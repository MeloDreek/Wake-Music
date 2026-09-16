import UIKit
import AuthenticationServices
import Security
import AppGroupKit
import KakaFoundation
import KakaUIKit

/// UI-facing adapter. No developer token is used, and no OAuth token enters App Group models.
final class Pan123DriveService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = Pan123DriveService()
    private override init() { super.init() }
    private var authorizationSession: ASWebAuthenticationSession?
    private var authorizationWindow: UIWindow?
    private var isAuthorizing = false
    private let keychainService = (Bundle.main.bundleIdentifier ?? "Wakemusic") + ".pan123.oauth"
    private lazy var api = Pan123DriveAPI(clientID: Drive123_ClientID, secret: Drive123_Secret, redirectURI: Drive123_RedirectURL,
                                          load: { [weak self] in self?.loadToken($0) },
                                          save: { [weak self] in self?.storeToken($1, accountID: $0) ?? false },
                                          remove: { [weak self] in self?.removeToken($0) })

    // ASWebAuthenticationSession consumes live callbacks. Suppress stale callbacks before general URL logging.
    static func isCallback(_ url: URL) -> Bool { url.scheme?.lowercased() == URL(string: Drive123_RedirectURL)?.scheme }

    func authorize(from controller: UIViewController, replacing account: Pan123DriveUserModel? = nil,
                   completion: @escaping (Result<Pan123DriveUserModel, KakaError>) -> Void) {
        guard !isAuthorizing, let window = controller.view.window,
              let scheme = URL(string: Drive123_RedirectURL)?.scheme,
              scheme != "https", scheme != "http" else { completion(.failure(.youhaveCanceled)); return }
        let state = UUID().uuidString + UUID().uuidString
        guard let url = api.authorizationURL(state: state) else { completion(.failure(.custom("Pan123.Configuration".localStr()))); return }
        isAuthorizing = true
        authorizationWindow = window
        let finish: (Result<Pan123DriveUserModel, KakaError>) -> Void = { result in
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
                self.api.exchange(code: code) { result in
                    switch result {
                    case .failure(let error): finish(.failure(self.convert(error)))
                    case .success(let token):
                        self.api.user(token: token) { result in
                            switch result {
                            case .failure(let error): finish(.failure(self.convert(error)))
                            case .success(let info):
                                let user = Pan123DriveUserModel(userID: String(info.uid), name: info.nickname,
                                                                email: info.mail ?? "", phone: info.passport ?? "")
                                guard account == nil || account == user else {
                                    finish(.failure(.custom("Pan123.SameAccount".localStr()))); return
                                }
                                guard self.api.install(token, accountID: user.userID) else {
                                    finish(.failure(self.convert(.storage))); return
                                }
                                var server = ServerConfigModel(serverType: .from123Drive, isSelected: true)
                                server.pan123User = user
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
        // Allow multiple Pan123 accounts without silently reusing the browser's previous account.
        session.prefersEphemeralWebBrowserSession = true
        authorizationSession = session
        if !session.start() { finish(.failure(.tokenExpiredAuthAgain)) }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        authorizationWindow ?? ASPresentationAnchor()
    }

    func listFolder(user: Pan123DriveUserModel, folderID: String,
                    completion: @escaping (Result<[MusicItemModel], KakaError>) -> Void) {
        // Upgrade existing saved accounts without making users authorize again.
        if folderID == "0", user.email.isEmpty && user.phone.isEmpty {
            api.user(accountID: user.userID) { result in
                guard case .success(let info) = result else { return }
                var servers = ConnectConfigManager.shared.connectedModels
                guard let index = servers.firstIndex(where: { $0.pan123User?.userID == user.userID }) else { return }
                servers[index].pan123User = Pan123DriveUserModel(userID: user.userID, name: info.nickname,
                                                               email: info.mail ?? "", phone: info.passport ?? "")
                ConnectConfigManager.shared.connectedModels = servers
            }
        }
        api.listFolder(accountID: user.userID, folderID: folderID) { result in
            completion(result.map { entries in
                return entries.map { entry in
                    var file = Pan123DriveFileModel()
                    file.id = String(entry.fileId)
                    file.parentFolderID = folderID
                    file.name = entry.filename
                    file.isFolder = entry.type == 1
                    file.size = max(0, entry.size)
                    file.status = entry.status
                    file.createdTime = Pan123DriveAPI.timestamp(entry.createAt)
                    file.modifiedTime = Pan123DriveAPI.timestamp(entry.updateAt)
                    file.pan123User = user
                    return MusicItemModel(pan123File: file)
                }
            }.mapError(self.convert))
        }
    }

    func fileURL(_ file: Pan123DriveFileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        guard !file.isFolder, let user = file.pan123User else { completion(.failure(.tokenExpiredAuthAgain)); return }
        guard file.status <= 100 else { completion(.failure(convert(.restrictedFile))); return }
        api.fileURL(accountID: user.userID, fileID: file.id) { result in completion(result.mapError(self.convert)) }
    }

    func unlink(_ user: Pan123DriveUserModel) { api.unlink(user.userID) }

    private func convert(_ error: Pan123DriveError) -> KakaError {
        switch error {
        case .authorization: return .tokenExpiredAuthAgain
        case .storage: return .custom("Pan123.Storage".localStr())
        case .permission: return .custom("Pan123.Permission".localStr())
        case .notFound: return .custom("Pan123.NotFound".localStr())
        case .rateLimited: return .custom("Pan123.RateLimited".localStr())

        case .configuration: return .custom("Pan123.Configuration".localStr())
        case .quota: return .custom("Pan123.Quota".localStr())
        case .restrictedFile: return .custom("Pan123.RestrictedFile".localStr())
        case .insecureDownload: return .custom("Pan123.InsecureDownload".localStr())
        case .invalidResponse, .network: return .custom("Pan123.Network".localStr())
        }
    }

    private func query(_ accountID: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService,
         kSecAttrAccount as String: accountID]
    }
    private func loadToken(_ accountID: String) -> Pan123OAuthToken? {
        var query = query(accountID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Pan123OAuthToken.self, from: data)
    }
    private func storeToken(_ token: Pan123OAuthToken, accountID: String) -> Bool {
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
    func connectPan123Drive() {
        Pan123DriveService.shared.authorize(from: self) { [weak self] result in
            switch result {
            case .success(let user):
                var server = ServerConfigModel(serverType: .from123Drive, isSelected: true)
                server.pan123User = user
                if self?.routeImportedServer(server) == true { return }
                self?.navigationController?.pushViewController(Pan123DriveFileListController(loginModel: user), animated: true)
            case .failure(let error):
                if error != .youhaveCanceled { self?.showOneAlert(message: error.errorDescription) }
            }
        }
    }
}
