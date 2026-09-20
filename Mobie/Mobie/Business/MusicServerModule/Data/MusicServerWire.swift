import Foundation
import CryptoKit

enum MusicServerSearchKind: Int, CaseIterable {
    case songs, artists, albums

    var responseKey: String {
        switch self {
        case .songs: return "song"
        case .artists: return "artist"
        case .albums: return "album"
        }
    }

    /// Explicit zero counts prevent fetching the other two categories on every page.
    func parameters(query: String, offset: Int, limit: Int) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "query", value: query.trimmingCharacters(in: .whitespacesAndNewlines))]
        for kind in Self.allCases {
            items.append(.init(name: kind.responseKey + "Count", value: String(kind == self ? min(max(limit, 1), MusicServerWire.maximumPageSize) : 0)))
            items.append(.init(name: kind.responseKey + "Offset", value: String(kind == self ? max(0, offset) : 0)))
        }
        return items
    }
}

/// A cancelled refresh must not join a cancelled login, and an older login's teardown must
/// never clear its replacement. Shared by the real client and deterministic concurrency tests.
@MainActor
final class MusicServerAuthenticationFlight<Value> {
    private var current: (id: UUID, task: Task<Value, Error>)?

    func isCurrent(_ id: UUID) -> Bool { current?.id == id }

    func value(operation: @escaping @MainActor (UUID) async throws -> Value) async throws -> Value {
        try Task.checkCancellation()
        if let current, !current.task.isCancelled {
            let result = try await current.task.value
            try Task.checkCancellation()
            return result
        }
        let id = UUID()
        let task = Task { try await operation(id) }
        current = (id, task)
        defer {
            // A cancelled operation may finish after a new generation has already started.
            if current?.id == id { current = nil }
        }
        return try await withTaskCancellationHandler(operation: {
            let result = try await task.value
            try Task.checkCancellation()
            return result
        }, onCancel: { task.cancel() })
    }
}

/// Protocol-independent URL and pagination rules. No account secrets are logged or persisted here.
enum MusicServerWire {
    static let maximumPageSize = 100
    static let maximumResponseBytes = 4 * 1024 * 1024

    static func normalizedBaseURL(_ address: String) -> URL? {
        guard var parts = URLComponents(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = parts.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil else { return nil }
        parts.scheme = scheme
        parts.host = host.lowercased()
        if (scheme == "https" && parts.port == 443) || (scheme == "http" && parts.port == 80) { parts.port = nil }
        while parts.path.hasSuffix("/") { parts.path.removeLast() }
        return parts.url
    }

    static func url(base: URL, path: String, query: [URLQueryItem] = []) -> URL? {
        guard var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        // Endpoints are app-owned constants; identifiers belong in query items, never interpolated paths.
        parts.path += path.hasPrefix("/") ? path : "/" + path
        parts.queryItems = query.isEmpty ? nil : query
        // URLComponents leaves '+' literal, but many form-style servers decode it as a space.
        parts.percentEncodedQuery = parts.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return parts.url
    }

    static func token(password: String, salt: String) -> String {
        Insecure.MD5.hash(data: Data((password + salt).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func totalCount(_ response: HTTPURLResponse) -> Int? {
        if let text = response.value(forHTTPHeaderField: "X-Total-Count"), let count = Int(text), count >= 0 { return count }
        if let text = response.value(forHTTPHeaderField: "Content-Range"),
           let count = text.split(separator: "/").last.flatMap({ Int($0) }), count >= 0 { return count }
        return nil
    }
}

/// Compact, value-only metadata for a complete artist catalog. Full song metadata and artwork
/// images must not be retained for every artist in a large library.
struct MusicServerArtistRecord: Decodable, Sendable {
    let id: String
    let name: String
    let albumCount: Int?
    let songCount: Int?
    let coverArt: String
    let starred: Bool

    private enum Key: String, CodingKey { case id, name, title, albumCount, songCount, coverArt, starred }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: Key.self)
        func text(_ key: Key) -> String? {
            if let value = try? values.decode(String.self, forKey: key) { return value }
            return (try? values.decode(Int.self, forKey: key)).map(String.init)
        }
        func count(_ key: Key) -> Int? {
            if let value = try? values.decode(Int.self, forKey: key) { return value }
            return text(key).flatMap(Int.init)
        }
        id = text(.id) ?? ""
        name = text(.name) ?? text(.title) ?? ""
        albumCount = count(.albumCount)
        songCount = count(.songCount)
        let cover = text(.coverArt) ?? ""
        coverArt = cover.isEmpty ? "ar-" + id : cover
        starred = (try? values.decode(Bool.self, forKey: .starred)) ?? !(text(.starred) ?? "").isEmpty
    }
}

enum MusicServerArtistCatalog {
    // Native Navidrome uses deluan/rest's explicit _start/_end range, without a 100-item cap.
    // Keep larger batches exclusive to catalog loading; interactive requests still cap at 100.
    static let batchSize = 1_000
    static let maximumArtists = 250_000
    static let maximumIndexResponseBytes = 64 * 1024 * 1024

    enum Failure: Error { case invalidResponse, responseTooLarge, server(code: Int?) }

    struct Accumulator {
        private(set) var records: [MusicServerArtistRecord] = []
        private(set) var nextOffset = 0
        private var ids = Set<String>()
        private var expectedTotal: Int?

        /// Returns true only for a complete catalog. A repeated/empty premature page is an
        /// error, never a successfully loaded partial library or an endless request loop.
        mutating func append(_ page: [MusicServerArtistRecord], total: Int?, requested: Int = batchSize) throws -> Bool {
            try Task.checkCancellation()
            guard page.count <= requested, nextOffset <= maximumArtists - page.count,
                  total.map({ $0 <= maximumArtists }) ?? true else { throw Failure.responseTooLarge }
            if let total {
                guard total >= 0, total >= nextOffset + page.count else { throw Failure.invalidResponse }
                if let expectedTotal, expectedTotal != total { throw Failure.invalidResponse }
                expectedTotal = total
            }
            if page.isEmpty {
                guard expectedTotal.map({ nextOffset >= $0 }) ?? true else { throw Failure.invalidResponse }
                return true
            }
            let oldCount = records.count
            for (index, artist) in page.enumerated() {
                if index.isMultiple(of: 256) { try Task.checkCancellation() }
                guard !artist.id.isEmpty else { throw Failure.invalidResponse }
                if ids.insert(artist.id).inserted { records.append(artist) }
            }
            guard records.count > oldCount else { throw Failure.invalidResponse }
            nextOffset += page.count
            if let expectedTotal { return nextOffset >= expectedTotal }
            return page.count < requested
        }
    }

    static func decodeNative(_ data: Data) throws -> [MusicServerArtistRecord] {
        try Task.checkCancellation()
        guard data.count <= MusicServerWire.maximumResponseBytes else { throw Failure.responseTooLarge }
        let records = try JSONDecoder().decode([MusicServerArtistRecord].self, from: data)
        guard records.count <= batchSize else { throw Failure.responseTooLarge }
        try Task.checkCancellation()
        return records
    }

    static func decodeIndex(_ data: Data) throws -> [MusicServerArtistRecord] {
        try Task.checkCancellation()
        guard data.count <= maximumIndexResponseBytes else { throw Failure.responseTooLarge }
        let envelope = try JSONDecoder().decode(IndexEnvelope.self, from: data)
        try Task.checkCancellation()
        return envelope.records
    }

    /// Decode one group at a time, directly from the response. Avoid JSONSerialization's
    /// large dictionary tree and its second JSON encoding used by small, paginated calls.
    private struct IndexEnvelope: Decodable {
        let records: [MusicServerArtistRecord]
        private enum Root: String, CodingKey { case response = "subsonic-response" }
        private enum Payload: String, CodingKey { case status, error, artists }
        private enum ErrorKey: String, CodingKey { case code }
        private enum Artists: String, CodingKey { case index }
        private struct Group: Decodable { let artist: [MusicServerArtistRecord]? }

        init(from decoder: Decoder) throws {
            let root = try decoder.container(keyedBy: Root.self)
            let payload = try root.nestedContainer(keyedBy: Payload.self, forKey: .response)
            guard try payload.decode(String.self, forKey: .status) == "ok" else {
                let error = try? payload.nestedContainer(keyedBy: ErrorKey.self, forKey: .error)
                throw Failure.server(code: try? error?.decode(Int.self, forKey: .code))
            }
            guard payload.contains(.artists) else { throw Failure.invalidResponse }
            let artists = try payload.nestedContainer(keyedBy: Artists.self, forKey: .artists)
            guard artists.contains(.index), !(try artists.decodeNil(forKey: .index)) else { records = []; return }
            var groups = try artists.nestedUnkeyedContainer(forKey: .index)
            var result: [MusicServerArtistRecord] = []
            var ids = Set<String>()
            var rawCount = 0
            while !groups.isAtEnd {
                try Task.checkCancellation()
                let group = try groups.decode(Group.self)
                for (index, artist) in (group.artist ?? []).enumerated() {
                    if index.isMultiple(of: 256) { try Task.checkCancellation() }
                    rawCount += 1
                    guard rawCount <= maximumArtists else { throw Failure.responseTooLarge }
                    guard !artist.id.isEmpty else { throw Failure.invalidResponse }
                    if ids.insert(artist.id).inserted { result.append(artist) }
                }
            }
            records = result
        }
    }
}

/// Both Navidrome's native API and Subsonic return these concepts, but use different scalar names/types.
/// Missing optional metadata must never reject an otherwise playable track.
struct MusicServerRecord: Decodable {
    let id: String
    let mediaFileID: String?
    let title: String
    let name: String
    let artist: String
    let artistID: String?
    let album: String
    let albumID: String?
    let coverArt: String
    let hasCoverArt: Bool?
    let songCount: Int?
    let albumCount: Int?
    let track: Int
    let disc: Int
    let duration: Int
    let bitRate: Int
    let sampleRate: Int
    let channels: Int
    let bitDepth: Int?
    let size: Int
    let suffix: String
    let year: Int?
    let genre: String
    let starred: Bool
    let playCount: Int
    let playDate: String?
    let streamURL: String?
    let ownerName: String

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ value: String) { stringValue = value }
        init?(stringValue: String) { self.init(stringValue) }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: Key.self)
        func string(_ key: String) -> String? {
            if let text = try? values.decode(String.self, forKey: Key(key)) { return text }
            if let number = try? values.decode(Int.self, forKey: Key(key)) { return String(number) }
            return nil
        }
        func integer(_ key: String) -> Int? {
            if let number = try? values.decode(Int.self, forKey: Key(key)) { return number }
            if let number = try? values.decode(Double.self, forKey: Key(key)), number.isFinite,
               number >= Double(Int.min), number < Double(Int.max) { return Int(number) }
            return string(key).flatMap(Int.init)
        }
        func boolean(_ key: String) -> Bool? { try? values.decode(Bool.self, forKey: Key(key)) }
        id = string("id") ?? ""
        mediaFileID = string("mediaFileId")
        title = string("title") ?? string("name") ?? ""
        name = string("name") ?? string("title") ?? ""
        artist = string("artist") ?? string("albumArtist") ?? ""
        artistID = string("artistId") ?? string("albumArtistId")
        album = string("album") ?? ""
        albumID = string("albumId")
        coverArt = string("coverArt") ?? ""
        hasCoverArt = boolean("hasCoverArt")
        songCount = integer("songCount")
        albumCount = integer("albumCount")
        track = integer("trackNumber") ?? integer("track") ?? 0
        disc = integer("discNumber") ?? 0
        duration = integer("duration") ?? 0
        bitRate = integer("bitRate") ?? 0
        sampleRate = integer("sampleRate") ?? integer("samplingRate") ?? 0
        channels = integer("channels") ?? integer("channelCount") ?? 2
        bitDepth = integer("bitDepth")
        size = integer("size") ?? 0
        suffix = string("suffix") ?? ""
        year = integer("year")
        genre = string("genre") ?? ""
        // Subsonic uses an ISO-8601 starred timestamp; Navidrome uses a boolean.
        starred = boolean("starred") ?? !(string("starred") ?? "").isEmpty
        playCount = integer("playCount") ?? 0
        playDate = string("playDate")
        streamURL = string("streamUrl")
        ownerName = string("ownerName") ?? string("owner") ?? ""
    }

    var hasBeenPlayed: Bool {
        playCount > 0 || (playDate.map { !$0.isEmpty && !$0.hasPrefix("0001-") } ?? false)
    }
}

/// Refuse cross-origin redirects so bearer headers and signed URLs cannot leak to another service.
final class MusicServerRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let source = response.url, let destination = request.url,
              source.host?.lowercased() == destination.host?.lowercased(),
              source.scheme?.lowercased() == destination.scheme?.lowercased(),
              source.port == destination.port else { completionHandler(nil); return }
        completionHandler(request)
    }
}
