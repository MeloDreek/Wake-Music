import Foundation
import SmartCodable

/// Only account identity is persisted in App Group data. OAuth tokens stay in Keychain.
public struct PCloudDriveUserModel: SmartCodableX, Hashable, Equatable, Sendable {
    public init() {}

    public init(userID: UInt64, serverRegionID: UInt, apiHostName: String, email: String) {
        self.userID = userID
        self.serverRegionID = serverRegionID
        self.apiHostName = apiHostName
        self.email = email
    }

    public var userID: UInt64 = 0
    public var serverRegionID: UInt = 0
    public var apiHostName: String = ""
    public var email: String = ""

    public var accountID: String { "\(serverRegionID)-\(userID)" }

    /// Do not send credentials to an arbitrary hostname supplied by an OAuth callback.
    public var hasValidEndpoint: Bool {
        switch serverRegionID {
        case 1: return apiHostName == "api.pcloud.com"
        case 2: return apiHostName == "eapi.pcloud.com"
        default: return false
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.accountID == rhs.accountID }
    public func hash(into hasher: inout Hasher) { hasher.combine(accountID) }
}

/// SDK-independent snapshot, shared by browsing, favorites, playback and downloads.
public struct PCloudDriveFileModel: SmartCodableX, Hashable, Equatable, Sendable {
    public init() {}

    public var id: UInt64 = 0
    public var parentFolderID: UInt64 = 0
    public var name: String = ""
    public var isFolder: Bool = false
    public var size: Int64 = 0
    public var createdTime: TimeInterval = 0
    public var modifiedTime: TimeInterval = 0
    public var pcloudUser: PCloudDriveUserModel?

    /// File and folder IDs occupy different namespaces; accounts/regions must not share caches.
    public var identity: String {
        "pcloud-\(pcloudUser?.accountID ?? "unknown")-\(isFolder ? "folder" : "file")-\(id)"
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
    public func hash(into hasher: inout Hasher) { hasher.combine(identity) }

    public func isDirectory() -> Bool { isFolder }
    public func fileExtension() -> String { (name as NSString).pathExtension.lowercased() }
    public func isMusic() -> Bool {
        !isFolder && AudioExtensionType.allCases.contains { $0.rawValue == fileExtension() }
    }
    public func isVideo() -> Bool {
        !isFolder && VideoExtensionType.allCases.contains { $0.rawValue == fileExtension() }
    }

    /// A non-network placeholder with the original extension. Resolve getfilelink before use.
    public func mediaPlayURL() -> URL {
        URL(string: "pcloud://library")!.appendingPathComponent(identity).appendingPathComponent(name)
    }
}
