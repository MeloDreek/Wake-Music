import UIKit
import SafariServices
import AppGroupKit
import KakaFoundation
import KakaUIKit

/// Uses the same form cells, section styling and action row as WebDAV/Navidrome.
final class AuthSMBViewController: SuperViewController, UITableViewDataSource, UITableViewDelegate, LoginTableViewCellDelegate {
    private let existing: SMBDriveUserModel?
    private let completion: ((SMBDriveUserModel) -> Void)?
    private var connecting = false
    private var loginTask: Task<Void, Never>?
    private let discovery = SMBDiscovery()
    // Password is transient form state only; it never enters ServerConfigModel.
    private var values: [LoginGroupItemType: String] = [:]
    private var cells: [LoginGroupItemType: LoginTableViewCell] = [:]
    private let fieldOrder: [LoginGroupItemType] = [.title, .host, .port, .path, .username, .password, .otherDav]
    private let groups: [[LoginGroupItemType]] = [
        [.title, .host, .port, .path],
        [.username, .password, .otherDav],
        [.cusButton]
    ]

    init(user: SMBDriveUserModel? = nil, completion: ((SMBDriveUserModel) -> Void)? = nil) {
        existing = user
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        values = [.title: user?.name ?? "My NAS".localStr(), .host: user?.host ?? "",
                  .port: String(user?.port ?? 445), .path: user?.share ?? "",
                  .username: user?.username ?? "", .password: "", .otherDav: user?.domain ?? ""]
//#if DEBUG
//        if user == nil {
//            values = [.title: "My NAS".localStr(), .host: "192.168.1.215", .port: "445",
//                      .path: "音乐", .username: "wakemusic", .password: "wake", .otherDav: ""]
//        }
//#endif
    }

    @MainActor required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
        discovery.onChange = { [weak self] in
            self?.tableView.reloadSections(IndexSet(integer: 0), with: .none)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(resumeDiscovery), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pauseDiscovery), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        title = ImportFileType.fromSMB.titleStr()
        navigationItem.largeTitleDisplayMode = .never
        if isPresent() {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        }
        
        let connectItem = UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"), style: .plain, target: self, action: #selector(questionBtnClick))
        self.navigationItem.rightBarButtonItem = connectItem
    }
    
    @objc func questionBtnClick() {
        let searchStr = String(format: SearchEngineType.defaultEngine().searchUrl(), "SMB")
        guard let vURL = URL(string: searchStr) else { return }
        
        if kaka_IsMacOS() {
            UIApplication.shared.open(vURL)
        }else{
            let webVC = SFSafariViewController(url: vURL)
            webVC.preferredControlTintColor = appMainColor
            self.present(webVC, animated: true)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
        if headView.frame.width != tableView.bounds.width {
            headView.frame.size.width = tableView.bounds.width
            tableView.tableHeaderView = headView
        }
        for cell in tableView.visibleCells.compactMap({ $0 as? LoginTableViewCell }) {
            resizeField(in: cell)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true {
            loginTask?.cancel()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        resumeDiscovery()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseDiscovery()
    }

    @objc private func resumeDiscovery() {
        guard isViewLoaded, view.window != nil, !connecting,
              navigationController?.topViewController === self, presentedViewController == nil else { return }
        // A real Bonjour browse triggers the system's first-use local network prompt.
        discovery.start()
    }

    @objc private func pauseDiscovery() { discovery.stop() }

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.dataSource = self
        table.delegate = self
        table.keyboardDismissMode = .interactive
        table.contentInsetAdjustmentBehavior = .automatic
        table.contentInset.bottom = kaka_safeAreaInsets().bottom + 20.ckValue()
//        table.tableHeaderView = headView
        return table
    }()

    private lazy var headView: UITableViewHeaderFooterView = {
        let iconSize: CGFloat = kaka_osType() == .iOS ? 120 : 150
        let header = UITableViewHeaderFooterView(frame: CGRect(x: 0, y: 0, width: view.width, height: iconSize * 1.5))
        header.backgroundColor = .clear
        let icon = UIImageView(image: ImportFileType.fromSMB.iconImage())
        icon.contentMode = .scaleAspectFit
        icon.isAccessibilityElement = false
        header.contentView.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(iconSize)
        }
        return header
    }()

    func numberOfSections(in tableView: UITableView) -> Int { groups.count + 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? discovery.devices.count + 1 : groups[section - 1].count
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? UITableView.automaticDimension : 55.ckValue()
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return "Nearby SMB Devices".localStr() }
        return section == 1 ? "Server".localStr() : (section == 2 ? "Account".localStr() : nil)
    }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "Select a Bonjour device to fill its hostname and port, then enter your share and account. Other devices can be added manually. Prefer hostnames when IP addresses change.".localStr()
        }
        guard section == 3 else { return nil }
        return "Connect to a Mac, Windows PC, or NAS on your local network. Enter the shared-folder name, not its disk path. Wake Music only browses, plays, and downloads files. Keep the server awake. SMB2/3 is required; guest access is not used. Passwords are saved in Keychain on this device.".localStr()
    }

    private func label(for item: LoginGroupItemType) -> String {
        if item == .path { return "Shared Folder".localStr() }
        if item == .otherDav { return "Domain (Optional)".localStr() }
        return item.titleStr(.fromSMB)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 { return discoveryCell(at: indexPath.row) }
        let item = groups[indexPath.section - 1][indexPath.row]
        if let cell = cells[item] { return cell }
        let cell = LoginTableViewCell(style: .default, reuseIdentifier: nil)
        cell.delegate = self
        cell.update(itemType: item, model: ServerConfigModel(serverType: .fromSMB, smbUser: existing))
        if item == .cusButton {
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = "Connect".localStr()
            cell.accessibilityTraits = .button
        } else {
            var config = cell.contentConfiguration as? UIListContentConfiguration
            config?.text = label(for: item)
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            cell.accessoryView = cell.textField
            cell.textField.text = values[item]
            cell.textField.accessibilityLabel = label(for: item)
            cell.textField.autocapitalizationType = .none
            cell.textField.autocorrectionType = .no
            switch item {
            case .host: cell.textField.placeholder = "smb://server/share"
            case .port: cell.textField.placeholder = "445"
            case .path: cell.textField.placeholder = "Required".localStr()
            case .otherDav: cell.textField.placeholder = "Optional".localStr()
            default: break
            }
            // Endpoint changes preserve the identity; share/account changes are a new connection.
            cell.textField.isEnabled = existing == nil || [.title, .host, .port, .password].contains(item)
        }
        cell.isUserInteractionEnabled = !connecting
        cells[item] = cell
        return cell
    }

    private func resizeField(in cell: LoginTableViewCell) {
        guard cell.itemType != .cusButton else { return }
        let labelWidth = fieldOrder.map { label(for: $0).width(cell.titleFont) }.max() ?? 0
        cell.textField.frame.size.width = max(100, cell.bounds.width - labelWidth - 55.ckValue())
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? LoginTableViewCell { resizeField(in: cell) }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !connecting else { return }
        if indexPath.section == 0 {
            selectDiscoveredDevice(at: indexPath.row)
            return
        }
        guard groups[indexPath.section - 1][indexPath.row] == .cusButton else { return }
        connect()
    }

    private func discoveryCell(at row: Int) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var config = cell.defaultContentConfiguration()
        config.textProperties.numberOfLines = 0
        config.secondaryTextProperties.numberOfLines = 0
        if row < discovery.devices.count {
            let device = discovery.devices[row]
            config.text = device.name
            config.secondaryText = "\(device.host):\(device.port)"
            config.image = UIImage(systemName: "externaldrive.connected.to.line.below")
            cell.accessoryType = values[.host] == device.host && values[.port] == String(device.port) ? .checkmark : .none
        } else {
            switch discovery.state {
            case .searching:
                config.text = "Searching for SMB devices…".localStr()
                let spinner = UIActivityIndicatorView(style: .medium)
                spinner.startAnimating()
                cell.accessoryView = spinner
            case .blocked:
                config.text = "Local network access is blocked. Open Settings.".localStr()
                cell.accessoryType = .disclosureIndicator
            case .unavailable:
                config.text = "Unable to search. Tap to retry.".localStr()
            case .browsing:
                config.text = (discovery.devices.isEmpty ? "No SMB devices found. Tap to search again." : "Search Again").localStr()
            }
            config.textProperties.color = .secondaryLabel
        }
        cell.contentConfiguration = config
        cell.accessibilityTraits.insert(.button)
        cell.isUserInteractionEnabled = !connecting
        return cell
    }

    private func selectDiscoveredDevice(at row: Int) {
        guard row < discovery.devices.count else {
            if discovery.state == .blocked {
                let settings = kaka_IsMacOS() ? SystemSettingPath.home.settingPathStr() : UIApplication.openSettingsURLString
                if let url = URL(string: settings) { UIApplication.shared.open(url) }
            } else { discovery.start() }
            return
        }
        let device = discovery.devices[row]
        view.endEditing(true)
        values[.host] = device.host
        values[.port] = String(device.port)
        // Preserve a custom label, the chosen share, and all account fields.
        if existing == nil && ((values[.title] ?? "").isEmpty || values[.title] == "My NAS".localStr()) {
            values[.title] = device.name
        }
        for item: LoginGroupItemType in [.host, .port, .title] { cells[item]?.textField.text = values[item] }
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
        tableView.scrollToRow(at: IndexPath(row: 0, section: 1), at: .top, animated: true)
    }

    func loginViewCellDidEndEditing(cell: LoginTableViewCell, itemType: LoginGroupItemType, content: String) {
        values[itemType] = content
    }
    func loginViewCellDidEndEditing(cell: LoginTableViewCell, itemType: LoginGroupItemType, isEnable: Bool) {}
    func loginViewCellDidNetProtocol(cell: LoginTableViewCell, netProtocol: NetworkProtocol) {}

    private func updateConnectingState() {
        cells.values.forEach { $0.isUserInteractionEnabled = !connecting }
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
        guard let button = cells[.cusButton] else { return }
        var config = button.contentConfiguration as? UIListContentConfiguration
        config?.text = (connecting ? "Processing..." : "Connect").localStr()
        button.contentConfiguration = config
        button.accessibilityLabel = (connecting ? "Processing..." : "Connect").localStr()
        button.accessibilityTraits = connecting ? [.button, .notEnabled] : .button
        if connecting {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.color = .deAccent
            spinner.startAnimating()
            button.accessoryView = spinner
        } else {
            button.accessoryView = nil
        }
    }

    @objc private func connect() {
        guard !connecting else { return }
        view.endEditing(true)
        do {
            let text = fieldOrder.map { (values[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
            var user = try SMBAddress.parse(server: text[1], port: text[2], share: text[3])
            if let existing {
                user = existing.updatingEndpoint(host: user.host, port: user.port)
            }
            user.name = text[0]
            user.username = text[4]
            user.domain = text[6]
            let password = values[.password] ?? "" // Password whitespace is significant.
            guard !user.username.isEmpty, !password.isEmpty else {
                throw SMBFailure.message("Enter your SMB username and password.")
            }
            connecting = true
            updateConnectingState()
            loginTask = SMBDriveService.shared.login(user, password: password) { [weak self] result in
                guard let self else { return }
                self.connecting = false
                self.updateConnectingState()
                switch result {
                case .success(let user):
                    self.values[.password] = ""
                    self.cells[.password]?.textField.text = nil
                    let server = ServerConfigModel(serverType: .fromSMB, isSelected: true, smbUser: user)
                    if self.routeImportedServer(server) { return }
                    if let completion = self.completion {
                        completion(user)
                        self.navigationController?.popViewController(animated: true)
                    } else {
                        let list = SMBDriveFileListController(loginModel: user)
                        var controllers = self.navigationController?.viewControllers ?? []
                        if controllers.last === self { controllers.removeLast() }
                        controllers.append(list)
                        self.navigationController?.setViewControllers(controllers, animated: true)
                    }
                case .failure(let error): self.showOneAlert(message: error.errorDescription)
                }
            }
        } catch {
            let message: String
            if case SMBFailure.message(let key) = error { message = key.localStr() }
            else { message = "Invalid SMB server address.".localStr() }
            showOneAlert(message: message)
        }
    }
}

extension UIViewController {
    func connectSMB() { navigationController?.pushViewController(AuthSMBViewController(), animated: true) }
}
