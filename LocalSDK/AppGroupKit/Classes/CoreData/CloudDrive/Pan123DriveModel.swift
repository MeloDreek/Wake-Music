import Foundation
import CryptoKit
import SmartCodable

/// Only identity is shared/persisted with the library. OAuth credentials stay in Keychain.
public struct Pan123DriveUserModel: SmartCodableX, Hashable, Sendable {
    public init() {}
    public init(userID: String, name: String, email: String = "", phone: String = "") {
        self.userID = userID
        self.name = name
        self.email = email
        self.phone = phone
    }
    public var userID = ""
    public var name = ""
    public var email = ""
    public var phone = ""
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.userID == rhs.userID }
    public func hash(into hasher: inout Hasher) { hasher.combine(userID) }
}

public struct Pan123DriveFileModel: SmartCodableX, Hashable, Sendable {
    public init() {}
    public var id = ""
    public var parentFolderID = ""
    public var name = ""
    public var isFolder = false
    public var size: Int64 = 0
    public var status = 0
    public var createdTime: TimeInterval = 0
    public var modifiedTime: TimeInterval = 0
    public var pan123User: Pan123DriveUserModel?

    public var identity: String {
        let key = (pan123User?.userID ?? "unknown") + "\u{0}" + (isFolder ? "folder" : "file") + "\u{0}" + id
        return "pan123-" + SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
    public func hash(into hasher: inout Hasher) { hasher.combine(identity) }
    public func isDirectory() -> Bool { isFolder }
    public func fileExtension() -> String { (name as NSString).pathExtension.lowercased() }
    public func isMusic() -> Bool { !isFolder && AudioExtensionType.allCases.contains { $0.rawValue == fileExtension() } }
    public func isVideo() -> Bool { !isFolder && VideoExtensionType.allCases.contains { $0.rawValue == fileExtension() } }
    /// Not a cached download link. Resolve download_info before every network use.
    public func mediaPlayURL() -> URL {
        URL(string: "pan123://library")!.appendingPathComponent(identity).appendingPathComponent(name)
    }
}
