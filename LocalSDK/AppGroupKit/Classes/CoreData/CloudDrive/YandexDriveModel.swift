import Foundation
import CryptoKit
import SmartCodable

/// Only identity is shared/persisted with the library. OAuth credentials stay in Keychain.
public struct YandexDriveUserModel: SmartCodableX, Hashable, Sendable {
    public init() {}
    public init(userID: String, login: String, name: String) {
        self.userID = userID
        self.login = login
        self.name = name
    }
    public var userID = ""
    public var login = ""
    public var name = ""
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.userID == rhs.userID }
    public func hash(into hasher: inout Hasher) { hasher.combine(userID) }
}

public struct YandexDriveFileModel: SmartCodableX, Hashable, Sendable {
    public init() {}
    public var id = ""
    public var path = "disk:/"
    public var parentFolderID = "disk:/"
    public var name = ""
    public var isFolder = false
    public var size: Int64 = 0
    public var createdTime: TimeInterval = 0
    public var modifiedTime: TimeInterval = 0
    public var yandexUser: YandexDriveUserModel?

    public var identity: String {
        // A bounded filesystem-safe key, including long Unicode paths and different accounts.
        let resource = (yandexUser?.userID ?? "unknown") + "\u{0}" + (isFolder ? "folder" : "file") + "\u{0}" + (id.isEmpty ? path : id)
        return "yandex-" + SHA256.hash(data: Data(resource.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
    public func hash(into hasher: inout Hasher) { hasher.combine(identity) }
    public func isDirectory() -> Bool { isFolder }
    public func fileExtension() -> String { (name as NSString).pathExtension.lowercased() }
    public func isMusic() -> Bool { !isFolder && AudioExtension.isPlayableAudioExtension(fileExtension()) }
    public func isVideo() -> Bool { !isFolder && VideoExtensionType.allCases.contains { $0.rawValue == fileExtension() } }
    /// Not a cached download link. Resolve /resources/download before every network use.
    public func mediaPlayURL() -> URL {
        URL(string: "yandex://library")!.appendingPathComponent(identity).appendingPathComponent(name)
    }
}
