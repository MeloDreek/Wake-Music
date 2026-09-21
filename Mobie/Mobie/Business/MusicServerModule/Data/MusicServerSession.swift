import Foundation
import AppGroupKit

enum MusicServerRoute: Hashable {
    case songs, artists, albums, radios, recent, favorites, playlists, random, recentlyAdded
    case playlist(id: String), album(id: String), artist(id: String)
    case search(query: String, kind: MusicServerSearchKind)
}

struct MusicServerOverview {
    var songs: Int?
    var artists: Int?
    var albums: Int?
    var radios: Int?
}

struct MusicServerSong {
    var value: NavidromeSong
    let bitDepth: Int?
    var id: String { value.id }
    var title: String { value.title }
    var artist: String { value.artist }
    var album: String { value.album }
    var coverArt: String { value.coverArt }
}

struct MusicServerArtist { let id: String; let name: String; let albumCount: Int?; let songCount: Int?; let coverArt: String; var starred: Bool = false }
struct MusicServerAlbum { let id: String; let name: String; let artist: String; let songCount: Int?; let coverArt: String }
struct MusicServerPlaylist { let id: String; let name: String; let songCount: Int?; let coverArt: String; let owner: String }
struct MusicServerRadio { let id: String; let name: String; let streamURL: URL? }

enum MusicServerItem {
    case song(MusicServerSong), artist(MusicServerArtist), album(MusicServerAlbum), playlist(MusicServerPlaylist), radio(MusicServerRadio)
    var id: String {
        switch self {
        case .song(let item): return "song:" + item.id
        case .artist(let item): return "artist:" + item.id
        case .album(let item): return "album:" + item.id
        case .playlist(let item): return "playlist:" + item.id
        case .radio(let item): return "radio:" + item.id
        }
    }
    var title: String {
        switch self {
        case .song(let item): return item.title
        case .artist(let item): return item.name
        case .album(let item): return item.name
        case .playlist(let item): return item.name
        case .radio(let item): return item.name
        }
    }
    var subtitle: String {
        switch self {
        case .song(let item): return item.artist
        case .album(let item): return item.artist
        case .playlist(let item): return item.owner
        case .artist, .radio: return ""
        }
    }
    var artworkID: String {
        switch self {
        case .song(let item): return item.coverArt
        case .artist(let item): return item.coverArt
        case .album(let item): return item.coverArt
        case .playlist(let item): return item.coverArt
        case .radio: return ""
        }
    }
}

struct MusicServerPage {
    let items: [MusicServerItem]
    /// nil means not supplied by the server, not an empty library.
    let total: Int?
    let hasMore: Bool
    /// Raw pagination cursor, which may differ from visible count after duplicate/history filtering.
    var nextOffset: Int? = nil
}

enum MusicServerError: LocalizedError {
    case invalidAddress, invalidCredentials, expiredSession, unsupported, invalidResponse, responseTooLarge, unavailable, timeout
    var errorDescription: String? {
        let key: String
        switch self {
        case .invalidAddress: key = "The server address is invalid."
        case .invalidCredentials: key = "Unable to sign in. Check your username and password."
        case .expiredSession: key = "Your music server session has expired. Please sign in again."
        case .unsupported: key = "This server does not support this feature."
        case .invalidResponse: key = "The music server returned an invalid response."
        case .responseTooLarge: key = "The server returned too much data. Please try a smaller page."
        case .unavailable: key = "Unable to connect to the music server. Please try again."
        case .timeout: key = "The server request timed out. Please try again."
        }
        return NSLocalizedString(key, comment: "Music server request error")
    }
}

/// Account-scoped homepage client. Native endpoints are an optional pagination enhancement;
/// authentication, random discovery and media URLs speak the Subsonic protocol.
@MainActor
final class MusicServerSession {
    private(set) var user: NavidromeUserModel
    var accountID: String { Self.identity(for: user) }
    private var authenticated = false
    private var nativeAPIAvailable = false
    private let authenticationFlight = MusicServerAuthenticationFlight<NavidromeUserModel>()
    private let transport: URLSession
    private let decoder = JSONDecoder()
    /// Complete metadata only, scoped to this account/session. Explicit pull-to-refresh replaces it.
    private var artistCatalogCache: (accountID: String, artists: [MusicServerArtist])?
    private var artistCatalogLoadID = UUID()

    var hasCachedArtistCatalog: Bool { artistCatalogCache?.accountID == accountID }

    /// Open the server UI without leaking API credentials or token query parameters.
    var webURL: URL? {
        guard var components = URLComponents(string: user.hostUrl.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              let host = components.host, !host.isEmpty else { return nil }
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        return components.url
    }

    init(user: NavidromeUserModel) {
        self.user = user
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpMaximumConnectionsPerHost = 4
        self.transport = URLSession(configuration: config, delegate: MusicServerRedirectPolicy(), delegateQueue: nil)
    }

    deinit { transport.invalidateAndCancel() }

    static func identity(for user: NavidromeUserModel) -> String {
        user.accountIdentity
    }

    @discardableResult
    func authenticate() async throws -> NavidromeUserModel {
        try Task.checkCancellation()
        if authenticated { return user }
        return try await authenticationFlight.value { generation in
            try await self.performAuthentication(generation: generation)
        }
    }

    private func performAuthentication(generation: UUID) async throws -> NavidromeUserModel {
        guard let base = MusicServerWire.normalizedBaseURL(user.hostUrl),
              let loginURL = MusicServerWire.url(base: base, path: "/auth/login") else { throw MusicServerError.invalidAddress }
        var updated = user
        updated.hostUrl = base.absoluteString
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(LoginRequest(username: user.username, password: user.password))
        let (data, response) = try await send(request)
        try Task.checkCancellation()
        guard authenticationFlight.isCurrent(generation) else { throw CancellationError() }
        let supportsNativeAPI: Bool
        if (200..<300).contains(response.statusCode), let login = try? decoder.decode(LoginResponse.self, from: data), !login.token.isEmpty {
            updated.id = login.id ?? updated.id
            updated.name = login.name ?? updated.name
            updated.isAdmin = login.isAdmin ?? false
            updated.token = login.token
            updated.subsonicSalt = login.subsonicSalt ?? ""
            updated.subsonicToken = login.subsonicToken ?? ""
            supportsNativeAPI = true
        } else {
            // A compatible Subsonic server may have no Navidrome web-login endpoint at all.
            // Validate its credentials using ping, without ever sending a plaintext password in a URL.
            if ![200, 401, 403, 404, 405].contains(response.statusCode) { try validate(response, authentication: true) }
            updated.token = ""
            updated.subsonicSalt = ""
            updated.subsonicToken = ""
            supportsNativeAPI = false
        }
        if updated.subsonicSalt.isEmpty || updated.subsonicToken.isEmpty {
            let salt = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            updated.subsonicSalt = salt
            updated.subsonicToken = MusicServerWire.token(password: updated.password, salt: salt)
        }
        _ = try await subsonic("ping", authenticatedUser: updated)
        try Task.checkCancellation()
        guard authenticationFlight.isCurrent(generation) else { throw CancellationError() }
        // Only a completely verified, still-current generation may publish credentials.
        user = updated
        nativeAPIAvailable = supportsNativeAPI
        authenticated = true
        // Refresh existing records only. A new login is saved by the owning login coordinator.
        var accounts = ConnectConfigManager.shared.connectedModels
        if let index = accounts.firstIndex(where: { $0.navUser.map(Self.identity(for:)) == accountID }) {
            accounts[index].navUser = updated
            ConnectConfigManager.shared.connectedModels = accounts
        }
        return updated
    }

    func overview() async throws -> MusicServerOverview {
        guard authenticated else { throw MusicServerError.expiredSession }
        guard nativeAPIAvailable else { return MusicServerOverview() }
        async let songCount = count("/api/song")
        async let artistCount = count("/api/artist")
        async let albumCount = count("/api/album")
        async let radioCount = count("/api/radio")
        let values = await (songCount, artistCount, albumCount, radioCount)
        try Task.checkCancellation()
        if values.0 == nil && values.1 == nil && values.2 == nil && values.3 == nil { throw MusicServerError.unavailable }
        return MusicServerOverview(songs: values.0, artists: values.1, albums: values.2, radios: values.3)
    }

    private func count(_ path: String) async -> Int? {
        guard let result = try? await native(path, query: [.init(name: "_start", value: "0"), .init(name: "_end", value: "1")]) else { return nil }
        // A true empty array may certify zero; a one-item preview never implies the total is one.
        return result.total ?? (result.records.isEmpty ? 0 : nil)
    }

    /// Playlist metadata is deliberately fetched in one bounded request: the Subsonic endpoint
    /// returns every accessible playlist, but never the songs inside those playlists.
    func allPlaylists() async throws -> [MusicServerItem] {
        try Task.checkCancellation()
        guard authenticated else { throw MusicServerError.expiredSession }
        let response = try await subsonic("getPlaylists")
        let playlists = try records(response, container: "playlists", key: "playlist")
        try Task.checkCancellation()
        return MusicServerPlaylistSupport.uniquePlaylists(playlists).map { item($0, route: .playlists) }
    }

    /// Do not retry a mutation after a timeout: the server may already have created it.
    func createPlaylist(name: String) async throws {
        try Task.checkCancellation()
        guard authenticated else { throw MusicServerError.expiredSession }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw MusicServerError.invalidResponse }
        _ = try await subsonic("createPlaylist", query: [.init(name: "name", value: name)], useFormPost: true)
    }

    func page(_ route: MusicServerRoute, offset: Int = 0, limit: Int = 40) async throws -> MusicServerPage {
        guard authenticated else { throw MusicServerError.expiredSession }
        let start = max(0, offset)
        let size = min(max(1, limit), MusicServerWire.maximumPageSize)
        if case .search(let query, let kind) = route {
            // Empty queries stay local; never turn clearing the search field into a library scan.
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return MusicServerPage(items: [], total: 0, hasMore: false, nextOffset: 0)
            }
            let response = try await subsonic("search3", query: kind.parameters(query: query, offset: start, limit: size))
            let matches = try records(response, container: "searchResult3", key: kind.responseKey)
            guard matches.count <= size else { throw MusicServerError.responseTooLarge }
            let category: MusicServerRoute = kind == .artists ? .artists : kind == .albums ? .albums : .songs
            return MusicServerPage(items: matches.filter { !$0.id.isEmpty }.map { item($0, route: category) },
                                   total: matches.count < size ? start + matches.count : nil,
                                   hasMore: matches.count == size, nextOffset: start + matches.count)
        }
        if route == .recent { return try await recentPage(offset: start, limit: size) }
        if route == .random {
            let response = try await subsonic("getRandomSongs", query: [.init(name: "size", value: String(size))])
            let records = try records(response, container: "randomSongs", key: "song")
            return MusicServerPage(items: records.prefix(size).map { .song(song($0)) }, total: nil, hasMore: false)
        }
        guard nativeAPIAvailable else { return try await compatiblePage(route, offset: start, limit: size) }
        var query = [URLQueryItem(name: "_start", value: String(start)), .init(name: "_end", value: String(start + size))]
        var path: String
        let sort: String
        switch route {
        case .songs: path = "/api/song"; sort = "title"
        case .recent: path = "/api/song"; sort = "play_date"
        // Creation time is the server's library import time, not release year or last playback.
        case .recentlyAdded: path = "/api/song"; sort = "created_at"
        case .favorites: path = "/api/song"; sort = "starred_at"; query.append(.init(name: "starred", value: "true"))
        case .artists: path = "/api/artist"; sort = "name"
        case .albums: path = "/api/album"; sort = "name"
        case .radios: path = "/api/radio"; sort = "name"
        case .playlists: path = "/api/playlist"; sort = "name"
        case .artist(let id): path = "/api/album"; sort = "name"; query.append(.init(name: "artist_id", value: id))
        case .album(let id): path = "/api/song"; sort = "disc_number,track_number"; query.append(.init(name: "album_id", value: id))
        case .playlist(let id):
            // Playlist IDs originate from the server. Encode each path segment before appending.
            guard !id.isEmpty, !id.contains("/"), !id.contains("?"), !id.contains("#"), id != ".", id != ".." else { throw MusicServerError.invalidResponse }
            path = "/api/playlist/\(id)/tracks"; sort = "id"
        case .random, .search: throw MusicServerError.unsupported
        }
        query.append(.init(name: "_sort", value: sort))
        query.append(.init(name: "_order", value: route == .recent || route == .favorites || route == .recentlyAdded ? "DESC" : "ASC"))
        let response = try await native(path, query: query)
        // Native APIs must honor the explicit range. Never proceed with an accidental full-library response.
        guard response.records.count <= size else { throw MusicServerError.responseTooLarge }
        var records = response.records
        var total = response.total
        var hasMore = total.map { start + records.count < $0 } ?? (records.count == size)
        if route == .recent {
            // Sorting by last played does not filter out unplayed tracks. Stop at that boundary.
            records = Array(records.prefix(while: \.hasBeenPlayed))
            let reachedEnd = records.count < response.records.count || !hasMore
            total = reachedEnd ? start + records.count : nil
            hasMore = !reachedEnd
        }
        let items = records.filter { !$0.id.isEmpty }.map { item($0, route: route) }
        return MusicServerPage(items: items, total: total, hasMore: hasMore && !records.isEmpty, nextOffset: start + response.records.count)
    }

    private func recentPage(offset: Int, limit: Int) async throws -> MusicServerPage {
        let local = MusicServerHistory.songs(user: user)
        let localIDs = Set(local.map(\.id))
        var items = Array(local.dropFirst(min(offset, local.count)).prefix(limit)).map(MusicServerItem.song)
        var cursor = offset + items.count
        if items.count == limit { return MusicServerPage(items: items, total: nil, hasMore: true, nextOffset: cursor) }
        guard nativeAPIAvailable else {
            return MusicServerPage(items: items, total: local.count, hasMore: false, nextOffset: cursor)
        }
        var hasMore = true
        // At most 100 local records can overlap, so two full native pages exhaust duplicates.
        // The extra iteration accommodates a small remainder without unbounded library traversal.
        for _ in 0..<3 {
            let serverOffset = max(0, cursor - local.count)
            let requestSize = min(MusicServerWire.maximumPageSize, max(limit - items.count, localIDs.count + limit - items.count))
            let query = [URLQueryItem(name: "_start", value: String(serverOffset)), .init(name: "_end", value: String(serverOffset + requestSize)), .init(name: "_sort", value: "play_date"), .init(name: "_order", value: "DESC")]
            let response: (records: [MusicServerRecord], total: Int?)
            do { response = try await native("/api/song", query: query) }
            catch {
                try Task.checkCancellation()
                if !items.isEmpty { return MusicServerPage(items: items, total: nil, hasMore: false, nextOffset: cursor) }
                throw error
            }
            guard response.records.count <= requestSize else { throw MusicServerError.responseTooLarge }
            if response.records.isEmpty { hasMore = false; break }
            var consumed = 0
            for record in response.records {
                // Sorted native lists also contain unplayed tracks. They are not recent history.
                guard record.hasBeenPlayed else { hasMore = false; break }
                consumed += 1
                cursor += 1
                let value = song(record)
                if !localIDs.contains(value.id), !value.id.isEmpty { items.append(.song(value)) }
                if items.count == limit { break }
            }
            if let total = response.total, serverOffset + consumed >= total { hasMore = false }
            if consumed == response.records.count && response.records.count < requestSize { hasMore = false }
            if !hasMore || items.count == limit { break }
        }
        return MusicServerPage(items: items, total: nil, hasMore: hasMore, nextOffset: cursor)
    }

    /// Search and favorite filtering happen on the server, including on very large libraries.
    func artistPage(offset: Int = 0, limit: Int = 100, query: String = "", starredOnly: Bool = false) async throws -> MusicServerPage {
        guard authenticated else { throw MusicServerError.expiredSession }
        let start = max(0, offset)
        let size = min(max(1, limit), MusicServerWire.maximumPageSize)
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nativeAPIAvailable else {
            if !name.isEmpty, !starredOnly { return try await page(.search(query: name, kind: .artists), offset: start, limit: size) }
            // getArtists/getStarred2 cannot be paginated. Do not download an entire large server
            // merely to show an index; compatible servers still support scoped artist search.
            throw MusicServerError.unsupported
        }
        var parameters = [URLQueryItem(name: "_start", value: String(start)), .init(name: "_end", value: String(start + size)),
                          .init(name: "_sort", value: "name"), .init(name: "_order", value: "ASC")]
        if !name.isEmpty { parameters.append(.init(name: "name", value: name)) }
        if starredOnly { parameters.append(.init(name: "starred", value: "true")) }
        let response = try await native("/api/artist", query: parameters)
        guard response.records.count <= size else { throw MusicServerError.responseTooLarge }
        let next = start + response.records.count
        return MusicServerPage(items: response.records.filter { !$0.id.isEmpty }.map { item($0, route: .artists) },
                               total: response.total, hasMore: !response.records.isEmpty && (response.total.map { next < $0 } ?? (response.records.count == size)), nextOffset: next)
    }

    /// One UI load, internally bounded native requests. Navidrome's getArtists index only
    /// contains album artists, so native accounts must not silently fall back and lose track artists.
    func allArtists(forceReload: Bool = false, onProgress: (@MainActor (Int, Int?) -> Void)? = nil) async throws -> [MusicServerArtist] {
        try Task.checkCancellation()
        guard authenticated else { throw MusicServerError.expiredSession }
        let requestedAccount = accountID
        if forceReload { artistCatalogCache = nil }
        if let cache = artistCatalogCache, cache.accountID == requestedAccount {
            onProgress?(cache.artists.count, cache.artists.count)
            try Task.checkCancellation()
            guard accountID == requestedAccount else { throw CancellationError() }
            return cache.artists
        }
        let loadID = UUID()
        artistCatalogLoadID = loadID
        do {
            let records: [MusicServerArtistRecord]
            if nativeAPIAvailable {
                var catalog = MusicServerArtistCatalog.Accumulator()
                var knownTotal: Int?
                while true {
                    try Task.checkCancellation()
                    guard accountID == requestedAccount, artistCatalogLoadID == loadID else { throw CancellationError() }
                    let result = try await artistCatalogBatch(offset: catalog.nextOffset)
                    try Task.checkCancellation()
                    guard accountID == requestedAccount, artistCatalogLoadID == loadID else { throw CancellationError() }
                    let complete = try catalog.append(result.records, total: result.total)
                    if let total = result.total { knownTotal = total }
                    onProgress?(catalog.records.count, knownTotal)
                    if complete { break }
                }
                records = catalog.records
            } else {
                guard let url = subsonicURL("getArtists") else { throw MusicServerError.invalidAddress }
                let (data, response) = try await send(URLRequest(url: url), maximumResponseBytes: MusicServerArtistCatalog.maximumIndexResponseBytes)
                try validate(response)
                records = try await Self.decodeArtistCatalog(data, indexResponse: true)
                try Task.checkCancellation()
                guard accountID == requestedAccount, artistCatalogLoadID == loadID else { throw CancellationError() }
                onProgress?(records.count, records.count)
            }
            try Task.checkCancellation()
            guard accountID == requestedAccount, artistCatalogLoadID == loadID else { throw CancellationError() }
            let artists = records.map { MusicServerArtist(id: $0.id, name: $0.name, albumCount: $0.albumCount,
                                                         songCount: $0.songCount, coverArt: $0.coverArt, starred: $0.starred) }
            try Task.checkCancellation()
            artistCatalogCache = (requestedAccount, artists)
            return artists
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as MusicServerArtistCatalog.Failure {
            switch failure {
            case .responseTooLarge: throw MusicServerError.responseTooLarge
            case .invalidResponse: throw MusicServerError.invalidResponse
            case .server(let code):
                if let code, [40, 41, 42, 43].contains(code) { throw MusicServerError.invalidCredentials }
                if code == 70 { throw MusicServerError.unsupported }
                throw MusicServerError.unavailable
            }
        } catch is DecodingError {
            throw MusicServerError.invalidResponse
        }
    }

    private func artistCatalogBatch(offset: Int, mayRefresh: Bool = true) async throws -> (records: [MusicServerArtistRecord], total: Int?) {
        let query = [URLQueryItem(name: "_start", value: String(offset)),
                     .init(name: "_end", value: String(offset + MusicServerArtistCatalog.batchSize)),
                     .init(name: "_sort", value: "id"), .init(name: "_order", value: "ASC")]
        guard let base = MusicServerWire.normalizedBaseURL(user.hostUrl),
              let url = MusicServerWire.url(base: base, path: "/api/artist", query: query) else { throw MusicServerError.invalidAddress }
        var request = URLRequest(url: url)
        let requestToken = user.token
        request.setValue("Bearer " + requestToken, forHTTPHeaderField: "X-ND-Authorization")
        request.setValue(AppMeta.identifier, forHTTPHeaderField: "x-nd-client-unique-id")
        let (data, response) = try await send(request)
        try Task.checkCancellation()
        if response.statusCode == 401 || response.statusCode == 403 {
            if mayRefresh {
                if user.token == requestToken { authenticated = false }
                _ = try await authenticate()
                return try await artistCatalogBatch(offset: offset, mayRefresh: false)
            }
            authenticated = false
        }
        try validate(response)
        let total = MusicServerWire.totalCount(response)
        guard total.map({ $0 <= MusicServerArtistCatalog.maximumArtists }) ?? true else { throw MusicServerError.responseTooLarge }
        let records = try await Self.decodeArtistCatalog(data, indexResponse: false)
        return (records, total)
    }

    nonisolated private static func decodeArtistCatalog(_ data: Data, indexResponse: Bool) async throws -> [MusicServerArtistRecord] {
        try Task.checkCancellation()
        let decode = Task.detached(priority: .userInitiated) {
            try indexResponse ? MusicServerArtistCatalog.decodeIndex(data) : MusicServerArtistCatalog.decodeNative(data)
        }
        return try await withTaskCancellationHandler(operation: {
            let records = try await decode.value
            try Task.checkCancellation()
            return records
        }, onCancel: { decode.cancel() })
    }

    func setArtistFavorite(id: String, isFavorite: Bool) async throws {
        let requestedAccount = accountID
        try await setFavorite(id: id, parameter: "artistId", isFavorite: isFavorite)
        if var cache = artistCatalogCache, cache.accountID == requestedAccount, accountID == requestedAccount,
           let index = cache.artists.firstIndex(where: { $0.id == id }) {
            cache.artists[index].starred = isFavorite
            artistCatalogCache = cache
        }
    }

    func setSongFavorite(id: String, isFavorite: Bool) async throws {
        try await setFavorite(id: id, parameter: "id", isFavorite: isFavorite)
        MusicServerHistory.updateFavorite(accountID: accountID, songID: id, isFavorite: isFavorite)
    }

    private func setFavorite(id: String, parameter: String, isFavorite: Bool) async throws {
        guard authenticated else { throw MusicServerError.expiredSession }
        guard !id.isEmpty else { throw MusicServerError.invalidResponse }
        _ = try await subsonic(isFavorite ? "star" : "unstar", query: [.init(name: parameter, value: id)], useFormPost: true)
    }

    func addSongToPlaylist(songID: String, playlistID: String) async throws {
        guard authenticated else { throw MusicServerError.expiredSession }
        guard !songID.isEmpty, !playlistID.isEmpty else { throw MusicServerError.invalidResponse }
        _ = try await subsonic("updatePlaylist", query: [.init(name: "playlistId", value: playlistID), .init(name: "songIdToAdd", value: songID)], useFormPost: true)
    }

    private func compatiblePage(_ route: MusicServerRoute, offset: Int, limit: Int) async throws -> MusicServerPage {
        // Only truly pageable protocol endpoints are used; getStarred/getArtists/getPlaylist can
        // return entire libraries and are deliberately not used as a hidden unbounded fallback.
        switch route {
        case .playlists:
            let playlists = try await allPlaylists()
            let items = Array(playlists.dropFirst(offset).prefix(limit))
            let nextOffset = offset + items.count
            return MusicServerPage(items: items, total: playlists.count,
                                   hasMore: nextOffset < playlists.count, nextOffset: nextOffset)
        case .albums:
            let response = try await subsonic("getAlbumList2", query: [.init(name: "type", value: "alphabeticalByName"), .init(name: "offset", value: String(offset)), .init(name: "size", value: String(limit))])
            let records = try records(response, container: "albumList2", key: "album")
            return MusicServerPage(items: records.prefix(limit).map { item($0, route: .albums) }, total: records.count < limit ? offset + records.count : nil, hasMore: records.count == limit)
        default: throw MusicServerError.unsupported
        }
    }

    func artworkURL(id: String, size: Int = 160) -> URL? {
        guard !id.isEmpty else { return nil }
        return subsonicURL("getCoverArt", query: [.init(name: "id", value: id), .init(name: "size", value: String(min(max(size, 40), 1200)))])
    }

    /// Artist-scoped protocol data; never download the full song library to build a profile.
    func artistDetails(id: String) async throws -> (artist: MusicServerArtist, albums: [MusicServerItem]) {
        guard !id.isEmpty else { throw MusicServerError.invalidResponse }
        let response = try await subsonic("getArtist", query: [.init(name: "id", value: id)])
        guard let object = response["artist"] as? [String: Any] else { throw MusicServerError.invalidResponse }
        let data = try JSONSerialization.data(withJSONObject: object)
        let record = try decoder.decode(MusicServerRecord.self, from: data)
        guard record.id == id, case .artist(let artist) = item(record, route: .artists) else { throw MusicServerError.invalidResponse }
        var seen = Set<String>()
        let albums = try records(response, container: "artist", key: "album")
            .filter { !$0.id.isEmpty && seen.insert($0.id).inserted }.map { item($0, route: .albums) }
        return (artist, albums)
    }

    func artistTopSongs(name: String, limit: Int = 30) async throws -> [MusicServerItem] {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let count = min(max(limit, 1), 30)
        let response = try await subsonic("getTopSongs", query: [.init(name: "artist", value: name), .init(name: "count", value: String(count))])
        guard response["topSongs"] is [String: Any] else { throw MusicServerError.invalidResponse }
        var seen = Set<String>()
        return try records(response, container: "topSongs", key: "song")
            .filter { !$0.id.isEmpty && seen.insert($0.id).inserted }.prefix(count).map { .song(song($0)) }
    }

    func similarArtists(id: String) async throws -> [MusicServerItem] {
        let response = try await subsonic("getArtistInfo2", query: [.init(name: "id", value: id),
            .init(name: "count", value: "20"), .init(name: "includeNotPresent", value: "false")])
        guard response["artistInfo2"] is [String: Any] else { throw MusicServerError.invalidResponse }
        var seen: Set<String> = [id]
        return try records(response, container: "artistInfo2", key: "similarArtist")
            .filter { !$0.id.isEmpty && $0.id != "-1" && seen.insert($0.id).inserted }
            .prefix(20).map { item($0, route: .artists) }
    }

    func musicItem(for song: MusicServerSong) -> MusicItemModel {
        var value = song.value
        value.navUser = user
        var model = MusicItemModel(navSong: value)
        model.bitDepth = song.bitDepth
        if let url = subsonicURL("stream", query: [.init(name: "id", value: value.id), .init(name: "maxBitRate", value: String(MusicConfigManager.shared.navMaxBitRate.rawValue)), .init(name: "format", value: MusicConfigManager.shared.navFormats.rawValue)]) { model.mediaPlayURL = url }
        return model
    }

    func musicItem(for radio: MusicServerRadio) -> MusicItemModel? {
        guard let url = radio.streamURL, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        var song = NavidromeSong()
        song.id = "radio-" + radio.id
        song.title = radio.name
        song.navUser = user
        var model = MusicItemModel(navSong: song)
        model.mediaPlayURL = url
        return model
    }

    private func song(_ record: MusicServerRecord) -> MusicServerSong {
        var song = NavidromeSong()
        song.id = record.mediaFileID ?? record.id
        song.title = record.title
        song.artist = record.artist
        song.artistId = record.artistID
        song.album = record.album
        song.albumId = record.albumID
        song.coverArt = record.coverArt.isEmpty ? (record.hasCoverArt == false ? "" : "mf-" + song.id) : record.coverArt
        song.trackNumber = record.track
        song.discNumber = record.disc
        song.duration = record.duration
        song.bitRate = record.bitRate
        song.samplingRate = record.sampleRate
        song.channelCount = record.channels
        song.size = record.size
        song.suffix = record.suffix
        song.year = record.year
        song.genre = record.genre
        song.starred = record.starred
        song.playCount = record.playCount
        song.navUser = user
        return MusicServerSong(value: song, bitDepth: record.bitDepth)
    }

    private func item(_ record: MusicServerRecord, route: MusicServerRoute) -> MusicServerItem {
        switch route {
        case .artists: return .artist(MusicServerArtist(id: record.id, name: record.name, albumCount: record.albumCount, songCount: record.songCount, coverArt: record.coverArt.isEmpty ? "ar-" + record.id : record.coverArt, starred: record.starred))
        case .albums, .artist: return .album(MusicServerAlbum(id: record.id, name: record.name, artist: record.artist, songCount: record.songCount, coverArt: record.coverArt.isEmpty ? "al-" + record.id : record.coverArt))
        case .playlists: return .playlist(MusicServerPlaylist(id: record.id, name: record.name, songCount: record.songCount, coverArt: record.coverArt.isEmpty ? "pl-" + record.id : record.coverArt, owner: record.ownerName))
        case .radios: return .radio(MusicServerRadio(id: record.id, name: record.name, streamURL: record.streamURL.flatMap(URL.init(string:))))
        default: return .song(song(record))
        }
    }

    private func native(_ path: String, query: [URLQueryItem], mayRefresh: Bool = true) async throws -> (records: [MusicServerRecord], total: Int?) {
        guard let base = MusicServerWire.normalizedBaseURL(user.hostUrl), let url = MusicServerWire.url(base: base, path: path, query: query) else { throw MusicServerError.invalidAddress }
        var request = URLRequest(url: url)
        let requestToken = user.token
        request.setValue("Bearer " + requestToken, forHTTPHeaderField: "X-ND-Authorization")
        request.setValue(AppMeta.identifier, forHTTPHeaderField: "x-nd-client-unique-id")
        let (data, response) = try await send(request)
        if response.statusCode == 401 || response.statusCode == 403 {
            if mayRefresh {
                // Concurrent section failures share one login. A request made before another
                // request already refreshed the token simply retries with the updated token.
                if user.token == requestToken { authenticated = false }
                _ = try await authenticate()
                return try await native(path, query: query, mayRefresh: false)
            }
            authenticated = false
        }
        try validate(response)
        guard let records = try? decoder.decode([MusicServerRecord].self, from: data) else { throw MusicServerError.invalidResponse }
        return (records, MusicServerWire.totalCount(response))
    }

    private func subsonicURL(_ endpoint: String, query: [URLQueryItem] = [], authenticatedUser: NavidromeUserModel? = nil) -> URL? {
        let user = authenticatedUser ?? self.user
        guard let base = MusicServerWire.normalizedBaseURL(user.hostUrl) else { return nil }
        let auth = [URLQueryItem(name: "u", value: user.username), .init(name: "t", value: user.subsonicToken), .init(name: "s", value: user.subsonicSalt), .init(name: "v", value: "1.16.1"), .init(name: "c", value: "WakeMusic"), .init(name: "f", value: "json")]
        return MusicServerWire.url(base: base, path: "/rest/" + endpoint, query: auth + query)
    }

    private func subsonic(_ endpoint: String, query: [URLQueryItem] = [], authenticatedUser: NavidromeUserModel? = nil, useFormPost: Bool = false) async throws -> [String: Any] {
        guard let url = subsonicURL(endpoint, query: query, authenticatedUser: authenticatedUser) else { throw MusicServerError.invalidAddress }
        let request = try useFormPost ? MusicServerPlaylistSupport.postRequest(url: url) : URLRequest(url: url)
        let (data, response) = try await send(request)
        try validate(response)
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let payload = root["subsonic-response"] as? [String: Any] else { throw MusicServerError.invalidResponse }
        guard payload["status"] as? String == "ok" else {
            let code = (payload["error"] as? [String: Any])?["code"] as? Int
            if code == 40 || code == 41 || code == 42 || code == 43 { throw MusicServerError.invalidCredentials }
            // Older compatible servers can ignore form bodies. Never fall back to a mutating GET
            // or replay an ambiguous request merely to work around an unsupported extension.
            if useFormPost && code == 10 { throw MusicServerError.unsupported }
            if code == 70 { throw MusicServerError.unsupported }
            throw MusicServerError.unavailable
        }
        return payload
    }

    private func records(_ response: [String: Any], container: String, key: String) throws -> [MusicServerRecord] {
        guard let value = response[container] as? [String: Any] else { return [] }
        guard let array = value[key] else { return [] }
        let data = try JSONSerialization.data(withJSONObject: array)
        guard let records = try? decoder.decode([MusicServerRecord].self, from: data) else { throw MusicServerError.invalidResponse }
        return records
    }

    private func validate(_ response: HTTPURLResponse, authentication: Bool = false) throws {
        switch response.statusCode {
        case 200..<300: break
        case 401, 403: throw authentication ? MusicServerError.invalidCredentials : MusicServerError.expiredSession
        case 404, 405: throw MusicServerError.unsupported
        default: throw MusicServerError.unavailable
        }
    }

    private func send(_ request: URLRequest, maximumResponseBytes: Int = MusicServerWire.maximumResponseBytes) async throws -> (Data, HTTPURLResponse) {
        do { return try await Self.readBounded(request, transport: transport, maximumResponseBytes: maximumResponseBytes) }
        catch is CancellationError { throw CancellationError() }
        catch let error as MusicServerError { throw error }
        catch {
#if DEBUG
            // Do not log URL, host, userInfo, response bodies or credentials.
            let failure = error as NSError
            debugPrint("[MusicServer] transport failure: \(failure.domain) (\(failure.code))")
#endif
            if let error = error as? URLError {
                if error.code == .cancelled { throw CancellationError() }
                if error.code == .timedOut { throw MusicServerError.timeout }
            }
            throw MusicServerError.unavailable
        }
    }

    /// Consumes bytes off the main actor and cancels if a server ignores pagination or sends a huge error page.
    nonisolated private static func readBounded(_ request: URLRequest, transport: URLSession, maximumResponseBytes: Int) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        let (bytes, response) = try await transport.bytes(for: request)
        defer { bytes.task.cancel() }
        guard let response = response as? HTTPURLResponse else { throw MusicServerError.invalidResponse }
        guard maximumResponseBytes > 0, response.expectedContentLength <= Int64(maximumResponseBytes) else { throw MusicServerError.responseTooLarge }
        var data = Data()
        data.reserveCapacity(min(max(Int(response.expectedContentLength), 0), maximumResponseBytes))
        for try await byte in bytes {
            if data.count >= maximumResponseBytes { throw MusicServerError.responseTooLarge }
            data.append(byte)
            if data.count.isMultiple(of: 16384) { try Task.checkCancellation() }
        }
        try Task.checkCancellation()
        return (data, response)
    }

    private struct LoginRequest: Encodable { let username: String; let password: String }
    private struct LoginResponse: Decodable {
        let id: String?
        let name: String?
        let isAdmin: Bool?
        let token: String
        let subsonicSalt: String?
        let subsonicToken: String?
    }
}

/// Shared by the real playlist client and offline request/response regression tests.
enum MusicServerPlaylistSupport {
    static func uniquePlaylists(_ records: [MusicServerRecord]) -> [MusicServerRecord] {
        var seen = Set<String>()
        return records.filter { !$0.id.isEmpty && seen.insert($0.id).inserted }.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
    }

    static func postRequest(url: URL) throws -> URLRequest {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let form = components.percentEncodedQuery else { throw MusicServerError.invalidAddress }
        // The URL builder already percent-encodes literal '+' characters. Keep that encoding
        // when moving both authentication and playlist parameters out of the URL into the body.
        components.percentEncodedQuery = nil
        guard let endpoint = components.url else { throw MusicServerError.invalidAddress }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(form.utf8)
        return request
    }
}
