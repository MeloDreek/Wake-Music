import UIKit
import AuthenticationServices
import Security
import AppGroupKit
import KakaFoundation
import KakaUIKit

/// UI-facing adapter. No developer token is used, and no OAuth token enters App Group models.
final class BoxDriveService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = BoxDriveService()
    private override init() { super.init() }
    private var authorizationSession: ASWebAuthenticationSession?
    private var authorizationWindow: UIWindow?
    private var isAuthorizing = false
    private let keychainService = (Bundle.main.bundleIdentifier ?? "Wakemusic") + ".box.oauth"
    private lazy var api = BoxDriveAPI(clientID: Box_ClientID, clientSecret: Box_ClientSecret, redirectURI: Box_RedirectURL,
                                     load: { [weak self] in self?.loadToken($0) },
                                     save: { [weak self] in self?.storeToken($1, accountID: $0) ?? false },
                                     remove: { [weak self] in self?.removeToken($0) })

    func authorize(from controller: UIViewController, replacing account: BoxDriveUserModel? = nil,
                   completion: @escaping (Result<BoxDriveUserModel, KakaError>) -> Void) {
        guard !isAuthorizing, let window = controller.view.window,
              let scheme = URL(string: Box_RedirectURL)?.scheme,
              scheme != "https", scheme != "http" else { completion(.failure(.youhaveCanceled)); return }
        let state = UUID().uuidString
        guard let url = api.authorizationURL(state: state) else { completion(.failure(.tokenExpiredAuthAgain)); return }
        isAuthorizing = true
        authorizationWindow = window
        let finish: (Result<BoxDriveUserModel, KakaError>) -> Void = { result in
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
                                let user = BoxDriveUserModel(userID: info.id, email: info.login, name: info.name)
                                guard account == nil || account == user else {
                                    finish(.failure(.custom("Please sign in to the same Box account.".localStr()))); return
                                }
                                guard self.api.install(token, accountID: user.userID) else {
                                    finish(.failure(self.convert(.storage))); return
                                }
                                let server = ServerConfigModel(serverType: .fromBoxDrive, isSelected: true, boxUser: user)
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
        // Allow multiple Box accounts without silently reusing the browser's previous account.
        session.prefersEphemeralWebBrowserSession = true
        authorizationSession = session
        if !session.start() { finish(.failure(.tokenExpiredAuthAgain)) }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        authorizationWindow ?? ASPresentationAnchor()
    }

    func listFolder(user: BoxDriveUserModel, folderID: String,
                    completion: @escaping (Result<[MusicItemModel], KakaError>) -> Void) {
        api.listFolder(accountID: user.userID, folderID: folderID) { result in
            completion(result.map { entries in
                let formatter = ISO8601DateFormatter()
                return entries.map { entry in
                    var file = BoxDriveFileModel()
                    file.id = entry.id
                    file.parentFolderID = folderID
                    file.name = entry.name
                    file.isFolder = entry.type == "folder"
                    file.size = max(0, entry.size ?? 0)
                    file.createdTime = entry.created_at.flatMap { formatter.date(from: $0) }?.timeIntervalSince1970 ?? 0
                    file.modifiedTime = entry.modified_at.flatMap { formatter.date(from: $0) }?.timeIntervalSince1970 ?? file.createdTime
                    file.boxUser = user
                    return MusicItemModel(boxFile: file)
                }
            }.mapError(self.convert))
        }
    }

    func fileURL(_ file: BoxDriveFileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        guard !file.isFolder, let user = file.boxUser else { completion(.failure(.tokenExpiredAuthAgain)); return }
        api.fileURL(accountID: user.userID, fileID: file.id) { result in completion(result.mapError(self.convert)) }
    }

    func unlink(_ user: BoxDriveUserModel) { api.unlink(user.userID) }

    private func convert(_ error: BoxDriveError) -> KakaError {
        switch error {
        case .authorization: return .tokenExpiredAuthAgain
        case .storage: return .custom("Unable to save Box authorization. Please try again.".localStr())
        default: return .custom("Box request failed. Please check your connection and account permissions.".localStr())
        }
    }

    private func query(_ accountID: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService,
         kSecAttrAccount as String: accountID]
    }
    private func loadToken(_ accountID: String) -> BoxOAuthToken? {
        var query = query(accountID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(BoxOAuthToken.self, from: data)
    }
    private func storeToken(_ token: BoxOAuthToken, accountID: String) -> Bool {
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
    func connectBoxDrive() {
        BoxDriveService.shared.authorize(from: self) { [weak self] result in
            switch result {
            case .success(let user):
                let server = ServerConfigModel(serverType: .fromBoxDrive, isSelected: true, boxUser: user)
                if self?.routeImportedServer(server) == true { return }
                self?.navigationController?.pushViewController(BoxDriveFileListController(loginModel: user), animated: true)
            case .failure(let error):
                if error != .youhaveCanceled { self?.showOneAlert(message: error.errorDescription) }
            }
        }
    }
}
