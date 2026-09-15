import UIKit
import Security
import AppGroupKit
import KakaFoundation
import KakaUIKit
import PCloudSDKSwift

/// Called from the main thread, like the SDK's completion blocks.
/// Each operation owns its client: never use the SDK's single global sharedClient.
final class PCloudDriveService {
    static let shared = PCloudDriveService()
    private init() {}

    private var isAuthorizing = false
    private let keychainService = (Bundle.main.bundleIdentifier ?? "Wakemusic") + ".pcloud.oauth"

    func authorize(from controller: UIViewController, replacing account: PCloudDriveUserModel? = nil,
                   completion: @escaping (Result<PCloudDriveUserModel, KakaError>) -> Void) {
        guard !isAuthorizing, let window = controller.view.window else {
            completion(.failure(.youhaveCanceled))
            return
        }
        isAuthorizing = true
        // The SDK derives its callback scheme from this app key (lowercased).
        OAuth.performAuthorizationFlow(with: window, appKey: pCloud_AppID) { [weak self] result in
            DispatchQueue.main.async {
                self?.completeAuthorization(result, replacing: account, completion: completion)
            }
        }
    }

    private func completeAuthorization(_ result: OAuth.Result, replacing account: PCloudDriveUserModel?,
                                       completion: @escaping (Result<PCloudDriveUserModel, KakaError>) -> Void) {
        switch result {
        case .cancel:
            self.isAuthorizing = false
            completion(.failure(.youhaveCanceled))
        case .failure:
            self.isAuthorizing = false
            completion(.failure(.tokenExpiredAuthAgain))
        case .success(let credentials):
            let user = PCloudDriveUserModel(userID: credentials.id, serverRegionID: credentials.serverRegionId,
                                           apiHostName: credentials.httpAPIHostName, email: "")
            guard user.hasValidEndpoint, !credentials.token.isEmpty else {
                self.isAuthorizing = false
                completion(.failure(.tokenExpiredAuthAgain))
                return
            }
            guard account == nil || account == user else {
                self.isAuthorizing = false
                completion(.failure(.custom("Please sign in to the same pCloud account.".localStr())))
                return
            }
            let client = PCloud.createClient(with: credentials)
            client.fetchUserInfo().addCompletionBlock { [client] result in
                _ = client // Retain the per-account URLSession until this request finishes.
                self.isAuthorizing = false
                switch result {
                case .success(let info):
                    guard info.id == user.userID, self.store(credentials, for: user) else {
                        completion(.failure(.custom("Unable to save pCloud authorization. Please try again.".localStr())))
                        return
                    }
                    var savedUser = user
                    savedUser.email = info.emailAddress
                    let server = ServerConfigModel(serverType: .fromePCloud, isSelected: true, pcloudUser: savedUser)
                    ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: server) {
                        completion(.success(savedUser))
                    }
                case .failure(let error):
                    completion(.failure(self.convert(error)))
                }
            }.start()
        }
    }

    func listFolder(user: PCloudDriveUserModel, folderID: UInt64,
                    completion: @escaping (Result<[MusicItemModel], KakaError>) -> Void) {
        guard let credentials = credentials(for: user) else {
            completion(.failure(.tokenExpiredAuthAgain))
            return
        }
        let client = PCloud.createClient(with: credentials)
        client.listFolder(folderID, recursively: false).addCompletionBlock { [client] result in
            _ = client
            guard self.credentials(for: user) == credentials else {
                completion(.failure(.tokenExpiredAuthAgain))
                return
            }
            switch result {
            case .success(let folder):
                let files = folder.contents.map { content -> MusicItemModel in
                    let metadata: Content.Metadata
                    var file = PCloudDriveFileModel()
                    switch content {
                    case .folder(let value):
                        metadata = value
                        file.isFolder = true
                    case .file(let value):
                        metadata = value
                        file.size = Int64(clamping: value.size)
                    }
                    file.id = metadata.id
                    file.parentFolderID = metadata.parentFolderId
                    file.name = metadata.name
                    file.createdTime = TimeInterval(metadata.createdTime)
                    file.modifiedTime = TimeInterval(metadata.modifiedTime)
                    file.pcloudUser = user
                    return MusicItemModel(pcloudFile: file)
                }
                completion(.success(files))
            case .failure(let error): completion(.failure(self.convert(error)))
            }
        }.start()
    }

    /// pCloud links expire. Resolve anew for each playback or download request.
    func fileURL(_ file: PCloudDriveFileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        guard !file.isDirectory(), let user = file.pcloudUser, let credentials = credentials(for: user) else {
            completion(.failure(.tokenExpiredAuthAgain))
            return
        }
        let client = PCloud.createClient(with: credentials)
        client.getFileLink(forFile: file.id).addCompletionBlock { [client] result in
            _ = client
            guard self.credentials(for: user) == credentials else {
                completion(.failure(.tokenExpiredAuthAgain))
                return
            }
            switch result {
            case .success(let links):
                guard let link = links.first(where: {
                    $0.address.scheme?.lowercased() == "https" && $0.address.host != nil && $0.expirationDate > Date()
                }) else {
                    completion(.failure(.unknowError))
                    return
                }
                completion(.success(link.address))
            case .failure(let error): completion(.failure(self.convert(error)))
            }
        }.start()
    }

    func unlink(_ user: PCloudDriveUserModel) {
        SecItemDelete(keychainQuery(for: user) as CFDictionary)
    }

    private func convert<E>(_ error: CallError<E>) -> KakaError {
        if case .authError = error { return .tokenExpiredAuthAgain }
        if case .clientError(let underlying) = error { return .custom(underlying.localizedDescription) }
        return .custom("pCloud request failed. Please check your connection and account permissions.".localStr())
    }

    private func keychainQuery(for user: PCloudDriveUserModel) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainService,
         kSecAttrAccount as String: user.accountID]
    }

    private func credentials(for user: PCloudDriveUserModel) -> OAuth.User? {
        guard user.hasValidEndpoint else { return nil }
        var query = keychainQuery(for: user)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let credentials = try? JSONDecoder().decode(OAuth.User.self, from: data),
              credentials.id == user.userID, credentials.serverRegionId == user.serverRegionID,
              credentials.httpAPIHostName == user.apiHostName else { return nil }
        return credentials
    }

    private func store(_ credentials: OAuth.User, for user: PCloudDriveUserModel) -> Bool {
        guard let data = try? JSONEncoder().encode(credentials) else { return false }
        let query = keychainQuery(for: user)
        let attributes: [String: Any] = [kSecValueData as String: data,
                                       kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        return SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess
    }
}

extension UIViewController {
    /// Shared by the Import and Connections entry points.
    func connectPCloudDrive() {
        PCloudDriveService.shared.authorize(from: self) { [weak self] result in
            switch result {
            case .success(let user):
                let server = ServerConfigModel(serverType: .fromePCloud, isSelected: true, pcloudUser: user)
                if self?.routeImportedServer(server) == true { return }
                self?.navigationController?.pushViewController(PCloudDriveFileListController(loginModel: user), animated: true)
            case .failure(let error):
                if error != .youhaveCanceled { self?.showOneAlert(message: error.errorDescription) }
            }
        }
    }
}
