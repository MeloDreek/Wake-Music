import Foundation

// Minimal data doubles; grouping methods are extracted from the production files.
public final class MusicViewModel: NSObject {}
public enum MusicGenreType: String { case pop, rock, other; func formatStr() -> String { rawValue } }
public struct MusicItemModel: Hashable {
    let id: Int
    var artist: String? = nil
    var displayArtist: String? = nil
    var album: String? = nil
    var track: Int? = nil
    var genre: MusicGenreType? = nil
    var folder = false
    var lyrics = false
    var mediaPlayURL: URL { URL(fileURLWithPath: "/fixture/\(id).mp3") }
    func showArtistName() -> String { displayArtist ?? artist ?? "Unknown Artist" }
    func showTitleName() -> String { String(id) }
    func isFolder() -> Bool { folder }
    func isLRCFile() -> Bool { lyrics }
    func musicGenreType() -> MusicGenreType? { genre }
}
extension String { func localStr() -> String { self } }
extension URL { var creationDate: Date? { Date(timeIntervalSince1970: 0) } }

@main enum GroupingRegression {
    static func main() {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            count += 1
            guard condition() else { fatalError("FAILED: \(label)") }
        }
        let vm = MusicViewModel()
        let songs = [
            MusicItemModel(id: 1, artist: "   ", album: "  "),
            MusicItemModel(id: 2, artist: "Ann & Bob;;", album: " Album ", track: 2, genre: .pop),
            MusicItemModel(id: 3, artist: "Anne", album: "Album", track: 1, genre: .pop),
            MusicItemModel(id: 4, artist: nil, displayArtist: "Wakemusic", album: "Demo", genre: .rock),
            MusicItemModel(id: 5, artist: "; / + ", album: nil),
            MusicItemModel(id: 6, artist: "Bob / Bob", album: "Demo", genre: .rock),
            MusicItemModel(id: 7, folder: true), MusicItemModel(id: 8, lyrics: true)
        ]
        vm.refreshSingerDataAction(songs)
        check(!vm.singerArray.contains(""), "No empty artist key")
        for name in vm.singerArray { check(!vm.singerMusicArray(name).isEmpty, "Every artist has songs") }
        check(vm.singerMusicArray("Ann").map(\.id) == [2], "Exact artist tokens, not substring matches")
        check(vm.singerMusicArray("Anne").map(\.id) == [3], "Similar names stay independent")
        check(vm.singerMusicArray("Wakemusic").map(\.id) == [4], "Demo display name matches detail lookup")
        check(Set(vm.singerMusicArray("Unknown Artist").map(\.id)) == [1, 5], "Whitespace and separators use Unknown Artist")
        check(vm.singerMusicArray("Bob").count == 2, "Duplicate duet credit appears once")
        vm.refreshAlbumDataAction(songs)
        check(!vm.albumArray.contains(""), "No empty album key")
        check(vm.albumMusicArray("Album").map(\.id) == [3, 2], "Trimmed album and track order")
        check(Set(vm.albumMusicArray("Unknown Album").map(\.id)) == [1, 5], "Unknown albums exclude folders and lyrics")
        vm.refreshGenreDataAction(songs)
        check(vm.genreMusicArray(.pop).count == 2, "Genre membership")
        check(vm.genreArray.last == .other, "Other genre comes last")
        check(vm.genreMusicArray(.other).count == 2, "Nonmusic excluded from genres")
        // Same-count edits must not be dropped by a time-based throttle.
        var changed = songs
        changed[2].artist = "New Artist"
        changed[2].album = "Renamed Album"
        changed[2].genre = .rock
        vm.refreshSingerDataAction(changed)
        vm.refreshAlbumDataAction(changed)
        vm.refreshGenreDataAction(changed)
        check(!vm.singerArray.contains("Anne") && vm.singerArray.contains("New Artist"), "Immediate artist tag edit")
        check(vm.albumMusicArray("Renamed Album").count == 1, "Immediate album tag edit")
        check(vm.genreMusicArray(.pop).count == 1, "Immediate genre tag edit")
        for _ in 0..<3 {
            vm.refreshSingerDataAction([]); vm.refreshAlbumDataAction([]); vm.refreshGenreDataAction([])
            check(vm.singerArray.isEmpty && vm.albumArray.isEmpty && vm.genreArray.isEmpty, "Immediate delete clears groups")
        }
        check(LibraryGrouping.artists("e\u{301};é", fallback: "unknown") == ["é"], "Unicode normalization")
        print("\(count) collection grouping checks passed")
    }
}
