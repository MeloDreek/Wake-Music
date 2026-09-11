import Foundation
import Security
import AMSMB2
import AppGroupKit
import KakaFoundation

/// Read-only adapter: deliberately exposes no remote create, write, move or delete API.
final class SMBDriveService {
    static let shared = SMBDriveService()
    private let keychainService = (Bundle.main.bundleIdentifier ?? "Wakemusic") + ".smb"

    @discardableResult
    func login(_ user: SMBDriveUserModel, password: String,
               completion: @escaping (Result<SMBDriveUserModel, KakaError>) -> Void) -> Task<Void, Never> {
        Task { @MainActor in
            do {
                let client = try await connect(user, password: password)
                _ = try await client.contentsOfDirectory(atPath: "")
                guard !Task.isCancelled else { return }
                guard savePassword(password, user: user) else {
                    throw SMBFailure.message("Unable to save SMB credentials in Keychain.")
                }
                SMBHTTPBridge.shared.revoke(account: user.identity)
                let server = ServerConfigModel(serverType: .fromSMB, isSelected: true, smbUser: user)
                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: server) {
                    completion(.success(user))
                }
            } catch {
                guard !Task.isCancelled else { return }
                completion(.failure(convert(error)))
            }
        }
    }

    func listFolder(user: SMBDriveUserModel, folderID: String,
                    completion: @escaping (Result<[MusicItemModel], KakaError>) -> Void) {
        Task { @MainActor in
            do {
                let client = try await connect(user)
                let path = try SMBPath.relative(folderID)
                let entries = try await client.contentsOfDirectory(atPath: path)
                let files = entries.compactMap { attributes -> MusicItemModel? in
                    guard let name = attributes[.nameKey] as? String,
                          name != ".", name != "..", !name.contains("/"), !name.contains("\\"),
                          !name.hasPrefix(".") else { return nil }
                    let type = attributes[.fileResourceTypeKey] as? URLFileResourceType
                    // Do not follow server-side symlinks outside the selected share.
                    guard type == .directory || type == .regular else { return nil }
                    var file = SMBDriveFileModel()
                    file.id = path.isEmpty ? name : path + "/" + name
                    file.name = name
                    file.isFolder = type == .directory
                    file.size = (attributes[.fileSizeKey] as? NSNumber)?.int64Value ?? 0
                    file.createdTime = (attributes[.creationDateKey] as? Date)?.timeIntervalSince1970 ?? 0
                    file.modifiedTime = (attributes[.contentModificationDateKey] as? Date)?.timeIntervalSince1970 ?? 0
                    file.smbUser = user
                    return MusicItemModel(smbFile: file)
                }
                completion(.success(files))
            } catch { completion(.failure(convert(error))) }
        }
    }

    func fileURL(_ file: SMBDriveFileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        Task { @MainActor in
            do {
                guard let user = file.smbUser, !file.isFolder else { throw SMBFailure.message("Invalid SMB file.") }
                let path = try SMBPath.relative(file.id)
                let client = try await connect(user)
                let attributes = try await client.attributesOfItem(atPath: path)
                guard attributes[.fileResourceTypeKey] as? URLFileResourceType == .regular,
                      let size = (attributes[.fileSizeKey] as? NSNumber)?.int64Value, size > 0 else {
                    throw SMBFailure.message("The SMB audio file is empty or unavailable.")
                }
                let url = try await SMBHTTPBridge.shared.register(file: file, size: size) { range in
                    try await client.contents(atPath: path, range: range)
                }
                completion(.success(url))
            } catch { completion(.failure(convert(error))) }
        }
    }

    private func connect(_ user: SMBDriveUserModel, password: String? = nil) async throws -> SMB2Manager {
        guard let password = password ?? loadPassword(user), !password.isEmpty else {
            throw SMBFailure.message("SMB credentials are missing. Edit the connection and sign in again.")
        }
        guard let url = user.serverURL,
              let client = SMB2Manager(url: url, domain: user.domain,
                                      credential: URLCredential(user: user.username, password: password, persistence: .none)) else {
            throw SMBFailure.message("Invalid SMB server address.")
        }
        client.timeout = 20
        try await client.connectShare(name: user.share)
        return client
    }

    func unlink(_ user: SMBDriveUserModel) {
        SecItemDelete(query(user) as CFDictionary)
        Task { @MainActor in SMBHTTPBridge.shared.revoke(account: user.identity) }
    }

    private func query(_ user: SMBDriveUserModel) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService,
         kSecAttrAccount as String: user.identity]
    }
    private func loadPassword(_ user: SMBDriveUserModel) -> String? {
        var q = query(user)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &value) == errSecSuccess, let data = value as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private func savePassword(_ password: String, user: SMBDriveUserModel) -> Bool {
        let q = query(user)
        let values: [String: Any] = [kSecValueData as String: Data(password.utf8),
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(q as CFDictionary, values as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        return SecItemAdd(q.merging(values) { _, new in new } as CFDictionary, nil) == errSecSuccess
    }
    private func convert(_ error: Error) -> KakaError {
        if case SMBFailure.message(let key) = error { return .custom(key.localStr()) }
        let code = (error as NSError).code
        let key: String
        switch code {
        case Int(EACCES), Int(EPERM): key = "SMB access denied. Check the username, password, and shared-folder permissions."
        case Int(ENOENT): key = "SMB share or file not found. Enter the shared-folder name, not a path on the Mac."
        default: key = "Unable to read from SMB. Keep the server awake, connect to the same network, and check the address and permissions."
        }
        return .custom(key.localStr() + " (\(code))")
    }
}
