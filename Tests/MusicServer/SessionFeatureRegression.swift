import Foundation

// The runner injects unmodified production methods. Only account/model plumbing
// and transport are stubbed; this executable has no URLSession or live writes.
struct NavidromeUserModel {
    var hostUrl = "https://music.example.invalid/subpath"
    var username = "fixture+listener@example.invalid"
    var subsonicToken = "fixture-token"
    var subsonicSalt = "fixture-salt"
}
enum MusicServerError: Error, Equatable {
    case expiredSession, unsupported, invalidResponse, responseTooLarge
    case invalidAddress, invalidCredentials, unavailable
}
enum MusicServerItem {
    case song(MusicServerRecord), artist(MusicServerRecord)
    var id: String {
        switch self { case .song(let record), .artist(let record): return record.id }
    }
}
struct MusicServerPage {
    let items: [MusicServerItem]
    let total: Int?
    let hasMore: Bool
    var nextOffset: Int? = nil
}
struct MusicServerArtist { let id: String; var starred: Bool }

@MainActor
enum MusicServerHistory {
    struct FavoriteChange: Equatable {
        let accountID: String
        let songID: String
        let isFavorite: Bool
    }
    static var favoriteChanges: [FavoriteChange] = []
    static func updateFavorite(accountID: String, songID: String, isFavorite: Bool) {
        favoriteChanges.append(FavoriteChange(accountID: accountID, songID: songID, isFavorite: isFavorite))
    }
}

// PRODUCTION_ROUTE

@MainActor
final class SessionUnderTest {
    var authenticated = true
    var nativeAPIAvailable = true
    var accountID = "fixture-account-A"
    var user = NavidromeUserModel()
    let decoder = JSONDecoder()
    var requests: [URLRequest] = []
    var historyCountsAtSend: [Int] = []
    var nativeRecords: [MusicServerRecord] = []
    var nativeTotal: Int? = nil
    var payload: [String: Any] = ["status": "ok"]
    var responseStatus = 200
    var transportError: Error? = nil
    var artistCatalogCache: (accountID: String, artists: [MusicServerArtist])?

    func native(_ path: String, query: [URLQueryItem]) async throws -> (records: [MusicServerRecord], total: Int?) {
        requests.append(URLRequest(url: MusicServerWire.url(base: URL(string: user.hostUrl)!, path: path, query: query)!))
        return (nativeRecords, nativeTotal)
    }
    func item(_ record: MusicServerRecord, route: MusicServerRoute) -> MusicServerItem {
        route == .artists ? .artist(record) : .song(record)
    }
    func song(_ record: MusicServerRecord) -> MusicServerRecord { record }
    func recentPage(offset: Int, limit: Int) async throws -> MusicServerPage { throw MusicServerError.unsupported }
    func compatiblePage(_ route: MusicServerRoute, offset: Int, limit: Int) async throws -> MusicServerPage { throw MusicServerError.unsupported }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        historyCountsAtSend.append(MusicServerHistory.favoriteChanges.count)
        if let transportError { throw transportError }
        let data = try JSONSerialization.data(withJSONObject: ["subsonic-response": payload])
        return (data, HTTPURLResponse(url: request.url!, statusCode: responseStatus, httpVersion: nil, headerFields: nil)!)
    }

    // PRODUCTION_METHODS
}

// PRODUCTION_PLAYLIST_SUPPORT

@main
enum MusicServerSessionFeatureRegression {
    @MainActor
    static func main() async throws {
        var checks = 0
        func expect(_ value: @autoclosure () -> Bool, _ message: String) {
            precondition(value(), message)
            checks += 1
        }
        func query(_ request: URLRequest) -> [String: String] {
            let components: URLComponents?
            if let body = request.httpBody {
                components = URLComponents(string: "https://fixture.invalid/?" + String(decoding: body, as: UTF8.self))
            } else { components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) } }
            return Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        }
        func records(_ count: Int, emptyFirst: Bool = false) throws -> [MusicServerRecord] {
            let values = (0..<count).map { ["id": emptyFirst && $0 == 0 ? "" : "id-\($0)", "name": "Name \($0)"] }
            return try JSONDecoder().decode([MusicServerRecord].self, from: JSONSerialization.data(withJSONObject: values))
        }
        func expectError(_ error: MusicServerError, _ body: () async throws -> Void) async {
            do { try await body(); preconditionFailure("Expected \(error)") }
            catch let actual as MusicServerError { expect(actual == error, "Unexpected error \(actual)") }
            catch { preconditionFailure("Unexpected \(error)") }
        }
        func expectMutation(_ session: SessionUnderTest, endpoint: String, expected: [String: String]) {
            expect(session.requests.count == 1, "Mutation must send exactly one request")
            let request = session.requests[0]
            expect(request.httpMethod == "POST", "Mutation must use form POST")
            expect(request.url?.path == "/subpath/rest/" + endpoint, "Correct endpoint and reverse-proxy base")
            expect(request.url?.query == nil, "Tokens and mutation parameters do not leak into URL query")
            expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded; charset=utf-8", "Form content type")
            let values = query(request)
            expect(values["u"] == session.user.username && values["t"] == session.user.subsonicToken, "Real URL helper carries account-scoped credentials into body")
            for (key, value) in expected { expect(values[key] == value, "Correct mutation parameter \(key)") }
        }

        expect(MusicServerWire.maximumPageSize == 100, "Request cap stays at 100")
        let artists = SessionUnderTest()
        artists.nativeRecords = try records(100, emptyFirst: true)
        artists.nativeTotal = 89_440
        let first = try await artists.artistPage(offset: -1, limit: 10_000, query: "  周 + R&B  \n", starredOnly: true)
        let params = query(artists.requests[0])
        expect(artists.requests[0].url?.path == "/subpath/api/artist", "Artist native endpoint")
        expect(params["_start"] == "0" && params["_end"] == "100", "Negative offset normalized and oversized limit capped")
        expect(params["_sort"] == "name" && params["_order"] == "ASC", "Artists sorted by name")
        expect(params["name"] == "周 + R&B" && params["starred"] == "true", "Search trimmed, encoded, and combined with server-side favorites")
        expect(first.items.count == 99 && first.nextOffset == 100, "Missing IDs hidden without losing raw pagination cursor")
        expect(first.total == 89_440 && first.hasMore, "Large total remains metadata, not an unbounded fetch")
        expect(artists.requests.count == 1, "One page never crawls the full artist library")

        let one = SessionUnderTest()
        let empty = try await one.artistPage(offset: 30, limit: 0, query: "\n ")
        let smallParams = query(one.requests[0])
        expect(smallParams["_start"] == "30" && smallParams["_end"] == "31", "Nonpositive limit clamps to one")
        expect(smallParams["name"] == nil && smallParams["starred"] == nil, "Empty query and unselected favorite filter are omitted")
        expect(empty.items.isEmpty && !empty.hasMore && empty.nextOffset == 30, "Empty artists stop pagination")
        one.nativeRecords = try records(2)
        await expectError(.responseTooLarge) { _ = try await one.artistPage(limit: 1) }
        one.nativeRecords = try records(2)
        one.nativeTotal = 32
        let last = try await one.artistPage(offset: 30, limit: 2)
        expect(!last.hasMore && last.nextOffset == 32, "Known artist total terminates on last page")

        let compatible = SessionUnderTest()
        compatible.nativeAPIAvailable = false
        compatible.payload = ["status": "ok", "searchResult3": ["artist": [["id": "artist-a", "name": "A"]]]]
        let searched = try await compatible.artistPage(offset: 4, limit: 999, query: "  A+B  ")
        let searchParams = query(compatible.requests[0])
        expect(compatible.requests[0].url?.path == "/subpath/rest/search3", "Compatible artist search uses paginated search3")
        expect(searchParams["artistOffset"] == "4" && searchParams["artistCount"] == "100", "Compatible search is bounded")
        expect(searchParams["songCount"] == "0" && searchParams["albumCount"] == "0", "No unrelated song/album payload")
        expect(searchParams["query"] == "A+B" && searched.items.count == 1, "Compatible artist query round-trips literal plus")
        compatible.requests.removeAll()
        await expectError(.unsupported) { _ = try await compatible.artistPage() }
        await expectError(.unsupported) { _ = try await compatible.artistPage(query: "A", starredOnly: true) }
        expect(compatible.requests.isEmpty, "No unbounded getArtists/getStarred2 fallback")

        let uploaded = SessionUnderTest()
        uploaded.nativeRecords = try records(20)
        uploaded.nativeTotal = 456_749
        let latest = try await uploaded.page(.recentlyAdded, limit: 20)
        let recentParams = query(uploaded.requests[0])
        expect(uploaded.requests[0].url?.path == "/subpath/api/song", "Latest uploads query songs directly")
        expect(recentParams["_sort"] == "created_at" && recentParams["_order"] == "DESC", "Upload/import creation order, not release date or modification")
        expect(recentParams["_start"] == "0" && recentParams["_end"] == "20", "Home latest-upload range is exactly 20")
        expect(recentParams["starred"] == nil && latest.items.count == 20 && latest.hasMore, "Uploads not accidentally limited to favorites")
        uploaded.requests.removeAll()
        _ = try await uploaded.page(.recentlyAdded, offset: -9, limit: 999)
        expect(query(uploaded.requests[0])["_end"] == "100", "Latest uploads also obey general request cap")
        uploaded.nativeRecords = try records(21)
        await expectError(.responseTooLarge) { _ = try await uploaded.page(.recentlyAdded, limit: 20) }

        let signedOut = SessionUnderTest()
        signedOut.authenticated = false
        await expectError(.expiredSession) { _ = try await signedOut.artistPage() }
        await expectError(.expiredSession) { _ = try await signedOut.page(.recentlyAdded) }
        await expectError(.expiredSession) { try await signedOut.setArtistFavorite(id: "a", isFavorite: true) }
        await expectError(.expiredSession) { try await signedOut.setSongFavorite(id: "s", isFavorite: false) }
        await expectError(.expiredSession) { try await signedOut.addSongToPlaylist(songID: "s", playlistID: "p") }
        expect(signedOut.requests.isEmpty, "No request leaves an unauthenticated session")
        expect(MusicServerHistory.favoriteChanges.isEmpty, "Unauthenticated favorite changes must not update cached history")

        let invalid = SessionUnderTest()
        await expectError(.invalidResponse) { try await invalid.setArtistFavorite(id: "", isFavorite: true) }
        await expectError(.invalidResponse) { try await invalid.setSongFavorite(id: "", isFavorite: true) }
        await expectError(.invalidResponse) { try await invalid.addSongToPlaylist(songID: "", playlistID: "p") }
        await expectError(.invalidResponse) { try await invalid.addSongToPlaylist(songID: "s", playlistID: "") }
        expect(invalid.requests.isEmpty, "Empty identifiers never reach transport")
        expect(MusicServerHistory.favoriteChanges.isEmpty, "Invalid favorite IDs must not update cached history")

        for selected in [true, false] {
            MusicServerHistory.favoriteChanges.removeAll()
            let artist = SessionUnderTest()
            try await artist.setArtistFavorite(id: "artist + &=", isFavorite: selected)
            expectMutation(artist, endpoint: selected ? "star" : "unstar", expected: ["artistId": "artist + &="])
            expect(query(artist.requests[0])["id"] == nil, "Artist favorite must not target a song ID")
            expect(MusicServerHistory.favoriteChanges.isEmpty, "Artist likes must not modify song history")
            let song = SessionUnderTest()
            song.accountID = selected ? "fixture-account-A" : "fixture-account-B"
            try await song.setSongFavorite(id: "song + &=", isFavorite: selected)
            expectMutation(song, endpoint: selected ? "star" : "unstar", expected: ["id": "song + &="])
            expect(query(song.requests[0])["artistId"] == nil, "Song favorite must not target an artist ID")
            expect(song.historyCountsAtSend == [0], "Cached song history is not updated before the server accepts the write")
            expect(MusicServerHistory.favoriteChanges == [MusicServerHistory.FavoriteChange(accountID: song.accountID, songID: "song + &=", isFavorite: selected)],
                   "Successful song favorite changes persist once to the correct account, song, and selected state")
        }
        MusicServerHistory.favoriteChanges.removeAll()
        let playlist = SessionUnderTest()
        try await playlist.addSongToPlaylist(songID: "song + 音乐", playlistID: "playlist &=🎵")
        expectMutation(playlist, endpoint: "updatePlaylist", expected: ["playlistId": "playlist &=🎵", "songIdToAdd": "song + 音乐"])
        let playlistParams = query(playlist.requests[0])
        expect(playlistParams["songId"] == nil && playlistParams["songIndexToRemove"] == nil && playlistParams["name"] == nil,
               "Adding a song neither replaces tracks nor renames/deletes a playlist")
        expect(MusicServerHistory.favoriteChanges.isEmpty, "Playlist membership changes do not alter favorite history")

        let ambiguous = SessionUnderTest()
        ambiguous.transportError = URLError(.timedOut)
        do { try await ambiguous.addSongToPlaylist(songID: "s", playlistID: "p"); preconditionFailure("Expected timeout") }
        catch { expect(ambiguous.requests.count == 1, "An ambiguous write failure never retries or falls back to GET") }
        let oldServer = SessionUnderTest()
        oldServer.payload = ["status": "failed", "error": ["code": 10]]
        await expectError(.unsupported) { try await oldServer.setArtistFavorite(id: "a", isFavorite: true) }
        expect(oldServer.requests.count == 1 && oldServer.requests[0].httpMethod == "POST", "Unsupported form POST never falls back to mutating GET")

        let failedFavorite = SessionUnderTest()
        failedFavorite.transportError = URLError(.timedOut)
        do { try await failedFavorite.setSongFavorite(id: "s", isFavorite: true); preconditionFailure("Expected favorite timeout") }
        catch { expect(failedFavorite.requests.count == 1, "Ambiguous favorite write is not retried") }
        expect(MusicServerHistory.favoriteChanges.isEmpty, "Failed favorite transport must not publish success to cached history")
        let rejectedFavorite = SessionUnderTest()
        rejectedFavorite.payload = ["status": "failed", "error": ["code": 40]]
        await expectError(.invalidCredentials) { try await rejectedFavorite.setSongFavorite(id: "s", isFavorite: false) }
        expect(MusicServerHistory.favoriteChanges.isEmpty, "Server-rejected favorite mutation leaves cached history unchanged")
        let expiredFavorite = SessionUnderTest()
        expiredFavorite.responseStatus = 401
        await expectError(.expiredSession) { try await expiredFavorite.setSongFavorite(id: "s", isFavorite: false) }
        expect(MusicServerHistory.favoriteChanges.isEmpty, "Expired server authentication leaves cached history unchanged")

        print("MusicServer session feature regressions: \(checks) checks passed; extracted production methods, OFFLINE only")
    }
}
