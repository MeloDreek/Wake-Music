import Foundation

/// Text evidence is a fallback, not an acoustic identification. Keep this policy
/// independent of networking/UI so ambiguous recordings can be regression tested.
enum CatalogMetadataMatcher {
    struct Query {
        let filename: String
        let title: String?
        let artist: String?
        let album: String?
        let duration: Double

        var filenameStem: String {
            clean(URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent)
        }

        var searchTerms: [String] {
            var values: [String] = []
            if let title = nonempty(title) {
                values.append([nonempty(artist), title].compactMap { $0 }.joined(separator: " "))
            }
            let stem = filenameStem
            if isUseful(stem) { values.append(stem) }
            var seen = Set<String>()
            return values.filter { isUseful($0) && seen.insert(normalize($0)).inserted }.prefix(2).map { $0 }
        }
    }

    struct Song: Decodable {
        let trackId: Int?
        let trackName: String
        let artistName: String
        let collectionName: String?
        let artworkUrl100: String?
        let trackTimeMillis: Double?
        let releaseDate: String?
        let primaryGenreName: String?
        let trackNumber: Int?
        let trackViewUrl: String?
        let kind: String?

        var duration: Double { (trackTimeMillis ?? 0) / 1000 }
        var identity: String { normalize(trackName) + "|" + normalize(artistName) }
        var artworkURL: String? {
            guard let value = artworkUrl100, let url = URL(string: value),
                  url.scheme == "https", let host = url.host?.lowercased(),
                  host == "mzstatic.com" || host.hasSuffix(".mzstatic.com") else { return nil }
            return value.replacingOccurrences(of: "100x100bb", with: "1200x1200bb")
        }
    }

    struct Match {
        let song: Song
        let artworkOnly: Bool
        let includeRelease: Bool
    }

    static func match(_ songs: [Song], query: Query) -> Match? {
        let ranked = songs.compactMap { song -> (Song, Double, Bool)? in
            guard song.kind == nil || song.kind == "song",
                  nonempty(song.trackName) != nil, nonempty(song.artistName) != nil else { return nil }
            let evidence = identityEvidence(song, query: query)
            guard evidence.title >= 0.94, evidence.artist >= 0.86 else { return nil }
            // Do not confuse live/cover/karaoke/remix recordings with the original.
            guard versions(song.trackName) == versions(evidence.sourceTitle) else { return nil }
            let hasDuration = query.duration > 0 && song.duration > 0
            let difference = hasDuration ? abs(query.duration - song.duration) : 0
            guard !hasDuration || difference <= max(12, query.duration * 0.035) else { return nil }
            let strong = evidence.title >= 0.98 && evidence.artist >= 0.96
                && (!hasDuration || difference <= max(4, query.duration * 0.015))
            let score = evidence.title * 0.55 + evidence.artist * 0.35
                + (hasDuration ? max(0, 0.1 - difference / 120) : 0)
            return (song, score, strong)
        }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return ($0.0.trackId ?? 0) < ($1.0.trackId ?? 0)
        }
        guard let first = ranked.first else { return nil }
        // Several editions of the same recording are expected; different artists
        // with similarly strong evidence are not safe to choose automatically.
        if ranked.dropFirst().contains(where: { $0.0.identity != first.0.identity && first.1 - $0.1 < 0.06 }) {
            return nil
        }
        let sameRecording = ranked.filter { $0.0.identity == first.0.identity }
        let requestedAlbum = nonempty(query.album)
        let chosen = requestedAlbum.flatMap { album in
            sameRecording.first { normalize($0.0.collectionName ?? "") == normalize(album) }
        } ?? first
        let albums = Set(sameRecording.compactMap { nonempty($0.0.collectionName).map(normalize) })
        let releaseCertain = requestedAlbum.map { normalize(chosen.0.collectionName ?? "") == normalize($0) }
            ?? (albums.count == 1)
        guard chosen.2 || chosen.0.artworkURL != nil else { return nil }
        return Match(song: chosen.0, artworkOnly: !chosen.2, includeRelease: chosen.2 && releaseCertain)
    }

    private static func identityEvidence(_ song: Song, query: Query) -> (title: Double, artist: Double, sourceTitle: String) {
        if let title = nonempty(query.title), let artist = nonempty(query.artist) {
            // Existing embedded identity takes precedence over a misleading filename.
            return (similarity(title, song.trackName), artistSimilarity(artist, song.artistName), title)
        }
        let stem = query.filenameStem
        var pairs: [(String, String)] = []
        // Both Artist - Title and Title - Artist are common. Never assume an order.
        for separator in [" - ", " – ", " — ", "-", "_"] {
            let pieces = stem.components(separatedBy: separator)
            guard pieces.count == 2, pieces.allSatisfy({ isUseful($0) }) else { continue }
            pairs.append((pieces[0], pieces[1]))
            pairs.append((pieces[1], pieces[0]))
        }
        if let artist = nonempty(query.artist) { pairs.append((nonempty(query.title) ?? stem, artist)) }
        // Filename with no artist is only useful when a known embedded artist exists.
        // Title + approximate duration alone cannot disambiguate covers reliably.
        let paired = pairs.map { title, artist in
            let effectiveTitle = nonempty(query.title) ?? title
            return (similarity(effectiveTitle, song.trackName), artistSimilarity(nonempty(query.artist) ?? artist, song.artistName), effectiveTitle)
        }.max { $0.0 * $0.1 < $1.0 * $1.1 }
        if let paired, paired.0 * paired.1 >= 0.8 { return paired }
        let title = nonempty(query.title) ?? stem
        if isUseful(title), nonempty(query.artist) == nil, query.duration > 0, song.duration > 0,
           abs(query.duration - song.duration) <= 3, normalize(title) == normalize(song.trackName) {
            // Title-only evidence can propose artwork, never identity/release tags.
            return (1, 0.88, title)
        }
        return paired ?? (0, 0, stem)
    }

    static func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    static func normalize(_ value: String) -> String {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let a = Array(normalize(lhs)), b = Array(normalize(rhs))
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        if a == b { return 1 }
        // Short titles require exact matches; a one-character mismatch matters.
        guard min(a.count, b.count) >= 6, max(a.count, b.count) <= 300 else { return 0 }
        var previous = Array(0...b.count)
        for (i, x) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, y) in b.enumerated() {
                current[j + 1] = min(current[j] + 1, previous[j + 1] + 1, previous[j] + (x == y ? 0 : 1))
            }
            previous = current
        }
        return 1 - Double(previous[b.count]) / Double(max(a.count, b.count))
    }

    static func artistSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let direct = similarity(lhs, rhs)
        if direct >= 0.96 { return direct }
        func credits(_ value: String) -> Set<String> {
            let separated = value.replacingOccurrences(of: #"(?i)\s+(?:feat\.?|ft\.?|featuring|with)\s+|\s*[&,;/、]\s*"#, with: "|", options: .regularExpression)
            return Set(separated.components(separatedBy: "|").map(normalize).filter { !$0.isEmpty })
        }
        let source = credits(lhs), catalog = credits(rhs)
        // Complete credits, not arbitrary substrings ("Eagle" != "Eagles").
        if !source.isEmpty, source == catalog { return 1 }
        if !source.isEmpty, source.isSubset(of: catalog) { return 0.97 }
        return direct
    }

    static func clean(_ name: String) -> String {
        // Whitespace alone is not a track-number separator: “99 Problems” and
        // “99 Luftballons” are real titles, not track 99 of an album.
        var text = name.replacingOccurrences(of: #"^\s*\d{1,3}\s*[.、_\-]\s*"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)[\[【(（]\s*(?:flac|mp3|wav|ape|aac|alac|dsd|hi[ -]?res|lossless|无损|高品质|\d{2,4}\s?kbps|\d{2}\s?bit(?:[/ -]\d{2,3}(?:\.\d)?\s?khz)?)\s*[\]】)）]"#, with: "", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isUseful(_ value: String) -> Bool {
        let key = normalize(value)
        guard key.count >= 2, key.count <= 200,
              key.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else { return false }
        guard key.range(of: #"^(?:track|audio|recording|untitled|unknown|音轨|录音|未知)\d+$"#, options: .regularExpression) == nil else { return false }
        return key.range(of: #"^(?:smb|ftp|webdav)?[a-f0-9]{24,}$"#, options: .regularExpression) == nil
    }

    private static func versions(_ title: String) -> Set<String> {
        let lower = title.lowercased()
        let groups = ["live": #"\blive\b|现场|演唱会"#, "remix": #"\bremix\b|混音"#,
                      "karaoke": #"\bkaraoke\b|伴奏"#, "instrumental": #"\binstrumental\b|纯音乐"#,
                      "cover": #"\bcover\b|翻唱"#, "acoustic": #"\bacoustic\b|不插电"#,
                      "edit": #"\bradio edit\b|\bsped up\b|\bslowed\b"#]
        return Set(groups.compactMap { key, regex in lower.range(of: regex, options: .regularExpression) == nil ? nil : key })
    }
}
