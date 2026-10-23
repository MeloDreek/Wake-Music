import UIKit
import AppGroupKit
import KakaFoundation
import KakaUIKit

/// Password and optional 2FA code stay in this short-lived form, never in shared models.
final class AuthMEGAViewController: UITableViewController {
    private let account: MEGADriveUserModel?
    private var completion: ((Result<MEGADriveUserModel, KakaError>) -> Void)?
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let codeField = UITextField()
    private var connecting = false

    init(replacing account: MEGADriveUserModel?, completion: @escaping (Result<MEGADriveUserModel, KakaError>) -> Void) {
        self.account = account
        self.completion = completion
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "MEGA"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        tableView.keyboardDismissMode = .onDrag
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 54
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 180))
        let icon = UIImageView(image: ImportFileType.fromMEGADrive.iconImage())
        icon.tintColor = .systemRed
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: header.centerXAnchor), icon.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 110), icon.heightAnchor.constraint(equalTo: icon.widthAnchor)
        ])
        tableView.tableHeaderView = header
        emailField.text = account?.email
        emailField.isEnabled = account == nil
        emailField.keyboardType = .emailAddress
        emailField.textContentType = .username
        emailField.placeholder = "MEGA.Email".localStr()
        passwordField.placeholder = "Password".localStr()
        passwordField.isSecureTextEntry = true
        passwordField.textContentType = .password
        codeField.placeholder = "MEGA.CodeOptional".localStr()
        codeField.keyboardType = .numberPad
        codeField.textContentType = .oneTimeCode
        for field in [emailField, passwordField, codeField] {
            field.font = .preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.clearButtonMode = .whileEditing
            field.accessibilityLabel = field.placeholder
        }
        let eye = UIButton(type: .system)
        eye.setImage(UIImage(systemName: "eye"), for: .normal)
        eye.accessibilityLabel = "MEGA.ShowPassword".localStr()
        eye.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        eye.addTarget(self, action: #selector(togglePassword), for: .touchUpInside)
        passwordField.rightView = eye
        passwordField.rightViewMode = .always
        
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 3 : 1 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Account".localStr() : nil
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 ? "MEGA.LoginHint".localStr() : nil
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        if indexPath.section == 0 {
            let field = [emailField, passwordField, codeField][indexPath.row]
            field.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(field)
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                field.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                field.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 6),
                field.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -6),
                field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ])
            cell.selectionStyle = .none
        } else {
            var config = UIListContentConfiguration.cell()
            config.text = (connecting ? "Processing..." : "Connect").localStr()
            config.textProperties.alignment = .center
            config.textProperties.color = .deAccent
            config.textProperties.font = .preferredFont(forTextStyle: .headline)
            cell.contentConfiguration = config
            cell.backgroundColor = .label
            cell.accessibilityTraits = connecting ? [.button, .notEnabled] : .button
            if connecting {
                let spinner = UIActivityIndicatorView(style: .medium)
                spinner.color = .deAccent
                spinner.startAnimating()
                cell.accessoryView = spinner
            }
        }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 { connect() }
    }

    private func setConnecting(_ value: Bool) {
        connecting = value
        isModalInPresentation = value
        navigationController?.isModalInPresentation = value
        navigationItem.leftBarButtonItem?.isEnabled = !value
        emailField.isEnabled = !value && account == nil
        passwordField.isEnabled = !value
        codeField.isEnabled = !value
        tableView.reloadSections(IndexSet(integer: 1), with: .none)
    }
    private func connect() {
        guard !connecting else { return }
        let email = (emailField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordField.text ?? ""
        let code = (codeField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), !password.isEmpty else { showOneAlert(message: "MEGA.EnterCredentials".localStr()); return }
        view.endEditing(true)
        setConnecting(true)
        MEGADriveService.shared.login(email: email, password: password, pin: code, replacing: account) { [weak self] result in
            guard let self else { return }
            self.setConnecting(false)
            switch result {
            case .failure(let error): self.showOneAlert(message: error.errorDescription)
            case .success:
                self.passwordField.text = nil
                self.codeField.text = nil
                let completion = self.completion
                self.completion = nil
                self.dismiss(animated: true) { completion?(result) }
            }
        }
    }
    @objc private func togglePassword() {
        passwordField.isSecureTextEntry.toggle()
        let button = passwordField.rightView as? UIButton
        button?.setImage(UIImage(systemName: passwordField.isSecureTextEntry ? "eye" : "eye.slash"), for: .normal)
        button?.accessibilityLabel = (passwordField.isSecureTextEntry ? "MEGA.ShowPassword" : "MEGA.HidePassword").localStr()
    }
    @objc private func cancel() {
        guard !connecting else { return }
        passwordField.text = nil
        codeField.text = nil
        let completion = completion
        self.completion = nil
        dismiss(animated: true) { completion?(.failure(.youhaveCanceled)) }
    }
}
