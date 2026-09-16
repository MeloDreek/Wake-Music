import Foundation
import Darwin

@main struct PreDownloadRegression {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("predownload-tests-" + UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let cache = root.appendingPathComponent("cache")
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        func staging() throws -> URL {
            let url = root.appendingPathComponent(UUID().uuidString + ".flac")
            try Data("complete audio fixture".utf8).write(to: url)
            return url
        }
        func name(_ title: String?, _ artist: String?, _ original: String = "original.mp3") -> String {
            PreDownloadedAudioFile.filename(title: title, artist: artist, originalName: original)
        }
        check(name("晴天", "周杰伦") == "晴天-周杰伦.mp3", "Title-artist order")
        check(name("  晴天\n", " 周杰伦 ", "source.FLAC") == "晴天-周杰伦.FLAC", "Whitespace and real format")
        check(name(nil, nil) == "original.mp3", "No tags fallback")
        check(name("Title", nil) == "original.mp3", "Missing artist fallback")
        check(name(nil, "Artist") == "original.mp3", "Missing title fallback")
        check(name(" ", "\n") == "original.mp3", "Blank tags fallback")
        check(name("a/b", "c:d") == "a_b-c_d.mp3", "Unsafe components")
        check(!name("..", "..").hasPrefix("."), "No hidden/dot filename")
        check(name(String(repeating: "音", count: 300), "artist").utf8.count < 255, "UTF8 length bound")
        check(name(nil, nil, "无标签.dsf") == "无标签.dsf", "DSF stays DSF")
        check(name("Title", "Artist", "song.dff").hasSuffix(".dff"), "DFF stays DFF")
        let first = try PreDownloadedAudioFile.store(staging(), in: cache, title: "Title", artist: "Artist", originalName: "original.flac", identity: "account1-file1")
        check(first.lastPathComponent == "Title-Artist.flac", "First readable name")
        check(PreDownloadedAudioFile.sourceIdentity(at: first) == "account1-file1", "Source marker stored")
        let second = try PreDownloadedAudioFile.store(staging(), in: cache, title: "Title", artist: "Artist", originalName: "other.flac", identity: "account2-file1")
        check(second.lastPathComponent == "Title-Artist 2.flac", "Separate accounts get collision suffix")
        let third = try PreDownloadedAudioFile.store(staging(), in: cache, title: "Title", artist: "Artist", originalName: "other.flac", identity: "account1-file2")
        check(third.lastPathComponent == "Title-Artist 3.flac", "Third collision")
        check(try Data(contentsOf: first) == Data("complete audio fixture".utf8), "Collision never overwrites")
        let duplicateStage = try staging()
        let same = try PreDownloadedAudioFile.store(duplicateStage, in: cache, title: "Renamed", artist: "Artist", originalName: "changed.flac", identity: "account1-file1")
        check(same.standardizedFileURL == first.standardizedFileURL && !fm.fileExists(atPath: duplicateStage.path), "Same source deduplicates regardless of tags")
        try fm.removeItem(at: first)
        let replacement = try PreDownloadedAudioFile.store(staging(), in: cache, title: "Title", artist: "Artist", originalName: "new.flac", identity: "account3-file1")
        check(replacement == first && PreDownloadedAudioFile.sourceIdentity(at: replacement) != "account1-file1", "Eviction cannot leave stale identity mapping")
        let renamed = cache.appendingPathComponent("User renamed.flac")
        try fm.moveItem(at: second, to: renamed)
        check(PreDownloadedAudioFile.sourceIdentity(at: renamed) == "account2-file1", "Identity survives rename")
        let untagged = try staging()
        check(PreDownloadedAudioFile.sourceIdentity(at: untagged) == nil, "Legacy untagged file")
        let fallback = try PreDownloadedAudioFile.store(untagged, in: cache, title: nil, artist: nil, originalName: "Original filename.flac", identity: "untagged-source")
        check(fallback.lastPathComponent == "Original filename.flac", "Store original filename when tags absent")
        print("\(checks) predownload regression checks passed")
    }
}
