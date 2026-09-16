import Foundation
import CryptoKit

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
