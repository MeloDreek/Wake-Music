import UIKit
import AppGroupKit
import KakaFoundation
import KakaUIKit
import SafariServices

/// FTP login form. Credentials are transient UI state and saved by FTPDriveService
/// in Keychain only after the connection has been verified.
final class AuthFTPViewController: SuperViewController, UITableViewDataSource, UITableViewDelegate, LoginTableViewCellDelegate {
    private let existing: FTPDriveUserModel?
    private let completion: ((FTPDriveUserModel) -> Void)?
    private var connecting = false
    private var loginTask: Task<Void, Never>?
    private var values: [LoginGroupItemType: String] = [:]
    private var cells: [LoginGroupItemType: LoginTableViewCell] = [:]
    private let fieldOrder: [LoginGroupItemType] = [.title, .host, .port, .path, .username, .password]
    private let groups: [[LoginGroupItemType]] = [
        [.title], [.host, .port, .path], [.username, .password], [.cusButton]
    ]

    init(user: FTPDriveUserModel? = nil, completion: ((FTPDriveUserModel) -> Void)? = nil) {
        self.existing = user
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        values = [.title: user?.name ?? "My FTP".localStr(), .host: user?.host ?? "",
                  .port: String(user?.port ?? 21), .path: user?.rootPath ?? "/",
                  .username: user?.username ?? "", .password: ""]
#if DEBUG
        if user == nil {
            values = [.title: "FTP", .host: "39.98.202.131", .port: "21", .path: "/",
                      .username: "ftplcc", .password: "cBytbhCzCyXXHDdz"]
        }
#endif
    }

    @MainActor required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
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

    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        title = ImportFileType.fromFTP.titleStr()
        navigationItem.largeTitleDisplayMode = .never
        if isPresent() {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"),
                                                            style: .plain, target: self, action: #selector(questionBtnClick))
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true {
            loginTask?.cancel()
        }
    }

    @objc private func questionBtnClick() {
        guard let url = URL(string: "https://en.wikipedia.org/wiki/File_Transfer_Protocol") else { return }
        if kaka_IsMacOS() { UIApplication.shared.open(url) }
        else { present(SFSafariViewController(url: url), animated: true) }
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

    private lazy var headView: UIView = {
        let iconSize: CGFloat = kaka_osType() == .iOS ? 110 : 140
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.width, height: iconSize * 1.45))
        let icon = UIImageView(image: ImportFileType.fromFTP.iconImage())
        icon.contentMode = .scaleAspectFit
        icon.isAccessibilityElement = false
        header.addSubview(icon)
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
        switch section {
        case 1: return "Server".localStr()
        case 2: return "Account".localStr()
        default: return nil
        }
    }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 3 ? "FTP.ConnectionHelp".localStr() : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = groups[indexPath.section][indexPath.row]
        if let cell = cells[item] { return cell }
        let cell = LoginTableViewCell(style: .default, reuseIdentifier: nil)
        cell.delegate = self
        cell.update(itemType: item, model: ServerConfigModel(serverType: .fromFTP, ftpUser: existing))
        if item == .cusButton {
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = "Connect".localStr()
            cell.accessibilityTraits = .button
        } else {
            cell.selectionStyle = .none
            cell.accessoryView = cell.textField
            cell.textField.text = values[item]
            cell.textField.accessibilityLabel = item.titleStr(.fromFTP)
            cell.textField.autocapitalizationType = .none
            cell.textField.autocorrectionType = .no
            switch item {
            case .host: cell.textField.placeholder = "ftp.example.com"
            case .port: cell.textField.placeholder = "21"
            case .path: cell.textField.placeholder = "/"
            default: break
            }
            cell.textField.isEnabled = true
            if item == .host {
                cell.onHostPaste = { [weak self] value in self?.normalizePastedHost(value) }
            }
        }
        cell.isUserInteractionEnabled = !connecting
        cells[item] = cell
        return cell
    }

    private func resizeField(in cell: LoginTableViewCell) {
        guard cell.itemType != .cusButton else { return }
        let width = fieldOrder.map { $0.titleStr(.fromFTP).width(cell.titleFont) }.max() ?? 0
        cell.textField.frame.size.width = max(100, cell.bounds.width - width - 55.ckValue())
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? LoginTableViewCell { resizeField(in: cell) }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !connecting, groups[indexPath.section][indexPath.row] == .cusButton else { return }
        connect()
    }

    func loginViewCellDidEndEditing(cell: LoginTableViewCell, itemType: LoginGroupItemType, content: String) {
        values[itemType] = content
    }
    func loginViewCellDidEndEditing(cell: LoginTableViewCell, itemType: LoginGroupItemType, isEnable: Bool) {}
    func loginViewCellDidNetProtocol(cell: LoginTableViewCell, netProtocol: NetworkProtocol) {}

    private func normalizePastedHost(_ text: String) {
        guard text.contains("://"), let url = URLComponents(string: text),
              url.scheme?.lowercased() == "ftp", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return }
        values[.host] = host
        cells[.host]?.textField.text = host
        if let port = url.port {
            values[.port] = String(port)
            cells[.port]?.textField.text = String(port)
        }
        if !url.path.isEmpty {
            values[.path] = url.path
            cells[.path]?.textField.text = url.path
        }
    }

    private func updateConnectingState() {
        for cell in cells.values { cell.isUserInteractionEnabled = !connecting }
        if let button = cells[.cusButton] {
            if connecting {
                let spinner = UIActivityIndicatorView(style: .medium)
                spinner.color = .deAccent
                spinner.startAnimating()
                button.accessoryView = spinner
            } else { button.accessoryView = nil }
        }
    }

    @objc private func connect() {
        guard !connecting else { return }
        view.endEditing(true)
        guard requireRemoteConnectionAccess() else { return }
        do {
            let rawHost = (values[.host] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let address = rawHost.contains("://") ? rawHost : "ftp://" + rawHost
            guard let parts = URLComponents(string: address), parts.scheme?.lowercased() == "ftp",
                  let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
                  parts.query == nil, parts.fragment == nil,
                  let port = parts.port ?? Int((values[.port] ?? "21").trimmingCharacters(in: .whitespacesAndNewlines)),
                  (1...65535).contains(port) else {
                throw FTPFailure.message("Invalid FTP server address.")
            }
            let explicitPath = (values[.path] ?? "/").trimmingCharacters(in: .whitespacesAndNewlines)
            let pathValue = explicitPath == "/" && !parts.path.isEmpty ? parts.path : explicitPath
            let path = pathValue == "/" || pathValue.isEmpty ? "" : try FTPPath.relative(pathValue)
            var user = existing ?? FTPDriveUserModel()
            user.connectionID = existing?.identity ?? UUID().uuidString
            user.host = host
            user.port = port
            user.rootPath = path.isEmpty ? "/" : "/" + path
            user.name = (values[.title] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            user.username = (values[.username] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let password = values[.password] ?? ""
            guard !user.username.isEmpty, !password.isEmpty || existing != nil else {
                throw FTPFailure.message("Enter your FTP username and password.")
            }
            connecting = true
            updateConnectingState()
            loginTask = FTPDriveService.shared.login(user, password: password) { [weak self] result in
                guard let self else { return }
                self.connecting = false
                self.updateConnectingState()
                switch result {
                case .success(let user):
                    self.values[.password] = ""
                    self.cells[.password]?.textField.text = nil
                    let server = ServerConfigModel(serverType: .fromFTP, isSelected: true, ftpUser: user)
                    if self.routeImportedServer(server) { return }
                    if let completion = self.completion {
                        completion(user)
                        self.navigationController?.popViewController(animated: true)
                    } else {
                        let list = FTPDriveFileListController(loginModel: user)
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
            if case FTPFailure.message(let key) = error { message = key.localStr() }
            else { message = "Invalid FTP server address.".localStr() }
            showOneAlert(message: message)
        }
    }
}

extension UIViewController {
    func connectFTP() { navigationController?.pushViewController(AuthFTPViewController(), animated: true) }
}
