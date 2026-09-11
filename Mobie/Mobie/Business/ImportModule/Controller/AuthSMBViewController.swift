import UIKit
import AppGroupKit
import KakaFoundation
import KakaUIKit

/// Uses the same form cells, section styling and action row as WebDAV/Navidrome.
final class AuthSMBViewController: SuperViewController, UITableViewDataSource, UITableViewDelegate, LoginTableViewCellDelegate {
    private let existing: SMBDriveUserModel?
    private let completion: ((SMBDriveUserModel) -> Void)?
    private var connecting = false
    private var loginTask: Task<Void, Never>?
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
        values = [.title: user?.name ?? "", .host: user?.host ?? "",
                  .port: String(user?.port ?? 445), .path: user?.share ?? "",
                  .username: user?.username ?? "", .password: "", .otherDav: user?.domain ?? ""]
#if DEBUG
        if user == nil {
            values = [.title: "Mac SMB", .host: "192.168.1.177", .port: "445",
                      .path: "音乐", .username: "wakemusic", .password: "wake", .otherDav: ""]
        }
#endif
    }

    @MainActor required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
    }

    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        title = ImportFileType.fromSMB.titleStr()
        navigationItem.largeTitleDisplayMode = .never
        if isPresent() {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
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

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.dataSource = self
        table.delegate = self
        table.keyboardDismissMode = .interactive
        table.contentInsetAdjustmentBehavior = .automatic
        table.contentInset.bottom = kaka_safeAreaInsets().bottom + 20.ckValue()
        table.tableHeaderView = headView
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

    func numberOfSections(in tableView: UITableView) -> Int { groups.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { groups[section].count }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 55.ckValue() }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Server".localStr() : (section == 1 ? "Account".localStr() : nil)
    }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 2 else { return nil }
        return "Connect to a Mac, Windows PC, or NAS on your local network. Enter the shared-folder name, not its disk path. Wake Music only browses, plays, and downloads files. Keep the server awake. SMB2/3 is required; guest access is not used. Passwords are saved in Keychain on this device.".localStr()
    }

    private func label(for item: LoginGroupItemType) -> String {
        if item == .path { return "Shared Folder".localStr() }
        if item == .otherDav { return "Domain (Optional)".localStr() }
        return item.titleStr(.fromSMB)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = groups[indexPath.section][indexPath.row]
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
            // Changing an existing account's identity would invalidate its saved tracks.
            cell.textField.isEnabled = existing == nil || item == .title || item == .password
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
        guard groups[indexPath.section][indexPath.row] == .cusButton else { return }
        connect()
    }

    func loginViewCellDidEndEditing(cell: LoginTableViewCell, itemType: LoginGroupItemType, content: String) {
        values[itemType] = content
    }
    func loginViewCellDidEndEditing(cell: LoginTableViewCell, itemType: LoginGroupItemType, isEnable: Bool) {}
    func loginViewCellDidNetProtocol(cell: LoginTableViewCell, netProtocol: NetworkProtocol) {}

    private func updateConnectingState() {
        cells.values.forEach { $0.isUserInteractionEnabled = !connecting }
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
