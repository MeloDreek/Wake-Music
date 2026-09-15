import UIKit
import AuthenticationServices
import Security
import AppGroupKit
import KakaFoundation
import KakaUIKit

/// UI-facing adapter. No developer token is used, and no OAuth token enters App Group models.
final class GuangyaDriveService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GuangyaDriveService()
    private override init() { super.init() }
    private var authorizationSession: ASWebAuthenticationSession?
    private var authorizationWindow: UIWindow?
    private var isAuthorizing = false
    private let keychainService = (Bundle.main.bundleIdentifier ?? "Wakemusic") + ".guangya.oauth"
    private lazy var api = GuangyaDriveAPI(clientID: Guangya_ClientID, projectID: Guangya_ProjectID, secret: Guangya_Secret,
                                          deviceID: deviceID, redirectURI: Guangya_RedirectURL,
                                          load: { [weak self] in self?.loadToken($0) },
                                          save: { [weak self] in self?.storeToken($1, accountID: $0) ?? false },
                                          remove: { [weak self] in self?.removeToken($0) })
    private var deviceID: String {
        let key = "guangya.installationID"
        if let saved = UserDefaults.standard.string(forKey: key), UUID(uuidString: saved) != nil { return saved }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
    // ASWebAuthenticationSession consumes live callbacks. Suppress stale callbacks before general URL logging.
    static func isCallback(_ url: URL) -> Bool { url.scheme?.lowercased() == "wakemusic-guangya" }

    func authorize(from controller: UIViewController, replacing account: GuangyaDriveUserModel? = nil,
                   completion: @escaping (Result<GuangyaDriveUserModel, KakaError>) -> Void) {
        guard !isAuthorizing, let window = controller.view.window,
              let scheme = URL(string: Guangya_RedirectURL)?.scheme,
              scheme != "https", scheme != "http" else { completion(.failure(.youhaveCanceled)); return }
        guard let pkce = GuangyaPKCE() else { completion(.failure(.custom("Guangya.Configuration".localStr()))); return }
        let state = pkce.state
        guard let url = api.authorizationURL(pkce) else { completion(.failure(.custom("Guangya.Configuration".localStr()))); return }
        isAuthorizing = true
        authorizationWindow = window
        let finish: (Result<GuangyaDriveUserModel, KakaError>) -> Void = { result in
            self.authorizationSession = nil
            self.authorizationWindow = nil
            self.isAuthorizing = false
            completion(result)
        }
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
            DispatchQueue.main.async {
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    finish(.failure(.youhaveCanceled)); return
                }
                if error == nil, let callback = callback, self.api.authorizationWasDenied(callback, state: state) {
                    finish(.failure(.youhaveCanceled)); return
                }
                guard error == nil, let callback = callback,
                      let code = self.api.authorizationCode(from: callback, state: state) else {
                    finish(.failure(.tokenExpiredAuthAgain)); return
                }
                self.api.exchange(code: code, verifier: pkce.verifier) { result in
                    switch result {
                    case .failure(let error): finish(.failure(self.convert(error)))
                    case .success(let token):
                        self.api.user(token: token) { result in
                            switch result {
                            case .failure(let error): finish(.failure(self.convert(error)))
                            case .success(let info):
                                let user = GuangyaDriveUserModel(userID: info.userId, name: info.nickName ?? "")
                                guard account == nil || account == user else {
                                    finish(.failure(.custom("Guangya.SameAccount".localStr()))); return
                                }
                                guard self.api.install(token, accountID: user.userID) else {
                                    finish(.failure(self.convert(.storage))); return
                                }
                                var server = ServerConfigModel(serverType: .fromGuangyaDrive, isSelected: true)
                                server.guangyaUser = user
                                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: server) {
                                    finish(.success(user))
                                }
                            }
                        }
                    }
                }
            }
        }
        session.presentationContextProvider = self
        // Allow multiple Guangya accounts without silently reusing the browser's previous account.
        session.prefersEphemeralWebBrowserSession = true
        authorizationSession = session
        if !session.start() { finish(.failure(.tokenExpiredAuthAgain)) }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        authorizationWindow ?? ASPresentationAnchor()
    }

    func listFolder(user: GuangyaDriveUserModel, folderID: String,
                    completion: @escaping (Result<[MusicItemModel], KakaError>) -> Void) {
        api.listFolder(accountID: user.userID, folderID: folderID) { result in
            completion(result.map { entries in
                return entries.map { entry in
                    var file = GuangyaDriveFileModel()
                    file.id = entry.fileId
                    file.parentFolderID = folderID
                    file.name = entry.fileName
                    file.isFolder = entry.resType == 2
                    file.size = max(0, entry.fileSize ?? 0)
                    file.createdTime = entry.ctime ?? 0
                    file.modifiedTime = entry.mtime ?? file.createdTime
                    file.guangyaUser = user
                    return MusicItemModel(guangyaFile: file)
                }
            }.mapError(self.convert))
        }
    }

    func fileURL(_ file: GuangyaDriveFileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        guard !file.isFolder, let user = file.guangyaUser else { completion(.failure(.tokenExpiredAuthAgain)); return }
        api.fileURL(accountID: user.userID, fileID: file.id) { result in completion(result.mapError(self.convert)) }
    }

    func unlink(_ user: GuangyaDriveUserModel) { api.unlink(user.userID) }

    private func convert(_ error: GuangyaDriveError) -> KakaError {
        switch error {
        case .authorization: return .tokenExpiredAuthAgain
        case .storage: return .custom("Guangya.Storage".localStr())
        case .permission: return .custom("Guangya.Permission".localStr())
        case .notFound: return .custom("Guangya.NotFound".localStr())
        case .rateLimited: return .custom("Guangya.RateLimited".localStr())
        case .clockSkew: return .custom("Guangya.ClockSkew".localStr())
        case .signature, .configuration: return .custom("Guangya.Configuration".localStr())
        case .membership: return .custom("Guangya.Membership".localStr())
        case .restrictedFile: return .custom("Guangya.RestrictedFile".localStr())
        case .insecureDownload: return .custom("Guangya.InsecureDownload".localStr())
        case .invalidResponse, .network: return .custom("Guangya.Network".localStr())
        }
    }

    private func query(_ accountID: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService,
         kSecAttrAccount as String: accountID]
    }
    private func loadToken(_ accountID: String) -> GuangyaOAuthToken? {
        var query = query(accountID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(GuangyaOAuthToken.self, from: data)
    }
    private func storeToken(_ token: GuangyaOAuthToken, accountID: String) -> Bool {
        guard let data = try? JSONEncoder().encode(token) else { return false }
        let query = query(accountID)
        let values: [String: Any] = [kSecValueData as String: data,
                                   kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        return SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil) == errSecSuccess
    }
    private func removeToken(_ accountID: String) { SecItemDelete(query(accountID) as CFDictionary) }
}

extension UIViewController {
    func connectGuangyaDrive() {
        GuangyaDriveService.shared.authorize(from: self) { [weak self] result in
            switch result {
            case .success(let user):
                self?.navigationController?.pushViewController(GuangyaDriveFileListController(loginModel: user), animated: true)
            case .failure(let error):
                if error != .youhaveCanceled { self?.showOneAlert(message: error.errorDescription) }
            }
        }
    }
}
