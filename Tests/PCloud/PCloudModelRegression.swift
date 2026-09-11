import Foundation
import SmartCodable

/// Runs against the real pCloud model, audio extensions and the vendored SmartCodable.
/// No account credentials, network, app initialization or user library access required.
@main
enum PCloudModelRegression {
    static func main() throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let us = PCloudDriveUserModel(userID: 101, serverRegionID: 1, apiHostName: "api.pcloud.com", email: "test@example.invalid")
        let eu = PCloudDriveUserModel(userID: 101, serverRegionID: 2, apiHostName: "eapi.pcloud.com", email: "test@example.invalid")
        check(us != eu, "Region participates in account identity")
        check(Set([us, eu]).count == 2, "Account hashes respect region")
        check(us.hasValidEndpoint && eu.hasValidEndpoint, "US/EU API endpoints are accepted")
        var invalid = us
        invalid.apiHostName = "api.pcloud.com.example.invalid"
        check(!invalid.hasValidEndpoint, "Reject a hostname suffix attack")
        invalid.apiHostName = eu.apiHostName
        check(!invalid.hasValidEndpoint, "Reject a region/host mismatch")
        invalid = us
        invalid.serverRegionID = 3
        check(!invalid.hasValidEndpoint, "Unknown regions fail closed")

        var file = PCloudDriveFileModel()
        file.id = 9_007_199_254_740_993
        file.parentFolderID = 0
        file.name = "测试 #1 & Live.FLAC"
        file.size = 40_000_000
        file.createdTime = 1_700_000_000
        file.modifiedTime = 1_700_001_000
        file.pcloudUser = us
        check(file.isMusic(), "Case-insensitive audio classification")
        check(!file.isVideo() && !file.isDirectory(), "Audio is neither video nor folder")
        check(file.mediaPlayURL().pathExtension == "FLAC", "Placeholder preserves codec extension")
        check(file.mediaPlayURL().lastPathComponent == file.name, "Unicode/special filenames round-trip through URL encoding")
        check(file.mediaPlayURL().scheme == "pcloud", "Placeholder is not a local file or a usable HTTP credential URL")

        var another = file
        another.pcloudUser = eu
        check(file != another, "Cross-region files are distinct")
        var secondUser = us
        secondUser.userID = 102
        another.pcloudUser = secondUser
        check(file != another, "Same-named files in different accounts are distinct")
        another = file
        another.id += 1
        check(file != another, "Same-named files in different folders have distinct IDs")
        another = file
        another.isFolder = true
        check(file != another, "Files and folders have separate ID namespaces")
        check(!another.isMusic() && !another.isVideo(), "A folder named .FLAC is not playable")
        another = file
        another.name = "renamed.flac"
        check(file == another && Set([file, another]).count == 1, "Rename does not duplicate favorites")

        let json = file.toJSONString()!
        let restored = PCloudDriveFileModel.deserialize(from: json)!
        check(restored.id == file.id, "64-bit file IDs retain integer precision")
        check(restored.name == file.name && restored.size == file.size, "File metadata persists")
        check(restored.pcloudUser?.apiHostName == us.apiHostName && restored.pcloudUser == us, "Account endpoint survives serialization")
        check(restored.identity == file.identity, "Identity is stable across app restarts")
        check(!json.lowercased().contains("token"), "Persisted file snapshots contain no OAuth token")
        let defaults = PCloudDriveFileModel.deserialize(from: "{}")!
        check(defaults.pcloudUser == nil && defaults.id == 0, "Missing fields remain safely defaulted")
        print("PASS: \(checks) pCloud model regression checks")
    }
}
