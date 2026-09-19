import Foundation

@main enum CacheTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ label: String) {
        precondition(condition(), label)
        checks += 1
    }

    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let source = root.appendingPathComponent("source.flac")
        let directory = root.appendingPathComponent(".MusicSpectrum", isDirectory: true)
        try Data(repeating: 17, count: 100).write(to: source)
        let original = AudioSpectrumCache.Revision(url: source)!
        let cache = AudioSpectrumCache(directory: directory, identity: "documents:music/source.flac")
        let pixels = (0..<(768 * 256 * 4)).map { UInt8($0 % 251) }
        let report = AudioSpectrumAnalyzer.Report(pixels: pixels, width: 768, height: 256,
            duration: 25, sampleRate: 48_000, sourceSampleRate: 48_000, bytes: original.bytes, codec: "FLAC", skippedPacketCount: 1)
        func write() { cache.store(report, revision: original, source: source, isCancelled: { false }) }
        check(cache.load(revision: original) == nil, "cache miss")
        write()
        let file = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first!
        let saved = try Data(contentsOf: file)
        let hit = cache.load(revision: original)!
        check(hit.pixels == pixels && hit.duration == 25 && hit.bytes == 100 && hit.codec == "FLAC", "round trip")
        check(hit.skippedPacketCount == 1, "partial analysis warning persists")
        check(saved.count < pixels.count, "lossless compression reduces bytes")
        check(AudioSpectrumCache(directory: directory, identity: "documents:music/source.flac").load(revision: original) != nil,
              "new instance/relaunch keeps cache")
        check(AudioSpectrumCache(directory: directory, identity: "documents:other/source.flac").load(revision: original) == nil,
              "same name in different folder does not collide")
        let invalidDirectory = root.appendingPathComponent("not-a-directory")
        try Data([0]).write(to: invalidDirectory)
        AudioSpectrumCache(directory: invalidDirectory, identity: "x").store(report, revision: original, source: source, isCancelled: { false })
        check(AudioSpectrumCache(directory: invalidDirectory, identity: "x").load(revision: original) == nil, "unwritable cache is optional")

        // Same byte count, newer modification date invalidates an existing entry.
        try FileManager.default.setAttributes([.modificationDate: original.modified.addingTimeInterval(10)], ofItemAtPath: source.path)
        let newer = AudioSpectrumCache.Revision(url: source)!
        check(cache.load(revision: newer) == nil, "modified source rejected")
        write()
        let unchanged = try Data(contentsOf: file)
        check(unchanged == saved, "changed-during-analysis source never stored")
        try FileManager.default.setAttributes([.modificationDate: original.modified], ofItemAtPath: source.path)
        try Data(repeating: 18, count: 101).write(to: source)
        check(cache.load(revision: AudioSpectrumCache.Revision(url: source)!) == nil, "file size change rejected")
        try Data(repeating: 17, count: 100).write(to: source)
        try FileManager.default.setAttributes([.modificationDate: original.modified], ofItemAtPath: source.path)

        for mutation in ["version", "identity", "width", "duration", "empty", "broken-compression", "pixel-checksum", "truncated"] {
            var entry = try PropertyListSerialization.propertyList(from: saved, options: [], format: nil) as! [String: Any]
            switch mutation {
            case "version": entry["version"] = -1
            case "identity": entry["identity"] = "wrong-file"
            case "width": entry["width"] = Int.max
            case "duration": entry["duration"] = 0
            case "empty": entry["pixels"] = Data(); entry["compressed"] = true
            case "broken-compression": entry["pixels"] = Data([1, 2, 3]); entry["compressed"] = true
            case "pixel-checksum": entry["pixels"] = Data(repeating: 0, count: pixels.count); entry["compressed"] = false
            default: break
            }
            let corrupted = mutation == "truncated" ? Data(saved.prefix(10)) :
                try PropertyListSerialization.data(fromPropertyList: entry, format: .binary, options: 0)
            try corrupted.write(to: file)
            check(cache.load(revision: original) == nil, "corrupt \(mutation) falls back")
        }
        try Data(repeating: 0, count: 2_000_000).write(to: file)
        check(cache.load(revision: original) == nil, "oversized cache rejected")
        try saved.write(to: file)

        // Cancelled jobs and missing sources must never publish cache entries.
        let cancelled = AudioSpectrumCache(directory: directory, identity: "cancelled")
        cancelled.store(report, revision: original, source: source, isCancelled: { true })
        check(cancelled.load(revision: original) == nil, "cancelled analysis not cached")
        check(AudioSpectrumCache.Revision(url: root.appendingPathComponent("missing")) == nil, "missing source")
        check(AudioSpectrumCache.Revision(url: directory) == nil, "folder is not a source")

        // Tiny budget evicts only generated reports, in last-access order.
        let budgetDirectory = root.appendingPathComponent("budget", isDirectory: true)
        try FileManager.default.createDirectory(at: budgetDirectory, withIntermediateDirectories: true)
        let foreign = budgetDirectory.appendingPathComponent("keep.txt")
        try Data([9]).write(to: foreign)
        let first = AudioSpectrumCache(directory: budgetDirectory, identity: "first", byteLimit: saved.count + 100)
        let second = AudioSpectrumCache(directory: budgetDirectory, identity: "second", byteLimit: saved.count + 100)
        let currentRevision = AudioSpectrumCache.Revision(url: source)!
        first.store(report, revision: currentRevision, source: source, isCancelled: { false })
        let firstFile = try FileManager.default.contentsOfDirectory(at: budgetDirectory, includingPropertiesForKeys: nil)
            .first { $0.pathExtension == "spectrum" }!
        try FileManager.default.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: firstFile.path)
        second.store(report, revision: currentRevision, source: source, isCancelled: { false })
        check(first.load(revision: currentRevision) == nil && second.load(revision: currentRevision) != nil, "budget evicts oldest")
        check(FileManager.default.fileExists(atPath: foreign.path), "foreign files preserved")
        print("PASS_SPECTRUM_CACHE \(checks) checks")
    }
}
