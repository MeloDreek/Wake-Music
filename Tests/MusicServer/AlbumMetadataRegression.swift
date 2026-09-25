import Foundation

struct MusicServerAlbum {
    let id: String
    let name: String
    let artist: String
    let songCount: Int?
    let coverArt: String
    var year: Int? = nil
    var genre = ""
    var duration: Int? = nil
}
enum MusicServerItem {
    case album(MusicServerAlbum), song(MusicServerRecord)
    var id: String {
        switch self { case .album(let album): return album.id; case .song(let song): return song.id }
    }
}
enum MusicServerRoute { case album(id: String), albums, playlists }
struct MusicServerPage {
    let items: [MusicServerItem]
    let total: Int?
    let hasMore: Bool
    var nextOffset: Int?
}
enum MusicServerError: Error { case invalidResponse, unavailable, unsupported }

@MainActor final class AlbumSessionFixture {
    let decoder = JSONDecoder()
    var responses: [String: [String: Any]] = [:]
    var calls: [String] = []
    var suspendAlbum = false
    var albumContinuation: CheckedContinuation<Void, Never>?
    // PRODUCTION_CACHE
    func subsonic(_ endpoint: String, query: [URLQueryItem]) async throws -> [String: Any] {
        calls.append(endpoint)
        if endpoint == "getAlbum", suspendAlbum {
            await withCheckedContinuation { albumContinuation = $0 }
        }
        await Task.yield()
        try Task.checkCancellation()
        guard let response = responses[endpoint] else { throw MusicServerError.unsupported }
        return response
    }
    func song(_ record: MusicServerRecord) -> MusicServerRecord { record }
    func item(_ record: MusicServerRecord, route: MusicServerRoute) -> MusicServerItem {
        .album(MusicServerAlbum(id: record.id, name: record.name, artist: record.artist, songCount: record.songCount,
                               coverArt: record.coverArt, year: record.year, genre: record.genre, duration: record.duration))
    }
    func allPlaylists() async throws -> [MusicServerItem] { [] }
    func page(id: String, offset: Int, limit: Int) async throws -> MusicServerPage {
        try await compatiblePage(.album(id: id), offset: offset, limit: limit)
    }
    // PRODUCTION_METHODS
}

@main enum AlbumMetadataRegression {
    @MainActor static func main() async throws {
        let fixture = AlbumSessionFixture()
        let songs: [[String: Any]] = (0..<63).map { ["id": "s\($0)", "track": $0 + 1, "suffix": "flac"] }
        fixture.responses["getAlbum"] = ["album": ["id": "a1", "name": "Album", "artist": "Artist", "year": 1999,
            "genre": "Rock", "duration": 3600, "songCount": 63, "song": songs + [["id": "s1"], ["id": ""]]]]
        async let header = fixture.albumDetails(id: "a1")
        async let first = fixture.page(id: "a1", offset: 0, limit: 40)
        let (album, page1) = try await (header, first)
        precondition(album.year == 1999 && album.genre == "Rock" && album.duration == 3600)
        precondition(fixture.calls.filter { $0 == "getAlbum" }.count == 1, "Concurrent header and songs must share one request")
        precondition(page1.items.count == 40 && page1.total == 63 && page1.hasMore && page1.nextOffset == 40)
        let page2 = try await fixture.page(id: "a1", offset: 40, limit: 40)
        precondition(page2.items.count == 23 && !page2.hasMore && page2.nextOffset == 63)
        precondition(page2.items.first?.id == "s40", "Preserve server track order across slices")
        precondition(fixture.calls.filter { $0 == "getAlbum" }.count == 1, "No repeated album fetch for each page")
        let end = try await fixture.page(id: "a1", offset: 63, limit: 40)
        precondition(end.items.isEmpty && !end.hasMore)

        do { _ = try await fixture.albumDescription(id: "a1"); fatalError("Missing info should be independent failure") } catch MusicServerError.unsupported {}
        let stillPlayable = try await fixture.page(id: "a1", offset: 0, limit: 40)
        precondition(stillPlayable.items.count == 40, "Optional notes failure must not evict playable album")
        fixture.responses["getAlbumInfo2"] = ["albumInfo": ["notes": "<p>A &amp; B</p>"]]
        let notes = try await fixture.albumDescription(id: "a1")
        precondition(notes == "A & B", "getAlbumInfo2 uses albumInfo, not albumInfo2")
        fixture.responses["getAlbumInfo2"] = ["albumInfo": [:]]
        let absent = try await fixture.albumDescription(id: "a1")
        precondition(absent == nil)

        fixture.invalidateAlbumDetails(id: "a1")
        fixture.responses["getAlbum"] = ["album": ["id": "wrong"]]
        do { _ = try await fixture.albumDetails(id: "a1"); fatalError("Wrong album ID") } catch MusicServerError.invalidResponse {}
        fixture.responses["getAlbum"] = ["album": ["id": "a1", "name": "Empty"]]
        let empty = try await fixture.page(id: "a1", offset: 0, limit: 40)
        precondition(empty.items.isEmpty && empty.total == 0 && !empty.hasMore)
        fixture.invalidateAlbumDetails(id: "a1")
        fixture.suspendAlbum = true
        let owner = Task { try await fixture.albumDetails(id: "a1") }
        while fixture.albumContinuation == nil { await Task.yield() }
        let waiter = Task { try await fixture.page(id: "a1", offset: 0, limit: 40) }
        for _ in 0..<4 { await Task.yield() }
        fixture.invalidateAlbumDetails(id: "a1")
        fixture.suspendAlbum = false
        fixture.albumContinuation?.resume()
        fixture.albumContinuation = nil
        do { _ = try await owner.value; fatalError("Invalidated owner must not publish") } catch is CancellationError {}
        do { _ = try await waiter.value; fatalError("Invalidated waiter must not publish") } catch is CancellationError {}
        let recovered = try await fixture.albumDetails(id: "a1")
        precondition(recovered.name == "Empty", "A cancelled shared request must not prevent a replacement")
        print("Album metadata regressions passed: shared request/cache, local pagination, order/dedup, optional notes isolation, HTML notes, absent fields, refresh, cancelled owner/waiter and wrong-ID rejection.")
    }
}
