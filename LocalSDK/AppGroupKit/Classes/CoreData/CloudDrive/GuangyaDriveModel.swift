import Foundation
import CryptoKit
import SmartCodable

/// Only identity is shared/persisted with the library. OAuth credentials stay in Keychain.
public struct GuangyaDriveUserModel: SmartCodableX, Hashable, Sendable {
    public init() {}
    public init(userID: String, name: String) {
        self.userID = userID
        self.name = name
    }
    public var userID = ""
    public var name = ""
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.userID == rhs.userID }
    public func hash(into hasher: inout Hasher) { hasher.combine(userID) }
}

public struct GuangyaDriveFileModel: SmartCodableX, Hashable, Sendable {
    public init() {}
    public var id = ""
    public var parentFolderID = ""
    public var name = ""
    public var isFolder = false
    public var size: Int64 = 0
    public var createdTime: TimeInterval = 0
    public var modifiedTime: TimeInterval = 0
    public var guangyaUser: GuangyaDriveUserModel?

    public var identity: String {
        let key = (guangyaUser?.userID ?? "unknown") + "\u{0}" + (isFolder ? "folder" : "file") + "\u{0}" + id
        return "guangya-" + SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
    public func hash(into hasher: inout Hasher) { hasher.combine(identity) }
    public func isDirectory() -> Bool { isFolder }
    public func fileExtension() -> String { (name as NSString).pathExtension.lowercased() }
    public func isMusic() -> Bool { !isFolder && AudioExtensionType.allCases.contains { $0.rawValue == fileExtension() } }
    public func isVideo() -> Bool { !isFolder && VideoExtensionType.allCases.contains { $0.rawValue == fileExtension() } }
    /// Not a cached download link. Resolve get_res_download_url before every network use.
    public func mediaPlayURL() -> URL {
        URL(string: "guangya://library")!.appendingPathComponent(identity).appendingPathComponent(name)
    }
}
