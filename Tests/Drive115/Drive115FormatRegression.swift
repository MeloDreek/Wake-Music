import Foundation

// Dependency stand-ins only; the file model and audio extension lists are the
// production sources. No account, network or user music library is accessed.
public protocol SmartCodableX {}
public struct Drive115UserModel {}
public enum SortedbyType { case name }
final class SandboxFileManager {
    static let shared = SandboxFileManager()
    func basePublicFileURL() -> URL { URL(fileURLWithPath: "/unused-test-folder", isDirectory: true) }
}
extension String { func localStr() -> String { self } }
final class UILocalizedIndexedCollation {
    static func current() -> UILocalizedIndexedCollation { UILocalizedIndexedCollation() }
    let sectionTitles = ["#"]
    func section(for object: Any, collationStringSelector: Selector) -> Int { 0 }
}

@main
enum Drive115FormatRegression {
    static func main() {
        var checks = 0
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            precondition(value(), message)
            checks += 1
        }
        func file(_ name: String, icon: String = "") -> Drive115FileModel {
            var model = Drive115FileModel()
            model.fc = 1
            model.fn = name
            model.ico = icon
            return model
        }

        for (name, icon) in [("song.dsf", "dsf"), ("song.DFF", "DFF"),
                             ("song.DSF", ""), ("song.dff", " .DFF "),
                             ("song.DSF", "mp3"), ("song", "dsf"), ("song.dff", "bin")] {
            let model = file(name, icon: icon)
            check(!model.isDirectory(), "DSD files are not folders")
            check(model.isUnsupportedStreamingAudio, "Block 115 DSD: \(name), \(icon)")
            check(model.isMusic(), "DSD stays in the music group despite streaming restriction")
        }
        var detail = Drive115FileModel()
        detail.file_category = 1
        detail.file_name = "详情.DFF"
        check(detail.fileExtension() == "dff", "Detail responses without ico use file_name")
        check(detail.isUnsupportedStreamingAudio && detail.isMusic(), "Detail response stays music but cannot stream")

        for suffix in ["mp3", "flac", "wav", "aac", "m4a", "dsd"] {
            let model = file("song.\(suffix.uppercased())", icon: suffix)
            check(model.isMusic() && !model.isUnsupportedStreamingAudio, "Do not change other 115 formats: \(suffix)")
        }
        for name in ["Archive.dsf", "Archive.DFF", "Music"] {
            var folder = Drive115FileModel()
            folder.fc = 0
            folder.fn = name
            check(folder.isDirectory(), "Do not mistake a dotted folder name for a file")
            check(!folder.isMusic() && !folder.isUnsupportedStreamingAudio, "Keep folder navigable")
        }
        let video = file("movie.MP4", icon: "MP4")
        check(video.isVideo() && !video.isMusic(), "Video support is unchanged")
        check(!file("notes.txt", icon: "txt").isMusic(), "Other file types stay unsupported")
        check(AudioExtension.audioSuffixs.contains("dsf"), "Local and other providers still support DSF")
        check(AudioExtension.audioSuffixs.contains("dff"), "Local and other providers still support DFF")
        print("\(checks) 115 format checks passed")
    }
}
