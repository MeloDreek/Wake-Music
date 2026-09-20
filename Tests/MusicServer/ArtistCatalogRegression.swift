import Foundation

// PRODUCTION_ARTIST
// PRODUCTION_ERROR

enum AppMeta { static let identifier = "catalog-regression" }

@MainActor
final class CatalogSessionProbe {
    struct User { var hostUrl = "https://music.example.test/base"; var token = "test-token" }
    struct Reply { let status: Int; let body: Data; let total: Int? }
    var user = User()
    var accountID = "account-a"
    var authenticated = true
    var nativeAPIAvailable = true
    var replies: [Reply] = []
    var requests: [URLRequest] = []
    var byteLimits: [Int] = []
    var refreshCount = 0
    var afterSend: (() -> Void)?
    var artistCatalogCache: (accountID: String, artists: [MusicServerArtist])?
    var artistCatalogLoadID = UUID()
    var favoriteError: Error?

    func setFavorite(id: String, parameter: String, isFavorite: Bool) async throws {
        if let favoriteError { throw favoriteError }
    }

    func authenticate() async throws { refreshCount += 1; user.token = "refreshed-token"; authenticated = true }
    func subsonicURL(_ endpoint: String) -> URL? { URL(string: "https://music.example.test/base/rest/" + endpoint) }
    func send(_ request: URLRequest, maximumResponseBytes: Int = MusicServerWire.maximumResponseBytes) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        precondition(!replies.isEmpty, "Unexpected request")
        requests.append(request)
        byteLimits.append(maximumResponseBytes)
        let reply = replies.removeFirst()
        var headers: [String: String] = [:]
        if let total = reply.total { headers["X-Total-Count"] = String(total) }
        afterSend?()
        return (reply.body, HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: headers)!)
    }

    // PRODUCTION_METHODS
}

@main
enum ArtistCatalogRegression {
    @MainActor static func main() async throws {
        var checks = 0
        func expect(_ value: Bool, _ name: String) {
            precondition(value, name); checks += 1
        }
        func native(_ ids: [String], total: Int? = nil, status: Int = 200) throws -> CatalogSessionProbe.Reply {
            let objects = ids.map { ["id": $0, "name": "Artist " + $0, "starred": $0 == "1", "songCount": 2] as [String: Any] }
            return .init(status: status, body: try JSONSerialization.data(withJSONObject: objects), total: total)
        }
        func index(_ json: String) -> CatalogSessionProbe.Reply { .init(status: 200, body: Data(json.utf8), total: nil) }
        func expectFailure(_ session: CatalogSessionProbe, _ expected: MusicServerError, forceReload: Bool = false) async throws {
            do { _ = try await session.allArtists(forceReload: forceReload); preconditionFailure("Expected catalog failure") }
            catch let error as MusicServerError { expect(String(describing: error) == String(describing: expected), "Expected \(expected), got \(error)") }
        }

        let complete = CatalogSessionProbe()
        complete.replies = [try native((0..<1000).map(String.init), total: 1001), try native(["1000"], total: 1001)]
        var progress: [(Int, Int?)] = []
        let artists = try await complete.allArtists { loaded, total in progress.append((loaded, total)) }
        expect(progress.map(\.0) == [1000, 1001] && progress.allSatisfy { $0.1 == 1001 }, "Main-actor progress follows each successful batch")
        expect(artists.count == 1001, "All batches are collected before returning")
        expect(artists[1].starred && artists[1].songCount == 2, "Metadata and favorite retained")
        expect(artists[1].coverArt == "ar-1", "Native missing cover ID uses artist artwork endpoint")
        expect(complete.requests.count == 2, "Large batch is internal, not one request per visible page")
        expect(complete.requests.allSatisfy { $0.url!.path == "/base/api/artist" }, "Native complete artist list includes track artists")
        expect(complete.byteLimits == [4 * 1024 * 1024, 4 * 1024 * 1024], "Native response limits unchanged")
        let first = URLComponents(url: complete.requests[0].url!, resolvingAgainstBaseURL: false)!.queryItems!
        let second = URLComponents(url: complete.requests[1].url!, resolvingAgainstBaseURL: false)!.queryItems!
        expect(first.contains(.init(name: "_end", value: "1000")), "Native batch is exactly 1000")
        expect(first.contains(.init(name: "_sort", value: "id")), "Stable ID sort, not potentially identical artist names")
        expect(second.contains(.init(name: "_start", value: "1000")), "Raw offset advances")
        expect(complete.requests[0].value(forHTTPHeaderField: "X-ND-Authorization") == "Bearer test-token", "Native authorization preserved")
        let cached = try await complete.allArtists()
        expect(cached.count == 1001 && complete.requests.count == 2, "Returning to artist list reuses complete session snapshot without network")
        expect(complete.artistCatalogCache?.accountID == complete.accountID, "Snapshot is explicitly account scoped")
        try await complete.setArtistFavorite(id: "0", isFavorite: true)
        expect(try await complete.allArtists().first?.starred == true, "Successful favorite updates cached metadata")
        complete.favoriteError = MusicServerError.unavailable
        do { try await complete.setArtistFavorite(id: "0", isFavorite: false); preconditionFailure("Expected favorite failure") }
        catch MusicServerError.unavailable { checks += 1 }
        expect(try await complete.allArtists().first?.starred == true, "Failed favorite leaves cache unchanged")
        complete.favoriteError = nil
        complete.replies = [try native(["new"], total: 1)]
        expect(try await complete.allArtists(forceReload: true).map(\.id) == ["new"], "Explicit refresh fetches a new complete snapshot")
        expect(complete.requests.count == 3, "Force reload never returns previous cache")
        complete.replies = [try native([], status: 500)]
        try await expectFailure(complete, .unavailable, forceReload: true)
        expect(complete.artistCatalogCache == nil, "Failed explicit refresh does not keep an invalidated old snapshot")
        complete.replies = [try native(["recovered"], total: 1)]
        expect(try await complete.allArtists().map(\.id) == ["recovered"], "A failed refresh is retryable and not cached")
        complete.accountID = "account-b"
        complete.replies = [try native(["account-b-artist"], total: 1)]
        expect(try await complete.allArtists().map(\.id) == ["account-b-artist"], "A different account cannot reuse the previous account snapshot")

        let clampedServer = CatalogSessionProbe()
        clampedServer.replies = [try native(["0", "1"], total: 3), try native(["2"], total: 3)]
        expect(try await clampedServer.allArtists().count == 3, "Honor smaller server pages with explicit total")
        let clampedSecond = URLComponents(url: clampedServer.requests[1].url!, resolvingAgainstBaseURL: false)!.queryItems!
        expect(clampedSecond.contains(.init(name: "_start", value: "2")), "Clamped page advances by returned records")

        let empty = CatalogSessionProbe(); empty.replies = [try native([], total: 0)]
        expect(try await empty.allArtists().isEmpty, "An actually empty catalog succeeds")
        let premature = CatalogSessionProbe(); premature.replies = [try native(["0"], total: 2), try native([], total: 2)]
        try await expectFailure(premature, .invalidResponse)
        expect(premature.artistCatalogCache == nil, "A partial collection is never published to cache")
        let repeats = CatalogSessionProbe(); repeats.replies = [try native(["0", "1"], total: 4), try native(["0", "1"], total: 4)]
        try await expectFailure(repeats, .invalidResponse)
        let changed = CatalogSessionProbe(); changed.replies = [try native(["0"], total: 2), try native(["1"], total: 3)]
        try await expectFailure(changed, .invalidResponse)
        let overLimit = CatalogSessionProbe(); overLimit.replies = [try native(["0"], total: 250001)]
        try await expectFailure(overLimit, .responseTooLarge)
        expect(overLimit.requests.count == 1, "Oversized total stops immediately")
        let hugeBatch = CatalogSessionProbe(); hugeBatch.replies = [try native((0...1000).map(String.init), total: 1001)]
        try await expectFailure(hugeBatch, .responseTooLarge)
        let missingID = CatalogSessionProbe(); missingID.replies = [try native([""], total: 1)]
        try await expectFailure(missingID, .invalidResponse)

        let refresh = CatalogSessionProbe(); refresh.replies = [try native([], status: 401), try native(["0"], total: 1)]
        expect(try await refresh.allArtists().count == 1, "Expired native token retries after authenticate")
        expect(refresh.refreshCount == 1 && refresh.requests.count == 2, "Exactly one auth retry")
        expect(refresh.requests[1].value(forHTTPHeaderField: "X-ND-Authorization") == "Bearer refreshed-token", "Retry uses fresh token")
        let denied = CatalogSessionProbe(); denied.replies = [try native([], status: 401), try native([], status: 401)]
        try await expectFailure(denied, .expiredSession)
        expect(denied.refreshCount == 1, "Repeated auth failure never loops")
        let unsupported = CatalogSessionProbe(); unsupported.replies = [try native([], status: 404)]
        try await expectFailure(unsupported, .unsupported)
        expect(unsupported.requests.count == 1, "Native error never silently falls back to incomplete album-artist index")

        let compat = CatalogSessionProbe(); compat.nativeAPIAvailable = false
        compat.replies = [index(#"{"subsonic-response":{"status":"ok","artists":{"index":[{"name":"A","artist":[{"id":"a","name":"Alpha","albumCount":"2","starred":"2026-01-01"}]},{"name":"B","artist":[{"id":"b","name":"Beta","coverArt":"explicit"},{"id":"a","name":"Alpha"}]}]}}}"#)]
        let indexArtists = try await compat.allArtists()
        expect(indexArtists.map(\.id) == ["a", "b"], "Compatible index flattens and de-duplicates all groups")
        expect(indexArtists[0].starred && indexArtists[0].albumCount == 2, "Subsonic scalar aliases and starred date decode")
        expect(indexArtists[1].coverArt == "explicit", "Explicit artwork retained")
        expect(compat.byteLimits == [64 * 1024 * 1024], "Only full compatible index permits 64MiB")
        expect(compat.requests[0].url!.path == "/base/rest/getArtists", "Compatible endpoint uses getArtists")
        let emptyIndex = CatalogSessionProbe(); emptyIndex.nativeAPIAvailable = false
        emptyIndex.replies = [index(#"{"subsonic-response":{"status":"ok","artists":{}}}"#)]
        var indexProgress: [(Int, Int?)] = []
        expect(try await emptyIndex.allArtists { indexProgress.append(($0, $1)) }.isEmpty, "Missing optional index means valid empty artists")
        expect(indexProgress.count == 1 && indexProgress[0].0 == 0 && indexProgress[0].1 == 0, "An empty compatible catalog reports completion")
        let invalidIndex = CatalogSessionProbe(); invalidIndex.nativeAPIAvailable = false
        invalidIndex.replies = [index(#"{"subsonic-response":{"status":"ok"}}"#)]
        try await expectFailure(invalidIndex, .invalidResponse)
        for (code, expected) in [(40, MusicServerError.invalidCredentials), (70, .unsupported), (0, .unavailable)] {
            let errorIndex = CatalogSessionProbe(); errorIndex.nativeAPIAvailable = false
            errorIndex.replies = [index("{\"subsonic-response\":{\"status\":\"failed\",\"error\":{\"code\":\(code)}}}")]
            try await expectFailure(errorIndex, expected)
        }

        let unauthenticated = CatalogSessionProbe(); unauthenticated.authenticated = false
        try await expectFailure(unauthenticated, .expiredSession)
        expect(unauthenticated.requests.isEmpty, "No request before authentication")
        let accountSwitch = CatalogSessionProbe(); accountSwitch.replies = [try native(["0"], total: 1)]
        accountSwitch.afterSend = { accountSwitch.accountID = "account-b" }
        var wrongAccountProgress = false
        do { _ = try await accountSwitch.allArtists { _, _ in wrongAccountProgress = true }; preconditionFailure("Account change must discard results") }
        catch is CancellationError { checks += 1 }
        expect(!wrongAccountProgress, "Account switch suppresses progress from stale data")
        let canceled = CatalogSessionProbe()
        let operation = Task { try await canceled.allArtists() }
        operation.cancel()
        do { _ = try await operation.value; preconditionFailure("Cancelled catalog must not succeed") }
        catch is CancellationError { checks += 1 }
        expect(canceled.requests.isEmpty, "Pre-cancelled operation sends no request")
        let cancelDuringLoad = CatalogSessionProbe(); cancelDuringLoad.replies = [try native(["0"], total: 2)]
        cancelDuringLoad.afterSend = { withUnsafeCurrentTask { $0?.cancel() } }
        let interrupted = Task { try await cancelDuringLoad.allArtists() }
        do { _ = try await interrupted.value; preconditionFailure("Mid-load cancellation must fail") }
        catch is CancellationError { checks += 1 }
        expect(cancelDuringLoad.artistCatalogCache == nil, "Cancelled load leaves no partial snapshot")
        let superseded = CatalogSessionProbe(); superseded.replies = [try native(["0"], total: 1)]
        superseded.afterSend = { superseded.artistCatalogLoadID = UUID() }
        do { _ = try await superseded.allArtists(); preconditionFailure("An old load cannot publish after a replacement starts") }
        catch is CancellationError { checks += 1 }
        expect(superseded.artistCatalogCache == nil, "Generation check prevents late cache resurrection")
        expect(MusicServerWire.maximumPageSize == 100, "Interactive search/list pages retain original limit")

        // An index the size of the user's large server, without any network or real account.
        // Its JSON exceeds the normal 4MiB page cap and therefore exercises the dedicated path.
        let count = 90_000
        let entries = (0..<count).map { "{\"id\":\"artist-\($0)\",\"name\":\"Synthetic Artist \($0)\",\"albumCount\":2}" }.joined(separator: ",")
        let largeData = Data(("{\"subsonic-response\":{\"status\":\"ok\",\"artists\":{\"index\":[{\"name\":\"A\",\"artist\":[" + entries + "]}]}}}").utf8)
        let start = Date()
        let large = try await Task.detached { try MusicServerArtistCatalog.decodeIndex(largeData) }.value
        expect(large.count == count && large.last?.id == "artist-89999", "90k artist index decodes without truncation")
        expect(largeData.count > MusicServerWire.maximumResponseBytes, "Large index fixture really exceeds ordinary response cap")
        print("Synthetic index: \(count) artists, \(largeData.count / 1024) KiB, \(String(format: "%.2f", Date().timeIntervalSince(start)))s decode")
        print("Artist catalog regressions: \(checks) checks passed")
    }
}
