import Foundation

@main struct CatalogMatchingTests {
    static var count = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        count += 1
        guard condition() else { fatalError(message) }
    }
    static func song(_ title: String = "Victory", _ artist: String = "Two Steps From Hell", album: String = "Battlecry", seconds: Double = 320, id: Int = 1) -> CatalogMetadataMatcher.Song {
        .init(trackId: id, trackName: title, artistName: artist, collectionName: album,
              artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music/100x100bb.jpg",
              trackTimeMillis: seconds * 1000, releaseDate: "2015-04-28", primaryGenreName: "Soundtrack", trackNumber: 2, trackViewUrl: nil, kind: "song")
    }
    static func query(_ filename: String = "Two Steps From Hell - Victory.flac", title: String? = nil, artist: String? = nil, album: String? = nil, duration: Double = 320) -> CatalogMetadataMatcher.Query {
        .init(filename: filename, title: title, artist: artist, album: album, duration: duration)
    }
    static func main() async throws {
        let victory = song()
        for filename in ["Two Steps From Hell - Victory.flac", "Victory-Two Steps From Hell.mp3", "02. Two Steps From Hell - Victory [FLAC].flac", "Victory_Two Steps From Hell.wav"] {
            let match = CatalogMetadataMatcher.match([victory], query: query(filename))
            check(match != nil && match?.artworkOnly == false, "Filename orientation/noise: \(filename)")
        }
        check(CatalogMetadataMatcher.match([victory], query: query("Victory.flac"))?.artworkOnly == true, "Title-only must be artwork-only")
        check(CatalogMetadataMatcher.match([victory], query: query("Victory.flac", duration: 0)) == nil, "Title-only without duration is unsafe")
        check(CatalogMetadataMatcher.match([victory, song("Victory", "Other Artist", id: 2)], query: query("Victory.flac")) == nil, "Ambiguous title rejected")
        check(CatalogMetadataMatcher.match([victory], query: query(title: "Victory", artist: "Different Artist")) == nil, "Existing identity wins over filename")
        check(CatalogMetadataMatcher.match([song("Victory (Live)")], query: query()) == nil, "Live/studio mismatch rejected")
        check(CatalogMetadataMatcher.match([song("Victory", seconds: 390)], query: query()) == nil, "Duration mismatch rejected")
        check(CatalogMetadataMatcher.match([victory], query: query(duration: 330))?.artworkOnly == true, "Moderate duration confidence cannot fill identity")
        let compilations = [victory, song(album: "Best of", id: 2)]
        check(CatalogMetadataMatcher.match(compilations, query: query())?.includeRelease == false, "Ambiguous releases cannot fill album/track/year")
        let albumMatch = CatalogMetadataMatcher.match(compilations, query: query(album: "Best of"))
        check(albumMatch?.song.collectionName == "Best of" && albumMatch?.includeRelease == true, "Existing album disambiguates release")
        check(CatalogMetadataMatcher.match([song("顺流逆流", "邓瑞霞")], query: query("邓瑞霞 - 顺流逆流.flac"))?.artworkOnly == false, "Chinese filename")
        check(CatalogMetadataMatcher.match([song("Déjà Vu", "Beyoncé")], query: query("Beyonce - Deja Vu.flac"))?.artworkOnly == false, "Accents normalized")
        check(CatalogMetadataMatcher.match([song("My Song (Live)", "Artist")], query: query("Artist - My Song.flac", title: "My Song (Live)")) != nil, "Use effective embedded title for version")
        check(CatalogMetadataMatcher.clean("99 Problems") == "99 Problems", "Numeric song name retained")
        check(query("smb-d244d9e3ce79909ed2466d8477292451301a1bd21d50599109de51a4f4b272ba.mp3").searchTerms.isEmpty, "Hashes not searched")
        check(query("Track 01.wav").searchTerms.isEmpty, "Generic track filename not searched")
        check(query("12345.wav").searchTerms.isEmpty, "Numeric filename not searched")
        check(CatalogMetadataMatcher.similarity("Song", "Sung") == 0, "Short titles need exact matches")
        check(CatalogMetadataMatcher.similarity("", "") == 0, "Blank tags not matches")
        check(CatalogMetadataMatcher.match([song("Victory", "Two Steps From Hell & Thomas Bergersen")], query: query())?.artworkOnly == false, "Catalog collaborator credits")
        check(CatalogMetadataMatcher.artistSimilarity("Thomas Bergersen,Two Steps From Hell", "Two Steps From Hell & Thomas Bergersen") == 1, "Artist credit order")
        check(CatalogMetadataMatcher.artistSimilarity("Eagle", "Eagles") == 0, "Do not guess artist spelling")
        check(victory.artworkURL?.contains("1200x1200bb") == true, "High-resolution artwork")
        let malicious = CatalogMetadataMatcher.Song(trackId: 2, trackName: "Victory", artistName: "Two Steps From Hell", collectionName: nil, artworkUrl100: "https://evilmzstatic.com/100x100bb.jpg", trackTimeMillis: nil, releaseDate: nil, primaryGenreName: nil, trackNumber: nil, trackViewUrl: nil, kind: "song")
        check(malicious.artworkURL == nil, "Require Apple CDN domain boundary")
        let json = #"{"trackId":123,"trackName":"A & B #1","artistName":"Artist","kind":"song","trackTimeMillis":200000}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CatalogMetadataMatcher.Song.self, from: json)
        check(decoded.duration == 200, "Apple payload decode")
        print("Catalog matching: \(count) assertions passed")
        if CommandLine.arguments.contains("--online") {
            let result = try await AppleCatalogMetadataService.shared.search(query())
            check(result?.song.artistName.contains("Two Steps From Hell") == true, "Live Apple catalog artist")
            check(result?.song.trackName == "Victory", "Live Apple catalog title")
            print("Live Apple catalog: \(result!.song.trackName) / \(result!.song.artistName), artwork=\(result!.song.artworkURL != nil), release=\(result!.includeRelease)")
        }
    }
}
