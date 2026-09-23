import Foundation
import Security
import FilesProvider
import AppGroupKit
import KakaFoundation

/// Read-only FTP adapter. The persisted account never contains a password.
final class FTPDriveService {
    static let shared = FTPDriveService()
    private let keychainService = (Bundle.main.bundleIdentifier ?? "Wakemusic") + ".ftp"
    private let readLimiter = FTPReadLimiter()

    @discardableResult
    func login(_ user: FTPDriveUserModel, password: String,
               completion: @escaping (Result<FTPDriveUserModel, KakaError>) -> Void) -> Task<Void, Never> {
        Task { @MainActor in
            do {
                let resolvedPassword = password.isEmpty ? loadPassword(user) : password
                guard let resolvedPassword, !resolvedPassword.isEmpty else {
                    throw FTPFailure.message("FTP credentials are missing. Edit the connection and sign in again.")
                }
                let provider = try makeProvider(user, password: resolvedPassword)
                defer { provider.session.invalidateAndCancel() }
                _ = try await directory(provider, path: FTPPath.serverPath(root: user.rootPath, relative: ""))
                guard !Task.isCancelled else { return }
                if !password.isEmpty {
                    let status = savePassword(password, user: user)
                    guard status == errSecSuccess else { throw FTPFailure.keychainStatus(status) }
                }
                SMBHTTPBridge.shared.revokeFTP(account: user.identity)
                let server = ServerConfigModel(serverType: .fromFTP, isSelected: true, ftpUser: user)
                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: server) {
                    completion(.success(user))
                }
            } catch {
                guard !Task.isCancelled else { return }
                completion(.failure(convert(error)))
            }
        }
    }

    func listFolder(user: FTPDriveUserModel, folderPath: String,
                    completion: @escaping (Result<[MusicItemModel], KakaError>) -> Void) {
        Task { @MainActor in
            do {
                let provider = try makeProvider(user)
                defer { provider.session.invalidateAndCancel() }
                let path = try FTPPath.relative(folderPath)
                let serverPath = try FTPPath.serverPath(root: user.rootPath, relative: path)
                let entries = try await directory(provider, path: serverPath)
                let files = entries.compactMap { entry -> MusicItemModel? in
                    let name = entry.name
                    guard name != ".", name != "..", !name.hasPrefix("."),
                          !name.contains("/"), !name.contains("\\"), !name.contains("\0"),
                          !FTPPath.hasControlCharacters(name),
                          entry.type == .directory || entry.type == .regular else { return nil }
                    var file = FTPDriveFileModel()
                    file.ftpUser = user
                    file.path = path.isEmpty ? name : path + "/" + name
                    file.name = name
                    file.isFolder = entry.type == .directory
                    file.size = max(0, entry.size)
                    file.createdTime = entry.creationDate?.timeIntervalSince1970 ?? 0
                    file.modifiedTime = entry.modifiedDate?.timeIntervalSince1970 ?? 0
                    return MusicItemModel(ftpFile: file)
                }
                completion(.success(files))
            } catch { completion(.failure(convert(error))) }
        }
    }

    /// Registers a short-lived, unguessable loopback URL. The FTP password and path
    /// are never exposed to AVPlayer, KSPlayer, Alamofire, or local HTTP requests.
    func fileURL(_ file: FTPDriveFileModel,
                 completion: @escaping (Result<URL, KakaError>) -> Void) {
        Task { @MainActor in
            do {
                guard let user = file.ftpUser, !file.isDirectory() else {
                    throw FTPFailure.message("Invalid FTP file.")
                }
                if let current = ConnectConfigManager.shared.connectedModels.compactMap(\.ftpUser)
                    .first(where: { $0.identity == user.identity }),
                   (current.host != user.host || current.port != user.port ||
                    current.username != user.username || current.rootPath != user.rootPath) {
                    // A queued item from before an endpoint edit must not be
                    // served from a different server with the same relative path.
                    throw FTPFailure.message("Invalid FTP file.")
                }
                let path = try FTPPath.relative(file.path)
                let serverPath = try FTPPath.serverPath(root: user.rootPath, relative: path)
                var size = file.size
                if size <= 0 {
                    let provider = try makeProvider(user)
                    defer { provider.session.invalidateAndCancel() }
                    let object = try await attributes(provider, path: serverPath)
                    size = object.size
                }
                guard size > 0 else { throw FTPFailure.message("The FTP audio file is empty or unavailable.") }
                let url = try await SMBHTTPBridge.shared.register(file: file, size: size) { range in
                    try await self.read(user: user, path: serverPath, range: range)
                }
                completion(.success(url))
            } catch { completion(.failure(convert(error))) }
        }
    }

    func unlink(_ user: FTPDriveUserModel) {
        SecItemDelete(query(user) as CFDictionary)
        Task { @MainActor in SMBHTTPBridge.shared.revokeFTP(account: user.identity) }
    }

    @MainActor private func makeProvider(_ requested: FTPDriveUserModel, password: String? = nil) throws -> FTPFileProvider {
        // Old playlists can refer to an earlier host while the edited connection
        // retains its stable identity. The current connected endpoint wins.
        let user = password == nil
            ? (ConnectConfigManager.shared.connectedModels.compactMap(\.ftpUser)
                .first { $0.identity == requested.identity } ?? requested)
            : requested
        guard let password = password ?? loadPassword(user), !password.isEmpty else {
            throw FTPFailure.message("FTP credentials are missing. Edit the connection and sign in again.")
        }
        guard !FTPPath.hasControlCharacters(user.username),
              !FTPPath.hasControlCharacters(password) else {
            throw FTPFailure.message("Invalid FTP server address.")
        }
        guard let url = user.serverURL,
              // Many Internet FTP servers advertise a private IP in PASV.
              // EPSV keeps the control-connection host and only returns a
              // data port, so it also works behind the server's NAT.
              let provider = FTPFileProvider(baseURL: url, mode: .extendedPassive,
                                             credential: URLCredential(user: user.username,
                                                                       password: password,
                                                                       persistence: .none), cache: nil) else {
            throw FTPFailure.message("Invalid FTP server address.")
        }
        return provider
    }

    private func directory(_ provider: FTPFileProvider, path: String) async throws -> [FileObject] {
        try await withCheckedThrowingContinuation { continuation in
            let resumeOnce = FTPResumeOnce()
            provider.contentsOfDirectory(path: path) { files, error in
                resumeOnce.run {
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: files) }
                }
            }
        }
    }

    private func attributes(_ provider: FTPFileProvider, path: String) async throws -> FileObject {
        try await withCheckedThrowingContinuation { continuation in
            let resumeOnce = FTPResumeOnce()
            provider.attributesOfItem(path: path) { file, error in
                resumeOnce.run {
                    if let error { continuation.resume(throwing: error) }
                    else if let file { continuation.resume(returning: file) }
                    else { continuation.resume(throwing: FTPFailure.message("The FTP audio file is empty or unavailable.")) }
                }
            }
        }
    }

    private func read(user: FTPDriveUserModel, path: String, range: Range<Int64>) async throws -> Data {
        let length = range.upperBound - range.lowerBound
        guard length > 0, length <= Int.max else { throw FTPFailure.message("Invalid FTP byte range.") }
        // FileProvider opens another control connection to fetch attributes for
        // every ranged RETR. Reusing one provider retains those sockets and can
        // exhaust servers with a 10-connection limit. A single in-flight read,
        // each with its own invalidated session, keeps the bridge streamable.
        await readLimiter.acquire()
        do {
            try Task.checkCancellation()
            let provider = try await makeProvider(user)
            let cancellation = FTPCancellation()
            let result: Data
            do {
                result = try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        let resumeOnce = FTPResumeOnce()
                        let progress = provider.contents(path: path, offset: range.lowerBound, length: Int(length)) { data, error in
                            resumeOnce.run {
                                if let error { continuation.resume(throwing: error) }
                                else if let data { continuation.resume(returning: data) }
                                else { continuation.resume(throwing: FTPFailure.message("Unable to read the FTP audio file.")) }
                            }
                        }
                        cancellation.set(progress)
                    }
                } onCancel: {
                    cancellation.cancel()
                }
            } catch {
                provider.session.invalidateAndCancel()
                throw error
            }
            provider.session.invalidateAndCancel()
            await readLimiter.release()
            return result
        } catch {
            await readLimiter.release()
            throw error
        }
    }

    private func query(_ user: FTPDriveUserModel) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService,
         kSecAttrAccount as String: user.identity]
    }

    private func loadPassword(_ user: FTPDriveUserModel) -> String? {
        var request = query(user)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func savePassword(_ password: String, user: FTPDriveUserModel) -> OSStatus {
        let request = query(user)
        let values: [String: Any] = [kSecValueData as String: Data(password.utf8),
                                     kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(request as CFDictionary, values as CFDictionary)
        if status == errSecSuccess { return status }
        guard status == errSecItemNotFound else { return status }
        return SecItemAdd(request.merging(values) { _, new in new } as CFDictionary, nil)
    }

    private func convert(_ error: Error) -> KakaError {
        if case FTPFailure.message(let key) = error { return .custom(key.localStr()) }
        if case FTPFailure.keychainStatus(let status) = error {
            return .custom("Unable to save FTP credentials in Keychain.".localStr() + " (\(status))")
        }
        // Do not display provider error descriptions: some contain FTP URLs.
        let code = (error as NSError).code
        return .custom("Unable to connect to FTP. Check the address, account, and server permissions.".localStr() + " (\(code))")
    }
}

private final class FTPCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var progress: Progress?
    private var cancelled = false

    func set(_ progress: Progress?) {
        lock.lock()
        self.progress = progress
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel { progress?.cancel() }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let current = progress
        lock.unlock()
        current?.cancel()
    }
}

/// Some versions of FileProvider can invoke an FTP completion twice when the
/// data connection finishes but the control connection then reports an error.
/// Resuming a checked continuation more than once is a process-fatal error.
private final class FTPResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func run(_ body: () -> Void) {
        lock.lock()
        guard !resumed else { lock.unlock(); return }
        resumed = true
        lock.unlock()
        body()
    }
}

private actor FTPReadLimiter {
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isBusy { isBusy = true; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty { isBusy = false }
        else { waiters.removeFirst().resume() }
    }
}

enum FTPFailure: Error { case message(String), keychainStatus(OSStatus) }

enum FTPPath {
    static func hasControlCharacters(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    static func relative(_ path: String) throws -> String {
        let parts = path.replacingOccurrences(of: "\\", with: "/").split(separator: "/")
        guard !parts.contains(".."), !hasControlCharacters(path) else {
            throw FTPFailure.message("Invalid FTP file.")
        }
        return parts.filter { $0 != "." }.joined(separator: "/")
    }

    static func serverPath(root: String, relative: String) throws -> String {
        let rootPart = try self.relative(root)
        let relativePart = try self.relative(relative)
        let combined = [rootPart, relativePart].filter { !$0.isEmpty }.joined(separator: "/")
        return combined.isEmpty ? "/" : "/" + combined
    }
}
