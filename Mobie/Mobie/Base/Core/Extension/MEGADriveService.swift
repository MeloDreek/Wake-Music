import UIKit
import Security
import AppGroupKit
import KakaFoundation
import KakaUIKit
import MEGASdk

/// Only session keys enter Keychain. File models never contain passwords, keys or plaintext URLs.
@MainActor
final class MEGADriveService {
    static let shared = MEGADriveService()
    private var clients: [String: MEGASdk] = [:]
    private var restoring: [String: [(Result<MEGASdk, KakaError>) -> Void]] = [:]
    private var generations: [String: UUID] = [:]
    private var requests: [UUID: MEGARequestCompletion] = [:]
    private var streamDelegates: [String: MEGAHTTPCompletion] = [:]
    private var lastStreamError = Date.distantPast
    private let keychainService = (Bundle.main.bundleIdentifier ?? "Wakemusic") + ".mega.session"

    func authorize(from controller: UIViewController, replacing user: MEGADriveUserModel? = nil,
                   completion: @escaping (Result<MEGADriveUserModel, KakaError>) -> Void) {
        let login = AuthMEGAViewController(replacing: user, completion: completion)
        controller.present(KakaNavigationController(rootViewController: login), animated: true)
    }

    func login(email: String, password: String, pin: String, replacing user: MEGADriveUserModel?,
               completion: @escaping (Result<MEGADriveUserModel, KakaError>) -> Void) {
        // MEGA no longer requires a developer app key. No sample application's key is reused.
        guard let api = makeClient() else {
            completion(.failure(.custom("MEGA.Unavailable".localStr()))); return
        }
        runLogin(api, action: { delegate in
            if pin.isEmpty { api.login(withEmail: email, password: password, delegate: delegate) }
            else { api.multiFactorAuthLogin(withEmail: email, password: password, pin: pin, delegate: delegate) }
        }) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success:
                self.run(api, stage: "fetchNodes", action: { api.fetchNodes(with: $0) }) { result in
                    if case .failure(let error) = result { api.logout(); completion(.failure(error)); return }
                    guard let rootID = api.rootNode?.base64Handle, let session = api.dumpSession(),
                          let email = api.myEmail else {
                        api.logout(); completion(.failure(.custom("MEGA.InvalidResponse".localStr()))); return
                    }
                    let account = MEGADriveUserModel(userID: rootID, email: email, name: "MEGA")
                    guard user == nil || user == account else {
                        api.logout(); completion(.failure(.custom("MEGA.SameAccount".localStr()))); return
                    }
                    guard self.saveSession(session, account: rootID) else {
                        api.logout(); completion(.failure(.custom("MEGA.KeychainError".localStr()))); return
                    }
                    self.stopClient(rootID)
                    self.generations[rootID] = UUID()
                    self.clients[rootID] = api
                    let waiting = self.restoring.removeValue(forKey: rootID) ?? []
                    waiting.forEach { $0(.success(api)) }
                    var server = ServerConfigModel(serverType: .fromMEGADrive, isSelected: true)
                    server.megaUser = account
                    ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: server) {
                        completion(.success(account))
                    }
                }
            }
        }
    }

    func listFolder(user: MEGADriveUserModel, folderID: String,
                    completion: @escaping (Result<[MusicItemModel], KakaError>) -> Void) {
        client(for: user) { result in
            completion(result.flatMap { api in
                guard let parent = folderID == "0" ? api.rootNode : self.node(folderID, api: api), parent.isFolder() else {
                    return .failure(.custom("MEGA.NotFound".localStr()))
                }
                let nodes = api.children(forParent: parent)
                let files = (0..<nodes.size).compactMap { index -> MusicItemModel? in
                    guard let node = nodes.node(at: index), let id = node.base64Handle, let name = node.name else { return nil }
                    var file = MEGADriveFileModel()
                    file.id = id
                    file.parentFolderID = folderID
                    file.name = name
                    file.isFolder = node.isFolder()
                    file.size = max(0, node.size?.int64Value ?? 0)
                    file.createdTime = node.creationTime?.timeIntervalSince1970 ?? 0
                    file.modifiedTime = node.modificationTime?.timeIntervalSince1970 ?? file.createdTime
                    file.megaUser = user
                    return MusicItemModel(megaFile: file)
                }
                return .success(files)
            })
        }
    }

    func fileURL(_ file: MEGADriveFileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        guard !file.isFolder, let user = file.megaUser else { completion(.failure(.tokenExpiredAuthAgain)); return }
        client(for: user) { result in
            completion(result.flatMap { api in
                guard let node = self.node(file.id, api: api), !node.isFolder() else {
                    return .failure(.custom("MEGA.NotFound".localStr()))
                }
                // The official SDK decrypts and serves HTTP ranges to AVPlayer / KSPlayer.
                // Bind loopback only and expose only explicitly requested files, never folders.
                if api.httpServerIsRunning() == 0 && !api.httpServerStart(true, port: 0) {
                    return .failure(.custom("MEGA.StreamError".localStr()))
                }
                api.httpServerSetRestrictedMode(1)
                api.httpServerEnableFolderServer(false)
                api.httpServerEnableFileServer(true)
                api.httpServerEnableSubtitlesSupport(false)
                api.httpServerSetMaxBufferSize(2 * 1024 * 1024)
                api.httpServerSetMaxOutputSize(256 * 1024)
                if self.streamDelegates[user.userID] == nil {
                    let delegate = MEGAHTTPCompletion { [weak self, weak api] code in
                        guard let self, let api, self.clients[user.userID] === api,
                              Date().timeIntervalSince(self.lastStreamError) > 10 else { return }
                        self.lastStreamError = Date()
                        appKeyWindow?.makeToast(Self.error(code == 509 ? -17 : code).errorDescription)
                    }
                    self.streamDelegates[user.userID] = delegate
                    api.httpServerAdd(delegate)
                }
                guard api.httpServerIsLocalOnly(), let url = api.httpServerGetLocalLink(node),
                      ["::1", "[::1]", "127.0.0.1", "localhost"].contains(url.host ?? "") else {
                    api.httpServerStop()
                    return .failure(.custom("MEGA.StreamError".localStr()))
                }
                return .success(url)
            })
        }
    }

    func unlink(_ user: MEGADriveUserModel) {
        generations[user.userID] = UUID()
        stopClient(user.userID)
        SecItemDelete(query(user.userID) as CFDictionary)
        let callbacks = restoring.removeValue(forKey: user.userID) ?? []
        callbacks.forEach { $0(.failure(.tokenExpiredAuthAgain)) }
    }

    private func node(_ id: String, api: MEGASdk) -> MEGANode? {
        guard id.count == 8, id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { return nil }
        return api.node(forHandle: MEGASdk.handle(forBase64Handle: id))
    }

    private func makeClient() -> MEGASdk? {
        // v10.19.0 asserts while updating account status if the status DB is absent,
        // even though the initializer still documents nil as a supported basePath.
        // Isolate simultaneous login/restore clients to avoid sharing a live SQLite DB.
        // This is disposable SDK state in the app's private temporary directory;
        // persistent account sessions remain in Keychain, never UserDefaults.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MEGASDK", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return MEGASdk(appKey: "", userAgent: "WakeMusic", basePath: directory.path)
        } catch {
            return nil
        }
    }

    private func stopClient(_ account: String) {
        guard let api = clients.removeValue(forKey: account) else { return }
        if let delegate = streamDelegates.removeValue(forKey: account) {
            api.httpServerRemove(delegate)
        }
        api.httpServerStop()
    }

    private func client(for user: MEGADriveUserModel, completion: @escaping (Result<MEGASdk, KakaError>) -> Void) {
        if let api = clients[user.userID] { completion(.success(api)); return }
        if restoring[user.userID] != nil { restoring[user.userID]?.append(completion); return }
        guard let session = loadSession(user.userID) else {
            completion(.failure(.tokenExpiredAuthAgain)); return
        }
        guard let api = makeClient() else { completion(.failure(.custom("MEGA.Unavailable".localStr()))); return }
        let generation = UUID()
        generations[user.userID] = generation
        restoring[user.userID] = [completion]
        let finish: (Result<MEGASdk, KakaError>) -> Void = { result in
            guard self.generations[user.userID] == generation else { return }
            if case .success(let api) = result { self.clients[user.userID] = api }
            let callbacks = self.restoring.removeValue(forKey: user.userID) ?? []
            callbacks.forEach { $0(result) }
        }
        runLogin(api, action: { api.fastLogin(withSession: session, delegate: $0) }) { result in
            if case .failure(let error) = result { finish(.failure(error)); return }
            self.run(api, stage: "fetchNodes", action: { api.fetchNodes(with: $0) }) { result in
                if case .failure(let error) = result { finish(.failure(error)); return }
                guard api.rootNode?.base64Handle == user.userID else { finish(.failure(.tokenExpiredAuthAgain)); return }
                finish(.success(api))
            }
        }
    }

    private func runLogin(_ api: MEGASdk, action: @escaping (MEGARequestCompletion) -> Void,
                          completion: @escaping (Result<Void, KakaError>) -> Void) {
        let proxy: MEGASystemProxy
        do { proxy = try MEGASystemProxy.current() }
        catch { completion(.failure(.custom("MEGA.ProxyUnsupported".localStr()))); return }
        #if DEBUG
        debugPrint("MEGA network route", proxy.url == nil ? "direct" : "system proxy")
        #endif
        // Configuration is asynchronous in the C++ SDK. Apply it before any auth request,
        // both for password login and for a session restored from Keychain.
        run(api, stage: "configureProxy", action: {
            api.wakeSetProxy(url: proxy.url, username: proxy.username, password: proxy.password, delegate: $0)
        }) { result in
            if case .failure(let error) = result { completion(.failure(error)); return }
            self.run(api, stage: "login", action: action, completion: completion)
        }
    }

    private func run(_ api: MEGASdk, stage: String, action: (MEGARequestCompletion) -> Void,
                     completion: @escaping (Result<Void, KakaError>) -> Void) {
        let id = UUID()
        let delegate = MEGARequestCompletion(stage: stage) { [weak self] code in
            guard let self, self.requests.removeValue(forKey: id) != nil else { return }
            completion(code == 0 ? .success(()) : .failure(Self.error(code)))
        }
        requests[id] = delegate
        action(delegate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 90) { [weak self, weak delegate] in
            guard self?.requests.removeValue(forKey: id) != nil else { return }
            delegate?.completion = nil
            #if DEBUG
            debugPrint("MEGA request timed out, stage", stage)
            #endif
            completion(.failure(.custom("MEGA.Timeout".localStr())))
        }
    }

    private static func error(_ code: Int) -> KakaError {
        let key: String
        switch code {
        case -15: return .tokenExpiredAuthAgain
        case -26: key = "MEGA.MFARequired"
        case -9, -11: key = "MEGA.CredentialsOrAccess"
        case -17, -24: key = "MEGA.QuotaExceeded"
        case -16, -28, -29: key = "MEGA.AccountRestricted"
        case -4: key = "MEGA.RateLimited"
        case -14: key = "MEGA.DecryptionError"
        default: key = "MEGA.RequestFailed"
        }
        return .custom(key.localStr())
    }

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: account]
    }
    private func loadSession(_ account: String) -> String? {
        var request = query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &value) == errSecSuccess, let data = value as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private func saveSession(_ session: String, account: String) -> Bool {
        let values: [String: Any] = [kSecValueData as String: Data(session.utf8), kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query(account) as CFDictionary, values as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        return SecItemAdd(query(account).merging(values) { _, new in new } as CFDictionary, nil) == errSecSuccess
    }
}

private final class MEGARequestCompletion: NSObject, MEGARequestDelegate {
    var completion: ((Int) -> Void)?
    private let stage: String
    init(stage: String, completion: @escaping (Int) -> Void) {
        self.stage = stage
        self.completion = completion
    }
    func onRequestTemporaryError(_ api: MEGASdk, request: MEGARequest, error: MEGAError) {
        #if DEBUG
        debugPrint("MEGA request retry, stage", stage, "type", request.type.rawValue, "code", error.type.rawValue)
        #endif
    }
    func onRequestFinish(_ api: MEGASdk, request: MEGARequest, error: MEGAError) {
        let code = error.type.rawValue
        #if DEBUG
        debugPrint("MEGA request finished, stage", stage, "type", request.type.rawValue, "code", code)
        #endif
        DispatchQueue.main.async {
            let completion = self.completion
            self.completion = nil
            completion?(code)
        }
    }
}

private final class MEGAHTTPCompletion: NSObject, MEGATransferDelegate {
    private let completion: (Int) -> Void
    init(_ completion: @escaping (Int) -> Void) { self.completion = completion }
    func onTransferFinish(_ api: MEGASdk, transfer: MEGATransfer, error: MEGAError) {
        let code = error.type.rawValue
        // A player closing a range early is normal, not a playback failure.
        guard code != 0, code != -13 else { return }
        #if DEBUG
        debugPrint("MEGA stream failed, code", code)
        #endif
        DispatchQueue.main.async { self.completion(code) }
    }
}

extension UIViewController {
    func connectMEGADrive() {
        MEGADriveService.shared.authorize(from: self) { [weak self] result in
            if case .success(let user) = result {
                self?.navigationController?.pushViewController(MEGADriveFileListController(loginModel: user), animated: true)
            }
        }
    }
}
