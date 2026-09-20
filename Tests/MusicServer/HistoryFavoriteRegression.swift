import Foundation

// Only model types are stubbed; the test compiles the entire production History
// implementation and redirects its defaults to an isolated disposable suite.
struct NavidromeUserModel { let accountIdentity: String }
struct NavidromeSong {
    var id = ""
    var title = ""
    var artist = ""
    var artistId: String?
    var album = ""
    var albumId: String?
    var coverArt = ""
    var duration = 0
    var suffix = ""
    var size = 0
    var bitRate = 0
    var samplingRate = 0
    var channelCount = 2
    var trackNumber = 0
    var discNumber = 0
    var year: Int?
    var genre: String?
    var starred = false
    var navUser: NavidromeUserModel?
}
struct MusicItemModel { let navidromeSong: NavidromeSong?; var bitDepth: Int? }
struct MusicServerSong {
    let value: NavidromeSong
    let bitDepth: Int?
    var id: String { value.id }
}

let historyTestSuite = "Wakemusic.HistoryRegression." + UUID().uuidString
let historyTestDefaults = UserDefaults(suiteName: historyTestSuite)!

@main
enum HistoryFavoriteRegression {
    @MainActor
    static func main() {
        defer { historyTestDefaults.removePersistentDomain(forName: historyTestSuite) }
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        let first = NavidromeUserModel(accountIdentity: "account-one")
        let second = NavidromeUserModel(accountIdentity: "account-two")
        func play(_ id: String, user: NavidromeUserModel, starred: Bool = false) {
            var song = NavidromeSong()
            song.id = id
            song.title = "Track \(id)"
            song.artist = "Artist"
            song.duration = 321
            song.starred = starred
            song.navUser = user
            MusicServerHistory.recordPlayback(MusicItemModel(navidromeSong: song, bitDepth: 24))
        }
        play("a", user: first)
        play("b", user: first)
        play("a", user: second)
        let secondOriginal = historyTestDefaults.data(forKey: "MusicServer.Recent.v1.account-two")
        let before = MusicServerHistory.songs(user: first)
        MusicServerHistory.updateFavorite(accountID: first.accountIdentity, songID: "a", isFavorite: true)
        let after = MusicServerHistory.songs(user: first)
        expect(after.map(\.id) == before.map(\.id), "Favorite updates do not reorder listening history")
        expect(after.count == 2, "Favorite updates do not add a fake play")
        expect(after.first(where: { $0.id == "a" })?.value.starred == true, "Confirmed star survives re-reading cached recent songs")
        expect(after.first(where: { $0.id == "a" })?.bitDepth == 24 && after.first(where: { $0.id == "a" })?.value.duration == 321,
               "All other metadata is preserved")
        expect(historyTestDefaults.data(forKey: "MusicServer.Recent.v1.account-two") == secondOriginal,
               "Same song ID in another account is untouched")
        MusicServerHistory.updateFavorite(accountID: first.accountIdentity, songID: "a", isFavorite: false)
        expect(MusicServerHistory.songs(user: first).last?.value.starred == false, "Confirmed unstar also survives cached reads")
        let original = historyTestDefaults.data(forKey: "MusicServer.Recent.v1.account-one")
        MusicServerHistory.updateFavorite(accountID: first.accountIdentity, songID: "missing", isFavorite: true)
        expect(historyTestDefaults.data(forKey: "MusicServer.Recent.v1.account-one") == original, "An unplayed song does not enter recent history")
        MusicServerHistory.updateFavorite(accountID: first.accountIdentity, songID: "a", isFavorite: false)
        expect(historyTestDefaults.data(forKey: "MusicServer.Recent.v1.account-one") == original, "Repeated annotation is a no-op")
        MusicServerHistory.updateFavorite(accountID: "missing-account", songID: "a", isFavorite: true)
        expect(historyTestDefaults.data(forKey: "MusicServer.Recent.v1.missing-account") == nil, "Missing account never creates a history cache")
        for index in 0..<105 { play("\(index)", user: first) }
        let bounded = MusicServerHistory.songs(user: first)
        MusicServerHistory.updateFavorite(accountID: first.accountIdentity, songID: "104", isFavorite: true)
        let updatedBounded = MusicServerHistory.songs(user: first)
        expect(updatedBounded.count == 100 && updatedBounded.map(\.id) == bounded.map(\.id), "100-record bound and order remain intact")
        expect(updatedBounded.first?.value.starred == true, "Newest entry annotation updates without recording another play")
        print("History favorite regressions: \(checks) checks passed; isolated defaults, no server writes")
    }
}
