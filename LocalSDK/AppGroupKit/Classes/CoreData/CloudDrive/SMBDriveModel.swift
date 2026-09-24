import Foundation
import CryptoKit
import SmartCodable

/// Persist connection identity only. Passwords are held in the app's Keychain.
public struct SMBDriveUserModel: SmartCodableX, Hashable, Sendable {
    public init() {}
    public var host = ""
    public var port = 445
    public var share = ""
    public var username = ""
    public var domain = ""
    public var name = ""
    /// Filled only when editing an endpoint. Legacy accounts retain their original hash.
    public var connectionID = ""
    public var identity: String {
        if !connectionID.isEmpty { return connectionID }
        let parts = [host.lowercased(), String(port), share, domain, username]
        let data = (try? JSONEncoder().encode(parts)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    /// Changing an address must not orphan Keychain credentials, favorites or artwork.
    public func updatingEndpoint(host: String, port: Int) -> Self {
        var updated = self
        updated.connectionID = identity
        updated.host = host
        updated.port = port
        return updated
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
    public func hash(into hasher: inout Hasher) { hasher.combine(identity) }
    public var title: String { name.isEmpty ? share : name }
    public var serverURL: URL? {
        var parts = URLComponents()
        parts.scheme = "smb"
        parts.host = host
        parts.port = port
        return parts.url
    }
}

public struct SMBDriveFileModel: SmartCodableX, Hashable, Sendable {
    public init() {}
    /// Relative to the selected share, never a credential-bearing URL.
    public var id = ""
    public var name = ""
    public var isFolder = false
    public var size: Int64 = 0
    public var createdTime: TimeInterval = 0
    public var modifiedTime: TimeInterval = 0
    public var smbUser: SMBDriveUserModel?
    public var identity: String {
        let key = (smbUser?.identity ?? "unknown") + ":" + id
        return "smb-" + SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
    public func hash(into hasher: inout Hasher) { hasher.combine(identity) }
    public func isDirectory() -> Bool { isFolder }
    public func fileExtension() -> String { (name as NSString).pathExtension.lowercased() }
    public func isMusic() -> Bool { !isFolder && AudioExtension.isPlayableAudioExtension(fileExtension()) }
    public func mediaPlayURL() -> URL {
        URL(string: "smb-library://file")!.appendingPathComponent(identity).appendingPathComponent(name)
    }
}

// MARK: - FTP Models

/// Persist the endpoint and account identity only. FTP passwords belong in Keychain.
public struct FTPDriveUserModel: SmartCodableX, Hashable, Sendable {
    public init() {}

    public var host = ""
    public var port = 21
    public var username = ""
    public var name = ""
    /// Directory used as the first page after connecting.
    public var rootPath = "/"
    /// Preserve this identity when editing an endpoint so credentials and favorites survive.
    public var connectionID = ""

    public var identity: String {
        if !connectionID.isEmpty { return connectionID }
        let parts = [host.lowercased(), String(port), username, rootPath]
        let data = (try? JSONEncoder().encode(parts)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public var title: String { name.isEmpty ? "FTP" : name }

    /// FileProvider's FTP directory listing applies its base path more than once.
    /// Keep the provider rooted at /; FTPDriveService applies rootPath to requests.
    /// The URL deliberately contains no user information or password.
    public var serverURL: URL? {
        var parts = URLComponents()
        parts.scheme = "ftp"
        parts.host = host
        parts.port = port
        parts.path = "/"
        return parts.url
    }

    public func updatingEndpoint(host: String, port: Int) -> Self {
        var updated = self
        updated.connectionID = identity
        updated.host = host
        updated.port = port
        return updated
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
    public func hash(into hasher: inout Hasher) { hasher.combine(identity) }
}

public struct FTPDriveFileModel: SmartCodableX, Hashable, Sendable {
    public init() {}

    /// Relative to the account's root path; never a URL containing credentials.
    public var path = ""
    public var name = ""
    public var isFolder = false
    public var size: Int64 = 0
    public var createdTime: TimeInterval = 0
    public var modifiedTime: TimeInterval = 0
    public var ftpUser: FTPDriveUserModel?

    public var identity: String {
        // Keep file caches tied to the actual endpoint even if credentials
        // retain their stable account ID while the connection is edited.
        let user = ftpUser
        let key = [user?.identity ?? "unknown", user?.host.lowercased() ?? "",
                   String(user?.port ?? 21), user?.username ?? "", user?.rootPath ?? "/", path]
            .joined(separator: "\u{0}")
        return "ftp-" + SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
    public func hash(into hasher: inout Hasher) { hasher.combine(identity) }
    public func isDirectory() -> Bool { isFolder }
    public func fileExtension() -> String { (name as NSString).pathExtension.lowercased() }
    public func isMusic() -> Bool {
        !isFolder && AudioExtension.isPlayableAudioExtension(fileExtension())
    }
    public func isVideo() -> Bool {
        !isFolder && VideoExtensionType.allCases.contains { $0.rawValue == fileExtension() }
    }

    /// Placeholder until the FTP service resolves a local playback URL.
    public func mediaPlayURL() -> URL {
        URL(string: "ftp-library://file")!.appendingPathComponent(identity).appendingPathComponent(name)
    }
}
