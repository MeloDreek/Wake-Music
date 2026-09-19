import Foundation

@main enum CacheIntegrationTests {
    static func run(_ source: URL, _ cache: AudioSpectrumCache, cancelled: Bool = false) async throws -> (AudioSpectrumAnalyzer.Report, Int) {
        try await withCheckedThrowingContinuation { continuation in
            let analyzer = AudioSpectrumAnalyzer()
            if cancelled { analyzer.cancel() }
            var progressCalls = 0
            analyzer.start(url: source, cache: cache, progress: { _ in progressCalls += 1 }, completion: { result in
                continuation.resume(with: result.map { ($0, progressCalls) })
            })
        }
    }

    static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let source = root.appendingPathComponent("tone.flac")
        let directory = root.appendingPathComponent("integration", isDirectory: true)
        let cache = AudioSpectrumCache(directory: directory, identity: "source")
        let start = Date()
        let (report, firstProgress) = try await run(source, cache)
        precondition(firstProgress > 0)
        let firstTime = Date().timeIntervalSince(start)
        let secondStart = Date()
        let (hit, secondProgress) = try await run(source, cache)
        precondition(secondProgress == 0 && hit.pixels == report.pixels && hit.duration == report.duration)
        print("PASS_SPECTRUM_CACHE_INTEGRATION first=\(firstTime)s cached=\(Date().timeIntervalSince(secondStart))s")

        // Corruption falls through to the real decoder and repairs the cache.
        let file = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first!
        try Data([0, 1, 2]).write(to: file)
        let (repaired, repairProgress) = try await run(source, cache)
        precondition(repairProgress > 0 && repaired.pixels == report.pixels)
        precondition(cache.load(revision: AudioSpectrumCache.Revision(url: source)!) != nil)

        // A fresh revision forces reanalysis, even when the number of bytes matches.
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(10)], ofItemAtPath: source.path)
        let (_, refreshProgress) = try await run(source, cache)
        precondition(refreshProgress > 0)
        do {
            _ = try await run(source, cache, cancelled: true)
            fatalError("pre-cancelled cache hit returned success")
        } catch AudioSpectrumAnalyzer.Failure.cancelled { }

        // Invalid media can only succeed via the cached report: proves the hit
        // path returns before calling any FFmpeg decoder/probe, not just DSP.
        let invalid = root.appendingPathComponent("invalid.flac")
        try Data(repeating: 1, count: 32).write(to: invalid)
        let invalidRevision = AudioSpectrumCache.Revision(url: invalid)!
        let bypass = AudioSpectrumCache(directory: root.appendingPathComponent("bypass"), identity: "cached-only")
        let fixture = AudioSpectrumAnalyzer.Report(pixels: report.pixels, width: report.width, height: report.height,
            duration: 10, sampleRate: 48_000, sourceSampleRate: 48_000, bytes: 32, codec: "FLAC")
        bypass.store(fixture, revision: invalidRevision, source: invalid, isCancelled: { false })
        let (_, bypassProgress) = try await run(invalid, bypass)
        precondition(bypassProgress == 0)
        let failedDirectory = root.appendingPathComponent("failed")
        let failed = AudioSpectrumCache(directory: failedDirectory, identity: "failure")
        do {
            _ = try await run(invalid, failed)
            fatalError("invalid file unexpectedly decoded")
        } catch AudioSpectrumAnalyzer.Failure.unreadable { }
        precondition(!FileManager.default.fileExists(atPath: failedDirectory.path))
        print("PASS_SPECTRUM_CACHE_INTEGRATION invalidation repair bypass cancellation failure")
    }
}
