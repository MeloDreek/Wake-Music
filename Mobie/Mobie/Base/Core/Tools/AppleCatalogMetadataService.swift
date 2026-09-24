import Foundation
import AppGroupKit
import KakaFoundation
import WaketagLibKit

/// Uses Apple's public iTunes catalog search (not the user's Apple Music library).
/// Only search terms are sent; local paths and audio data are never uploaded here.
actor AppleCatalogMetadataService {
    static let shared = AppleCatalogMetadataService()
    private struct Response: Decodable { let results: [CatalogMetadataMatcher.Song] }
    private struct Cached { let songs: [CatalogMetadataMatcher.Song]; let date: Date }
    private var cache: [String: Cached] = [:]
    private var nextRequest = Date.distantPast
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 18
        return URLSession(configuration: config)
    }()

    func search(_ query: CatalogMetadataMatcher.Query) async throws -> CatalogMetadataMatcher.Match? {
        let terms = query.searchTerms
        guard !terms.isEmpty else { return nil }
        let region = Locale.current.region?.identifier.uppercased() ?? "US"
        let country = region.count == 2 ? region : "US"
        var requests = terms.map { ($0, country) }
        if country != "US", let first = terms.first { requests.append((first, "US")) }
        var songs: [CatalogMetadataMatcher.Song] = []
        var best: CatalogMetadataMatcher.Match?
        for (term, store) in requests.prefix(3) {
            try Task.checkCancellation()
            do {
                songs.append(contentsOf: try await fetch(term: term, country: store))
            } catch is CancellationError { throw CancellationError() }
            catch { continue }
            best = CatalogMetadataMatcher.match(songs, query: query)
            if let best, !best.artworkOnly { return best }
        }
        return best
    }

    private func fetch(term: String, country: String) async throws -> [CatalogMetadataMatcher.Song] {
        let key = country + ":" + CatalogMetadataMatcher.normalize(term)
        if let cached = cache[key], Date().timeIntervalSince(cached.date) < 600 { return cached.songs }
        // Apple's public search API documents approximately 20 requests/minute.
        // Recheck after each suspension: the actor can admit another request
        // while this one waits. A cancelled waiter must not reserve an unused
        // future slot and delay the next screen/batch retry.
        while nextRequest.timeIntervalSinceNow > 0 {
            let delay = nextRequest.timeIntervalSinceNow
            if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        }
        try Task.checkCancellation()
        nextRequest = Date().addingTimeInterval(3.2)
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [URLQueryItem(name: "term", value: term),
                                 URLQueryItem(name: "media", value: "music"),
                                 URLQueryItem(name: "entity", value: "song"),
                                 URLQueryItem(name: "country", value: country),
                                 URLQueryItem(name: "limit", value: "25")]
        guard let url = components.url else { return [] }
        let (data, response) = try await session.data(from: url)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              data.count <= 2_000_000 else { return [] }
        let songs = try JSONDecoder().decode(Response.self, from: data).results
        cache = cache.filter { Date().timeIntervalSince($0.value.date) < 600 }
        if cache.count >= 128, let oldest = cache.min(by: { $0.value.date < $1.value.date })?.key {
            cache.removeValue(forKey: oldest)
        }
        cache[key] = Cached(songs: songs, date: Date())
        return songs
    }
}

extension AudioFingerprintMatcher {
    /// One entry point shared by Auto-Match, batch embedding, cover and lyric search.
    /// A failed acoustic match falls back to conservative text/duration evidence.
    @discardableResult
    func matchLocalAudioMetadata(model: MusicItemModel, isRequestLyrics: Bool = true,
                                completion: @escaping (Result<AudioFingerprintModel, KakaError>) -> Void) -> MetadataMatchRequest {
        let request = MetadataMatchRequest()
        matchLocalAudio(model: model, isRequestLyrics: isRequestLyrics) { [weak self, weak request] result in
            guard let self, let request, !request.isCancelled else { return }
            switch result {
            case .success:
                completion(result)
            case .failure(let fingerprintError):
                request.task = Task { [weak self, weak request] in
                    guard let self, let request, !request.isCancelled else { return }
                    // Disk metadata, not a list model's display-title fallback, is evidence.
                    let url = model.mediaPlayURL
                    guard url.isFileURL else {
                        await MainActor.run { if !request.isCancelled { completion(.failure(fingerprintError)) } }
                        return
                    }
                    let scope = url.startAccessingSecurityScopedResource()
                    let metadata = TaglibMetadataParser.readMetadata(withFileURL: url, read: .basic)
                    if scope { url.stopAccessingSecurityScopedResource() }
                    let query = CatalogMetadataMatcher.Query(filename: url.lastPathComponent,
                        title: metadata?.title, artist: metadata?.artist, album: metadata?.album,
                        duration: (metadata?.durationSeconds ?? 0) > 0 ? Double(metadata!.durationSeconds) : Double(model.durationSeconds))
                    do {
                        guard let match = try await AppleCatalogMetadataService.shared.search(query) else {
                            await MainActor.run { if !request.isCancelled { completion(.failure(fingerprintError)) } }
                            return
                        }
                        try Task.checkCancellation()
                        var tags = AudioFingerprintModel()
                        tags.metadataSource = match.artworkOnly ? "appleCatalogArtwork" : "appleCatalog"
                        tags.coverArt = match.song.artworkURL
                        if !match.artworkOnly {
                            tags.title = match.song.trackName
                            tags.artist = match.song.artistName
                            tags.duration = query.duration > 0 ? query.duration : match.song.duration
                            tags.appleMusicID = match.song.trackId.map(String.init)
                            tags.appleMusicURL = match.song.trackViewUrl
                            if match.includeRelease {
                                tags.album = match.song.collectionName
                                tags.year = match.song.releaseDate.flatMap { Int($0.prefix(4)) }
                                tags.trackNumber = match.song.trackNumber
                                tags.genres = match.song.primaryGenreName
                            }
                        }
                        let candidate = tags
                        await MainActor.run {
                            guard !request.isCancelled else { return }
                            if isRequestLyrics && !match.artworkOnly {
                                self.fetchLRCLyricArray(audioModel: candidate, model: model) { result in
                                    guard !request.isCancelled else { return }
                                    var withLyrics = candidate
                                    if case .success(let lyrics) = result { withLyrics.lyrics = lyrics }
                                    completion(.success(withLyrics))
                                }
                            } else { completion(.success(candidate)) }
                        }
                    } catch {
                        guard !Task.isCancelled, !request.isCancelled else { return }
                        await MainActor.run { if !request.isCancelled { completion(.failure(fingerprintError)) } }
                    }
                }
            }
        }
        return request
    }
}

/// Retained by the screen/operation until completion; cancellation never triggers
/// the filename fallback or allows a dismissed screen to receive stale results.
final class MetadataMatchRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var currentTask: Task<Void, Never>?
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    var task: Task<Void, Never>? {
        get { lock.lock(); defer { lock.unlock() }; return currentTask }
        set {
            lock.lock(); currentTask = newValue; let cancelNow = cancelled; lock.unlock()
            if cancelNow { newValue?.cancel() }
        }
    }
    func cancel() {
        lock.lock(); cancelled = true; let task = currentTask; currentTask = nil; lock.unlock()
        task?.cancel()
    }
    deinit { cancel() }
}
