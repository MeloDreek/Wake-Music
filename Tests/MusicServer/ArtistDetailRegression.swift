import Foundation

struct MusicServerArtist { let id: String; let name: String; let albumCount: Int?; let songCount: Int?; let coverArt: String; var starred = false }
struct TestSong { let id: String; let suffix: String }
enum MusicServerItem { case artist(MusicServerArtist), album(String), song(TestSong) }
enum MusicServerRoute { case artists, albums }
enum MusicServerError: Error { case invalidResponse, unavailable }

@MainActor final class ArtistSessionFixture {
    let decoder = JSONDecoder()
    var responses: [String: [String: Any]] = [:]
    var calls: [(String, [URLQueryItem])] = []
    func subsonic(_ endpoint: String, query: [URLQueryItem]) async throws -> [String: Any] {
        try Task.checkCancellation()
        calls.append((endpoint, query))
        guard let response = responses[endpoint] else { throw MusicServerError.unavailable }
        return response
    }
    func song(_ record: MusicServerRecord) -> TestSong { TestSong(id: record.id, suffix: record.suffix) }
    func item(_ record: MusicServerRecord, route: MusicServerRoute) -> MusicServerItem {
        switch route {
        case .artists: return .artist(MusicServerArtist(id: record.id, name: record.name, albumCount: record.albumCount, songCount: record.songCount, coverArt: record.coverArt))
        case .albums: return .album(record.id)
        }
    }
    // PRODUCTION_METHODS
}

@main enum ArtistDetailRegression {
    @MainActor static func main() async throws {
        let fixture = ArtistSessionFixture()
        fixture.responses["getArtist"] = ["artist": ["id": "ar1", "name": "Artist & +", "album": [["id": "al1", "name": "Album"], ["id": "al1"], ["id": ""]]]]
        let detail = try await fixture.artistDetails(id: "ar1")
        precondition(detail.artist.name == "Artist & +" && detail.albums.count == 1)
        fixture.responses["getArtist"] = ["artist": ["id": "wrong"]]
        do { _ = try await fixture.artistDetails(id: "ar1"); fatalError("Must reject unrelated artist") } catch MusicServerError.invalidResponse {}
        fixture.responses["getArtist"] = ["artist": ["id": "ar1", "name": "Empty"]]
        let emptyArtist = try await fixture.artistDetails(id: "ar1")
        precondition(emptyArtist.albums.isEmpty)
        fixture.responses["getTopSongs"] = ["topSongs": ["song": (0..<45).map { ["id": "s\($0)", "title": "Track", "suffix": "FLAC"] }]]
        let songs = try await fixture.artistTopSongs(name: "Artist & +", limit: 1000)
        precondition(songs.count == 30)
        guard case .song(let first) = songs[0] else { fatalError("Song mapping") }
        precondition(first.suffix == "FLAC", "Keep format metadata for the model placeholder")
        let query = Dictionary(uniqueKeysWithValues: fixture.calls.last!.1.map { ($0.name, $0.value ?? "") })
        precondition(query["artist"] == "Artist & +" && query["count"] == "30")
        let callCount = fixture.calls.count
        let noName = try await fixture.artistTopSongs(name: "  ")
        precondition(noName.isEmpty && fixture.calls.count == callCount)
        fixture.responses["getTopSongs"] = ["topSongs": ["song": [["id": "s1"], ["id": "s1"], ["id": ""]]]]
        let deduped = try await fixture.artistTopSongs(name: "Artist")
        precondition(deduped.count == 1)
        fixture.responses["getTopSongs"] = ["topSongs": [:]]
        let empty = try await fixture.artistTopSongs(name: "Artist")
        precondition(empty.isEmpty)
        fixture.responses["getTopSongs"] = [:]
        do { _ = try await fixture.artistTopSongs(name: "Artist"); fatalError("Malformed response must not look empty") } catch MusicServerError.invalidResponse {}
        fixture.responses["getArtistInfo2"] = ["artistInfo2": ["similarArtist": [["id": "ar1"], ["id": "ar2", "name": "Other"], ["id": "ar2"], ["id": "-1"], ["id": ""]]]]
        let similar = try await fixture.similarArtists(id: "ar1")
        precondition(similar.count == 1)
        guard case .artist(let other) = similar[0] else { fatalError("Artist mapping") }
        precondition(other.id == "ar2")
        let similarQuery = Dictionary(uniqueKeysWithValues: fixture.calls.last!.1.map { ($0.name, $0.value ?? "") })
        precondition(similarQuery["includeNotPresent"] == "false" && similarQuery["id"] == "ar1")
        fixture.responses["getArtistInfo2"] = ["artistInfo2": [:]]
        let noSimilar = try await fixture.similarArtists(id: "ar1")
        precondition(noSimilar.isEmpty)
        fixture.responses["getArtistInfo2"] = [:]
        do { _ = try await fixture.similarArtists(id: "ar1"); fatalError("Invalid similar response") } catch MusicServerError.invalidResponse {}
        print("Artist detail production-method regressions passed: parameters, deduplication, 30-song cap, format, empty/malformed responses, library-only similar artists.")
    }
}
