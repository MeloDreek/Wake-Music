import UIKit
import AuthenticationServices
import Security
import YandexLoginSDK
import AppGroupKit
import KakaFoundation
import KakaUIKit

/// The SDK handles PKCE/state. Disk credentials are stored per account, never in shared models.
final class YandexDriveService: NSObject, YandexLoginSDKObserver {
    static let shared = YandexDriveService()
    private override init() { super.init() }
    private var activated = false
    private var completion: ((Result<YandexDriveUserModel, KakaError>) -> Void)?
    private var replacingAccount: YandexDriveUserModel?
    private var validatingLogin = false
    private let keychainService = (Bundle.main.bundleIdentifier ?? "Wakemusic") + ".yandex.oauth"
    private lazy var api = YandexDriveAPI(load: { [weak self] in self?.loadToken($0) },
                                         save: { [weak self] in self?.storeToken($1, accountID: $0) ?? false },
                                         remove: { [weak self] in self?.removeToken($0) })

    func authorize(from controller: UIViewController, replacing account: YandexDriveUserModel? = nil,
                   completion: @escaping (Result<YandexDriveUserModel, KakaError>) -> Void) {
        guard self.completion == nil, controller.view.window != nil else {
            completion(.failure(.youhaveCanceled)); return
        }
        self.completion = completion
        replacingAccount = account
        do {
            if !activated {
                try YandexLoginSDK.shared.activate(with: Yandex_ClientID, authorizationStrategy: .webOnly)
                activated = true
            }
            // Avoid the SDK's global cached login silently selecting a previously connected user.
            try YandexLoginSDK.shared.logout()
            YandexLoginSDK.shared.add(observer: self)
            try YandexLoginSDK.shared.authorize(with: controller, authorizationStrategy: .webOnly)
        } catch {
            finish(.failure(.custom("Yandex.AuthorizationFailed".localStr())))
        }
    }

    /// Consume callbacks before the application's general URL logging, including stale callbacks.
    func handleCallback(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == ("yx" + Yandex_ClientID).lowercased() else { return false }
        if activated, completion != nil { _ = YandexLoginSDK.shared.tryHandleOpenURL(url) }
        return true
    }

    func didFinishLogin(with result: Result<LoginResult, any Error>) {
        DispatchQueue.main.async {
            guard self.completion != nil, !self.validatingLogin else { return }
            switch result {
            case .failure(let error):
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    self.finish(.failure(.youhaveCanceled))
                } else {
                    self.finish(.failure(.custom("Yandex.AuthorizationFailed".localStr())))
                }
            case .success(let login):
                self.validatingLogin = true
                self.api.user(token: login.token) { result in
                    switch result {
                    case .failure(let error): self.finish(.failure(self.convert(error)))
                    case .success(let info):
                        let user = YandexDriveUserModel(userID: info.uid, login: info.login, name: info.display_name ?? info.login)
                        guard self.replacingAccount == nil || self.replacingAccount == user else {
                            self.finish(.failure(.custom("Yandex.SameAccount".localStr()))); return
                        }
                        guard self.api.install(login.token, accountID: user.userID) else {
                            self.finish(.failure(self.convert(.storage))); return
                        }
                        var server = ServerConfigModel(serverType: .fromYandexDrive, isSelected: true)
                        server.yandexUser = user
                        ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: server) {
                            self.finish(.success(user))
                        }
                    }
                }
            }
        }
    }

    private func finish(_ result: Result<YandexDriveUserModel, KakaError>) {
        YandexLoginSDK.shared.remove(observer: self)
        try? YandexLoginSDK.shared.logout()
        let callback = completion
        completion = nil
        replacingAccount = nil
        validatingLogin = false
        callback?(result)
    }

    func listFolder(user: YandexDriveUserModel, folderID: String,
                    completion: @escaping (Result<[MusicItemModel], KakaError>) -> Void) {
        api.listFolder(accountID: user.userID, folderID: folderID) { result in
            completion(result.map { entries in
                let formatter = ISO8601DateFormatter()
                return entries.map { entry in
                    var file = YandexDriveFileModel()
                    file.id = entry.resource_id ?? ""
                    file.path = entry.path
                    file.parentFolderID = folderID
                    file.name = entry.name
                    file.isFolder = entry.type == "dir"
                    file.size = max(0, entry.size ?? 0)
                    file.createdTime = entry.created.flatMap { formatter.date(from: $0) }?.timeIntervalSince1970 ?? 0
                    file.modifiedTime = entry.modified.flatMap { formatter.date(from: $0) }?.timeIntervalSince1970 ?? file.createdTime
                    file.yandexUser = user
                    return MusicItemModel(yandexFile: file)
                }
            }.mapError(self.convert))
        }
    }

    func fileSource(_ file: YandexDriveFileModel, completion: @escaping (Result<YandexDownloadSource, KakaError>) -> Void) {
        guard !file.isFolder, let user = file.yandexUser else { completion(.failure(.tokenExpiredAuthAgain)); return }
        api.fileSource(accountID: user.userID, path: file.path) { result in completion(result.mapError(self.convert)) }
    }

    func unlink(_ user: YandexDriveUserModel) { api.unlink(user.userID) }

    /// For playback metadata probes which create their own options. Never expose an OAuth
    /// header for synthetic identity URLs, local caches or a destination outside Yandex.
    func playbackHeaders(for file: YandexDriveFileModel, url: URL) -> [String: String] {
        guard YandexDriveAPI.validDownloadURL(url), let user = file.yandexUser,
              let token = loadToken(user.userID), !token.isEmpty else { return [:] }
        return ["Authorization": "OAuth " + token]
    }

    private func convert(_ error: YandexDriveError) -> KakaError {
        switch error {
        case .authorization: return .tokenExpiredAuthAgain
        case .permission: return .custom("Yandex.PermissionDenied".localStr())
        case .storage: return .custom("Yandex.StorageFailed".localStr())
        case .notFound: return .custom("Yandex.FileNotFound".localStr())
        case .rateLimited: return .custom("Yandex.RateLimited".localStr())
        case .network: return .custom("Yandex.NetworkError".localStr())
        case .invalidResponse: return .custom("Yandex.InvalidResponse".localStr())
        }
    }

    private func query(_ accountID: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService,
         kSecAttrAccount as String: accountID]
    }
    private func loadToken(_ accountID: String) -> String? {
        var query = query(accountID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private func storeToken(_ token: String, accountID: String) -> Bool {
        let query = query(accountID)
        let values: [String: Any] = [kSecValueData as String: Data(token.utf8),
                                   kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        return SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil) == errSecSuccess
    }
    private func removeToken(_ accountID: String) { SecItemDelete(query(accountID) as CFDictionary) }
}

extension UIViewController {
    func connectYandexDrive() {
        YandexDriveService.shared.authorize(from: self) { [weak self] result in
            switch result {
            case .success(let user):
                var server = ServerConfigModel(serverType: .fromYandexDrive, isSelected: true)
                server.yandexUser = user
                if self?.routeImportedServer(server) == true { return }
                self?.navigationController?.pushViewController(YandexDriveFileListController(loginModel: user), animated: true)
            case .failure(let error):
                if error != .youhaveCanceled { self?.showOneAlert(message: error.errorDescription) }
            }
        }
    }
}
