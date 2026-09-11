import Foundation

@main
enum MEGARegression {
    static func main() throws {
        let alice = MEGADriveUserModel(userID: "RootAAAA", email: "a@example.test", name: "MEGA")
        let same = MEGADriveUserModel(userID: "RootAAAA", email: "renamed@example.test", name: "Renamed")
        let bob = MEGADriveUserModel(userID: "RootBBBB", email: "b@example.test", name: "MEGA")
        precondition(alice == same && alice != bob)
        precondition(Set([alice, same, bob]).count == 2)
        var file = MEGADriveFileModel()
        file.id = "NodeAAAA"
        file.name = "夜曲 #1.FLAC"
        file.megaUser = alice
        precondition(file.isMusic() && !file.isVideo() && !file.isDirectory())
        precondition(file.fileExtension() == "flac")
        let url = file.mediaPlayURL()
        precondition(url.scheme == "mega" && url.user == nil && url.password == nil)
        precondition(url.lastPathComponent == file.name)
        let identity = file.identity
        file.name = "renamed.flac"
        precondition(file.identity == identity)
        file.megaUser = bob
        precondition(file.identity != identity)
        file.isFolder = true
        precondition(!file.isMusic() && file.isDirectory())
        let folderID = file.identity
        file.isFolder = false
        precondition(file.identity != folderID)
        file.name = "film.MP4"
        precondition(file.isVideo() && !file.isMusic())
        precondition(MEGAFileListEmptyState.empty(folderID: "0", query: "") == .folder)
        precondition(MEGAFileListEmptyState.empty(folderID: "0", query: "missing") == .search)
        precondition(MEGAFileListEmptyState.failure("network").message(localize: { $0 }) == "network")
        print("MEGA model and empty-state checks passed: 14")
    }
}
