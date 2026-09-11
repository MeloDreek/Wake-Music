import Foundation
import SmartCodable

/// Only identity is shared/persisted with the library. OAuth credentials stay in Keychain.
public struct BoxDriveUserModel: SmartCodableX, Hashable, Sendable {
    public init() {}
    public init(userID: String, email: String, name: String) {
        self.userID = userID
        self.email = email
        self.name = name
    }
    public var userID = ""
    public var email = ""
    public var name = ""
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.userID == rhs.userID }
    public func hash(into hasher: inout Hasher) { hasher.combine(userID) }
}

public struct BoxDriveFileModel: SmartCodableX, Hashable, Sendable {
    public init() {}
    public var id = ""
    public var parentFolderID = "0"
    public var name = ""
    public var isFolder = false
    public var size: Int64 = 0
    public var createdTime: TimeInterval = 0
    public var modifiedTime: TimeInterval = 0
    public var boxUser: BoxDriveUserModel?

    public var identity: String { "box-\(boxUser?.userID ?? "unknown")-\(isFolder ? "folder" : "file")-\(id)" }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
    public func hash(into hasher: inout Hasher) { hasher.combine(identity) }
    public func isDirectory() -> Bool { isFolder }
    public func fileExtension() -> String { (name as NSString).pathExtension.lowercased() }
    public func isMusic() -> Bool { !isFolder && AudioExtensionType.allCases.contains { $0.rawValue == fileExtension() } }
    public func isVideo() -> Bool { !isFolder && VideoExtensionType.allCases.contains { $0.rawValue == fileExtension() } }
    /// Not a cached download link. Resolve /files/:id/content before every network use.
    public func mediaPlayURL() -> URL {
        URL(string: "box://library")!.appendingPathComponent(identity).appendingPathComponent(name)
    }
}
