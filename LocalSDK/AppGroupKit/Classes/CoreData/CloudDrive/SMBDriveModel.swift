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
    public var identity: String {
        let parts = [host.lowercased(), String(port), share, domain, username]
        let data = (try? JSONEncoder().encode(parts)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
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
    public func isMusic() -> Bool { !isFolder && AudioExtensionType.allCases.contains { $0.rawValue == fileExtension() } }
    public func mediaPlayURL() -> URL {
        URL(string: "smb-library://file")!.appendingPathComponent(identity).appendingPathComponent(name)
    }
}
