import Foundation
import AppGroupKit

/// Local recent plays are account-scoped, bounded and deliberately contain no credentials or signed URLs.
/// This does not submit scrobbles or alter the user's remote listening history.
@MainActor
enum MusicServerHistory {
    static let didChange = Notification.Name("MusicServerHistoryDidChange")
    private static var lastRecordedID: String?
    private static let maximumRecords = 100

    static func recordPlayback(_ model: MusicItemModel) {
        guard let song = model.navidromeSong, let user = song.navUser, !song.id.isEmpty,
              !song.id.hasPrefix("radio-") else { lastRecordedID = nil; return }
        let accountID = user.accountIdentity
        let identity = accountID + ":" + song.id
        guard lastRecordedID != identity else { return }
        lastRecordedID = identity
        var records = read(accountID)
        records.removeAll { $0.id == song.id }
        records.insert(Entry(song: song, bitDepth: model.bitDepth), at: 0)
        if let data = try? JSONEncoder().encode(Array(records.prefix(maximumRecords))) {
            UserDefaults.standard.set(data, forKey: storageKey(accountID))
            NotificationCenter.default.post(name: didChange, object: accountID)
        }
    }

    static func songs(user: NavidromeUserModel) -> [MusicServerSong] {
        read(user.accountIdentity).map { $0.song(user: user) }
    }

    /// A confirmed remote annotation must survive a homepage refresh. This changes
    /// metadata only: favoriting never creates a play, reorders history or emits a play notification.
    static func updateFavorite(accountID: String, songID: String, isFavorite: Bool) {
        guard !accountID.isEmpty, !songID.isEmpty else { return }
        var records = read(accountID)
        guard let index = records.firstIndex(where: { $0.id == songID }),
              records[index].starred != isFavorite else { return }
        records[index].starred = isFavorite
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey(accountID))
        }
    }

    private static func storageKey(_ accountID: String) -> String { "MusicServer.Recent.v1." + accountID }
    private static func read(_ accountID: String) -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey(accountID)), data.count <= 512 * 1024,
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return Array(entries.prefix(maximumRecords))
    }

    private struct Entry: Codable {
        let id: String
        let title: String
        let artist: String
        let artistID: String?
        let album: String
        let albumID: String?
        let coverArt: String
        let duration: Int
        let suffix: String
        let size: Int
        let bitRate: Int
        let sampleRate: Int
        let channels: Int
        let bitDepth: Int?
        let track: Int
        let disc: Int
        let year: Int?
        let genre: String?
        var starred: Bool?

        init(song: NavidromeSong, bitDepth: Int?) {
            id = song.id; title = song.title; artist = song.artist; artistID = song.artistId
            album = song.album; albumID = song.albumId; coverArt = song.coverArt
            duration = song.duration; suffix = song.suffix; size = song.size; bitRate = song.bitRate
            sampleRate = song.samplingRate; channels = song.channelCount; self.bitDepth = bitDepth
            track = song.trackNumber; disc = song.discNumber; year = song.year; genre = song.genre; starred = song.starred
        }

        func song(user: NavidromeUserModel) -> MusicServerSong {
            var value = NavidromeSong()
            value.id = id; value.title = title; value.artist = artist; value.artistId = artistID
            value.album = album; value.albumId = albumID; value.coverArt = coverArt
            value.duration = duration; value.suffix = suffix; value.size = size; value.bitRate = bitRate
            value.samplingRate = sampleRate; value.channelCount = channels
            value.trackNumber = track; value.discNumber = disc; value.year = year; value.genre = genre
            value.starred = starred ?? false
            value.navUser = user
            return MusicServerSong(value: value, bitDepth: bitDepth)
        }
    }
}
