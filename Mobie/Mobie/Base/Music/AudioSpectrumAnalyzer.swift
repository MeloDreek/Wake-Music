import Foundation
import Accelerate
import Compression
import CryptoKit
import FFmpegKit
import Libavformat
import Libavcodec
import Libavutil
import Libswresample

/// Offline, pre-EQ analysis with a private decoder. No playback state or audio
/// session changes, network access, whole-track PCM arrays, or temporary files.
final class AudioSpectrumAnalyzer {
    struct Report {
        let pixels: [UInt8]
        let width: Int
        let height: Int
        let duration: Double
        let sampleRate: Double
        let sourceSampleRate: Double
        let bytes: Int64
        let codec: String
        var skippedPacketCount: Int = 0
        var averageBitrate: Double { Double(bytes) * 8 / duration }
    }
    enum Failure: Error { case unreadable, cancelled }
    private static let queue = DispatchQueue(label: "music.spectrum", qos: .utility)
    private let lock = NSLock()
    private var cancelled = false
    private var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    private func checkCancellation() throws { if isCancelled { throw Failure.cancelled } }
    func start(url: URL, cache: AudioSpectrumCache? = nil, progress: @escaping (Double) -> Void,
               completion: @escaping (Result<Report, Error>) -> Void) {
        Self.queue.async { [self] in
            let result = Result {
                try checkCancellation()
                let revision = AudioSpectrumCache.Revision(url: url)
                if let revision, let report = cache?.load(revision: revision) {
                    try checkCancellation()
                    // Do not return stale data if the source was replaced during the read.
                    if AudioSpectrumCache.Revision(url: url) == revision { return report }
                }
                let report = try analyze(url: url, progress: progress)
                try checkCancellation()
                if let revision {
                    cache?.store(report, revision: revision, source: url, isCancelled: { self.isCancelled })
                }
                try checkCancellation()
                return report
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func analyze(url: URL, progress: @escaping (Double) -> Void) throws -> Report {
        try checkCancellation()
        guard url.isFileURL,
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true, let bytes = values.fileSize, bytes > 0 else { throw Failure.unreadable }
        var format = avformat_alloc_context()
        guard let allocated = format else { throw Failure.unreadable }
        allocated.pointee.interrupt_callback = AVIOInterruptCB(callback: { opaque in
            guard let opaque else { return 1 }
            return Unmanaged<AudioSpectrumAnalyzer>.fromOpaque(opaque).takeUnretainedValue().isCancelled ? 1 : 0
        }, opaque: Unmanaged.passUnretained(self).toOpaque())
        var options: OpaquePointer?
        av_dict_set(&options, "protocol_whitelist", "file", 0)
        defer { av_dict_free(&options); avformat_close_input(&format) }
        guard avformat_open_input(&format, url.path, nil, &options) >= 0,
              let context = format, avformat_find_stream_info(context, nil) >= 0 else { throw Failure.unreadable }
        let index = av_find_best_stream(context, AVMEDIA_TYPE_AUDIO, -1, -1, nil, 0)
        guard index >= 0, let stream = context.pointee.streams[Int(index)],
              let parameters = stream.pointee.codecpar,
              let decoder = avcodec_find_decoder(parameters.pointee.codec_id) else { throw Failure.unreadable }
        var codec = avcodec_alloc_context3(decoder)
        defer { avcodec_free_context(&codec) }
        guard let codecContext = codec, avcodec_parameters_to_context(codecContext, parameters) >= 0 else { throw Failure.unreadable }
        codecContext.pointee.thread_count = 1
        codecContext.pointee.pkt_timebase = stream.pointee.time_base
        guard avcodec_open2(codecContext, decoder, nil) >= 0 else { throw Failure.unreadable }
        let sourceRate = Double(codecContext.pointee.sample_rate)
        let sourceSampleFormat = codecContext.pointee.sample_fmt
        let channels = Int(codecContext.pointee.ch_layout.nb_channels)
        let duration = stream.pointee.duration > 0
            ? Double(stream.pointee.duration) * av_q2d(stream.pointee.time_base)
            : Double(context.pointee.duration) / Double(AV_TIME_BASE)
        guard sourceRate.isFinite, sourceRate > 0, duration.isFinite, duration > 0,
              channels > 0, channels <= 8 else { throw Failure.unreadable }
        let rate = min(sourceRate, 192_000)
        let accumulator = try SpectrumAccumulator(duration: duration, sampleRate: rate)
        var resampler: OpaquePointer?
        var layout = AVChannelLayout()
        guard av_channel_layout_copy(&layout, &codecContext.pointee.ch_layout) >= 0 else { throw Failure.unreadable }
        defer { swr_free(&resampler); av_channel_layout_uninit(&layout) }
        guard swr_alloc_set_opts2(&resampler, &layout, AV_SAMPLE_FMT_FLTP, Int32(rate),
                                 &codecContext.pointee.ch_layout, codecContext.pointee.sample_fmt,
                                 Int32(sourceRate), 0, nil) >= 0, swr_init(resampler) >= 0 else { throw Failure.unreadable }
        // Output and FFT staging buffers stay bounded even for enormous files.
        let capacity = 32768
        let planes = (0..<channels).map { _ in UnsafeMutablePointer<Float>.allocate(capacity: capacity) }
        let staging = (0..<channels).map { _ in UnsafeMutablePointer<Float>.allocate(capacity: 4096) }
        defer { planes.forEach { $0.deallocate() }; staging.forEach { $0.deallocate() } }
        var filled = 0
        var samplePosition: Int64 = 0
        var decodedFrameCount = 0
        var skippedPacketCount = 0
        var consecutiveErrors = 0
        var needsTimestampRecovery = false
        var fallbackResumePosition: Int64 = 0
        var lastProgress = Date.distantPast
        func consume(_ amount: Int) throws {
            var position = 0
            while position < amount {
                try checkCancellation()
                let length = min(4096 - filled, amount - position)
                for channel in 0..<channels { staging[channel].advanced(by: filled).update(from: planes[channel].advanced(by: position), count: length) }
                filled += length; position += length
                if filled == 4096 {
                    accumulator.append(channels: staging, channelCount: channels, count: filled, time: Double(samplePosition) / rate)
                    samplePosition += Int64(filled); filled = 0
                }
            }
            if Date().timeIntervalSince(lastProgress) > 0.2 {
                lastProgress = Date()
                let fraction = min(0.99, Double(samplePosition) / rate / duration)
                DispatchQueue.main.async { progress(fraction) }
            }
        }
        func drainResampler() throws {
            while true {
                try checkCancellation()
                var output = planes.map { Optional(UnsafeMutableRawPointer($0).assumingMemoryBound(to: UInt8.self)) }
                let amount = swr_convert(resampler, &output, Int32(capacity), nil, 0)
                guard amount >= 0 else { throw Failure.unreadable }
                if amount == 0 { return }
                try consume(Int(amount))
            }
        }
        func finishStaging() {
            guard filled > 0 else { return }
            accumulator.append(channels: staging, channelCount: channels, count: filled, time: Double(samplePosition) / rate)
            samplePosition += Int64(filled)
            filled = 0
        }
        var packet = av_packet_alloc()
        var frame = av_frame_alloc()
        defer { av_packet_free(&packet); av_frame_free(&frame) }
        guard let packetValue = packet, let frameValue = frame else { throw Failure.unreadable }
        let timeBase = av_q2d(stream.pointee.time_base)
        let streamStart = stream.pointee.start_time == Int64.min ? 0 : Double(stream.pointee.start_time)
        func sampleOffset(timestamp: Int64) -> Int64? {
            guard timestamp != Int64.min else { return nil }
            let time = (Double(timestamp) - streamStart) * timeBase
            // Reject nonsensical timestamps rather than overflowing or allocating
            // silence for arbitrary gaps. Missing regions stay empty in the plot.
            guard time.isFinite, time >= 0, time <= duration + 1,
                  time * rate < Double(Int64.max) else { return nil }
            return Int64((time * rate).rounded())
        }
        func recoverInvalidPacket() throws {
            try checkCancellation()
            skippedPacketCount += 1
            consecutiveErrors += 1
            // Real DTS-in-WAV files can contain a malformed trailing packet.
            // Recover isolated INVALIDDATA only; never swallow IO, allocation,
            // format-change errors, or sustained corruption.
            guard skippedPacketCount <= 64, consecutiveErrors <= 8 else { throw Failure.unreadable }
            try drainResampler()
            finishStaging()
            let packetStart = sampleOffset(timestamp: packetValue.pointee.pts)
                ?? sampleOffset(timestamp: packetValue.pointee.dts)
                ?? max(samplePosition, fallbackResumePosition)
            let packetDuration = Double(max(0, packetValue.pointee.duration)) * timeBase * rate
            if packetDuration.isFinite, packetDuration >= 0, packetDuration <= (duration + 1) * rate,
               Double(packetStart) + packetDuration < Double(Int64.max) {
                fallbackResumePosition = max(samplePosition, packetStart + Int64(packetDuration.rounded()))
            } else {
                fallbackResumePosition = samplePosition
            }
            needsTimestampRecovery = true
            // Do not interpolate across a damaged region using old filter delay.
            swr_close(resampler)
            guard swr_init(resampler) >= 0 else { throw Failure.unreadable }
        }
        func receive() throws {
            while true {
                try checkCancellation()
                let result = avcodec_receive_frame(codecContext, frameValue)
                if result == swift_AVERROR(EAGAIN) || result == swift_AVERROR_EOF { return }
                if result == swift_AVERROR_INVALIDDATA { try recoverInvalidPacket(); return }
                guard result >= 0 else { throw Failure.unreadable }
                defer { av_frame_unref(frameValue) }
                // A midstream format change must not feed mismatched buffers to swr.
                guard frameValue.pointee.sample_rate == Int32(sourceRate),
                      frameValue.pointee.format == sourceSampleFormat.rawValue,
                      frameValue.pointee.ch_layout.nb_channels == channels,
                      av_channel_layout_compare(&frameValue.pointee.ch_layout, &layout) == 0,
                      frameValue.pointee.nb_samples > 0, let data = frameValue.pointee.extended_data else { throw Failure.unreadable }
                if needsTimestampRecovery {
                    samplePosition = max(samplePosition,
                        sampleOffset(timestamp: frameValue.pointee.best_effort_timestamp) ?? fallbackResumePosition)
                    needsTimestampRecovery = false
                }
                decodedFrameCount += 1
                consecutiveErrors = 0
                var input = (0..<channels).map { data[$0].map { UnsafePointer<UInt8>($0) } }
                var output = planes.map { Optional(UnsafeMutableRawPointer($0).assumingMemoryBound(to: UInt8.self)) }
                let amount = swr_convert(resampler, &output, Int32(capacity), &input, frameValue.pointee.nb_samples)
                guard amount >= 0 else { throw Failure.unreadable }
                try consume(Int(amount))
            }
        }
        while true {
            try checkCancellation()
            let result = av_read_frame(context, packetValue)
            if result == swift_AVERROR_EOF { break }
            guard result >= 0 else { throw Failure.unreadable }
            defer { av_packet_unref(packetValue) }
            if packetValue.pointee.stream_index == index {
                var sent = avcodec_send_packet(codecContext, packetValue)
                if sent == swift_AVERROR(EAGAIN) {
                    try receive()
                    sent = avcodec_send_packet(codecContext, packetValue)
                }
                if sent == swift_AVERROR_INVALIDDATA { try recoverInvalidPacket(); continue }
                guard sent >= 0 else { throw Failure.unreadable }
                try receive()
            }
        }
        guard avcodec_send_packet(codecContext, nil) >= 0 else { throw Failure.unreadable }
        try receive()
        try drainResampler()
        finishStaging()
        guard samplePosition > 0, decodedFrameCount > 0,
              skippedPacketCount == 0 || decodedFrameCount >= skippedPacketCount * 100 else { throw Failure.unreadable }
        try checkCancellation()
        let codecName = String(cString: avcodec_get_name(parameters.pointee.codec_id))
        // FFmpeg reports DSD samples in packed bytes (the DSF demuxer divides
        // the header's 1-bit sample rate by eight). Keep source and PCM analysis
        // rates distinct, rather than presenting 352.8 kHz as DSD64's source rate.
        let originalRate = codecName.hasPrefix("dsd_") ? sourceRate * 8 : sourceRate
        let fileFormat = url.pathExtension.isEmpty ? codecName.uppercased() : url.pathExtension.uppercased()
        return Report(pixels: accumulator.pixels(), width: accumulator.width, height: accumulator.height,
                      duration: duration, sampleRate: rate, sourceSampleRate: originalRate,
                      bytes: Int64(bytes), codec: fileFormat, skippedPacketCount: skippedPacketCount)
    }
}

/// Disk-only cache, used on the analyzer's serial background queue. No audio or
/// artwork is duplicated. The version covers the decoder, FFT and color mapping.
final class AudioSpectrumCache {
    struct Revision: Codable, Equatable {
        let bytes: Int64
        let modified: Date
        let created: Date?

        init?(url: URL) {
            // Read fresh attributes; URL resource values may retain an old date.
            guard url.isFileURL,
                  let values = try? FileManager.default.attributesOfItem(atPath: url.path),
                  values[.type] as? FileAttributeType == .typeRegular,
                  let size = values[.size] as? NSNumber, size.int64Value > 0,
                  let modified = values[.modificationDate] as? Date else { return nil }
            bytes = size.int64Value
            self.modified = modified
            created = values[.creationDate] as? Date
        }
    }

    private struct Entry: Codable {
        let version: Int
        let identity: String
        let revision: Revision
        let pixels: Data
        let pixelDigest: Data
        let compressed: Bool
        let width: Int
        let height: Int
        let duration: Double
        let sampleRate: Double
        let sourceSampleRate: Double
        let codec: String
        let skippedPacketCount: Int
    }

    private static let version = 1
    private static let pixelCount = 768 * 256 * 4
    private static let maximumEntryBytes = pixelCount + 32_768
    private let directory: URL
    private let identity: String
    private let byteLimit: Int
    private var entryURL: URL { directory.appendingPathComponent(identity + ".spectrum") }

    init(directory: URL, identity: String, byteLimit: Int = 128 * 1024 * 1024) {
        self.directory = directory
        // Hash paths rather than using title/artist names, which collide and may
        // contain slashes. A Documents-relative identity survives sandbox moves.
        self.identity = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        self.byteLimit = max(0, byteLimit)
    }

    func load(revision: Revision) -> AudioSpectrumAnalyzer.Report? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: entryURL.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.intValue <= Self.maximumEntryBytes,
              let data = try? Data(contentsOf: entryURL),
              let entry = try? PropertyListDecoder().decode(Entry.self, from: data),
              entry.version == Self.version, entry.identity == identity, entry.revision == revision,
              entry.width == 768, entry.height == 256,
              !entry.pixels.isEmpty, entry.pixels.count <= Self.pixelCount,
              entry.duration.isFinite, entry.duration > 0,
              entry.sampleRate.isFinite, entry.sampleRate > 0, entry.sampleRate <= 192_000,
              entry.sourceSampleRate.isFinite, entry.sourceSampleRate > 0,
              entry.skippedPacketCount >= 0, entry.skippedPacketCount <= 64,
              !entry.codec.isEmpty, entry.codec.utf8.count <= 256 else { return nil }
        var pixels: [UInt8]
        if entry.compressed {
            // A corrupt cache must not cause an unbounded decompression allocation.
            pixels = [UInt8](repeating: 0, count: Self.pixelCount)
            let count = pixels.withUnsafeMutableBufferPointer { output in
                entry.pixels.withUnsafeBytes { input in
                    compression_decode_buffer(output.baseAddress!, output.count,
                        input.bindMemory(to: UInt8.self).baseAddress!, input.count, nil, COMPRESSION_LZFSE)
                }
            }
            guard count == Self.pixelCount else { return nil }
        } else {
            guard entry.pixels.count == Self.pixelCount else { return nil }
            pixels = Array(entry.pixels)
        }
        guard Data(SHA256.hash(data: Data(pixels))) == entry.pixelDigest else { return nil }
        // Access time for our own LRU policy; the source music is never touched.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: entryURL.path)
        return AudioSpectrumAnalyzer.Report(pixels: pixels, width: entry.width, height: entry.height,
            duration: entry.duration, sampleRate: entry.sampleRate, sourceSampleRate: entry.sourceSampleRate,
            bytes: revision.bytes, codec: entry.codec, skippedPacketCount: entry.skippedPacketCount)
    }

    func store(_ report: AudioSpectrumAnalyzer.Report, revision: Revision, source: URL,
               isCancelled: () -> Bool) {
        guard !isCancelled(), report.width == 768, report.height == 256,
              report.pixels.count == Self.pixelCount, report.bytes == revision.bytes,
              report.duration.isFinite, report.duration > 0,
              report.sampleRate.isFinite, report.sampleRate > 0, report.sampleRate <= 192_000,
              report.sourceSampleRate.isFinite, report.sourceSampleRate > 0,
              !report.codec.isEmpty, report.codec.utf8.count <= 256 else { return }
        var packed = [UInt8](repeating: 0, count: Self.pixelCount)
        let count = packed.withUnsafeMutableBufferPointer { output in
            report.pixels.withUnsafeBufferPointer { input in
                compression_encode_buffer(output.baseAddress!, output.count,
                    input.baseAddress!, input.count, nil, COMPRESSION_LZFSE)
            }
        }
        let pixels = count > 0 ? Data(packed.prefix(count)) : Data(report.pixels)
        let entry = Entry(version: Self.version, identity: identity, revision: revision,
            pixels: pixels, pixelDigest: Data(SHA256.hash(data: Data(report.pixels))),
            compressed: count > 0, width: report.width, height: report.height,
            duration: report.duration, sampleRate: report.sampleRate,
            sourceSampleRate: report.sourceSampleRate, codec: report.codec, skippedPacketCount: report.skippedPacketCount)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(entry), data.count <= min(byteLimit, Self.maximumEntryBytes),
              !isCancelled(), Revision(url: source) == revision else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: entryURL, options: .atomic)
            trim()
        } catch {
            // Storage pressure or an unwritable directory cannot fail analysis.
        }
    }

    private func trim() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]) else { return }
        let files: [(url: URL, bytes: Int, date: Date)] = urls.compactMap { url in
            // Only delete this cache's own generated files, never foreign contents.
            let name = url.deletingPathExtension().lastPathComponent
            guard url.pathExtension == "spectrum", name.count == 64,
                  name.allSatisfy({ "0123456789abcdef".contains($0) }),
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
        var total = files.reduce(0) { $0 + $1.bytes }
        for file in files.sorted(by: { $0.date < $1.date }) where total > byteLimit {
            if (try? fm.removeItem(at: file.url)) != nil { total -= file.bytes }
        }
    }
}

/// 4096-sample Hann windows; peak-held time/frequency bins, calibrated in dBFS.
/// Pure streaming DSP, also compiled by the standalone regression harness.
final class SpectrumAccumulator {
    let width = 768
    let height = 256
    private let count = 4096
    private let duration: Double
    private let sampleRate: Double
    private let setup: vDSP_DFT_Setup
    private var window = [Float](repeating: 0, count: 4096)
    private var real = [Float](repeating: 0, count: 4096)
    private let imaginary = [Float](repeating: 0, count: 4096)
    private var outputReal = [Float](repeating: 0, count: 4096)
    private var outputImaginary = [Float](repeating: 0, count: 4096)
    private var peaks = [Float](repeating: -100, count: 768 * 256)
    private var scale: Float = 0

    init(duration: Double, sampleRate: Double) throws {
        self.duration = duration
        self.sampleRate = sampleRate
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, 4096, .FORWARD) else { throw AudioSpectrumAnalyzer.Failure.unreadable }
        self.setup = setup
        vDSP_hann_window(&window, 4096, Int32(vDSP_HANN_DENORM))
        scale = 2 / window.reduce(0, +)
    }
    deinit { vDSP_DFT_DestroySetup(setup) }

    func append(channels: UnsafePointer<UnsafeMutablePointer<Float>>, channelCount: Int, count frames: Int, time: Double) {
        let first = min(width - 1, max(0, Int(time / duration * Double(width))))
        let last = min(width - 1, max(first, Int((time + Double(frames) / sampleRate) / duration * Double(width))))
        for channel in 0..<channelCount {
            for i in 0..<count { real[i] = i < frames && channels[channel][i].isFinite ? channels[channel][i] * window[i] : 0 }
            vDSP_DFT_Execute(setup, real, imaginary, &outputReal, &outputImaginary)
            for bin in 0..<(count / 2) {
                let magnitude = hypotf(outputReal[bin], outputImaginary[bin]) * scale * (bin == 0 ? 0.5 : 1)
                let db = min(0, max(-100, 20 * log10f(max(0.00001, magnitude))))
                let row = height - 1 - min(height - 1, bin * height / (count / 2))
                for column in first...last { peaks[row * width + column] = max(peaks[row * width + column], db) }
            }
        }
    }

    func level(column: Int, row: Int) -> Float { peaks[row * width + column] }

    func pixels() -> [UInt8] {
        let stops: [[Float]] = [[5, 9, 18], [32, 28, 88], [147, 41, 117], [237, 112, 47], [255, 235, 154]]
        var result = [UInt8](repeating: 255, count: width * height * 4)
        for (index, db) in peaks.enumerated() {
            let position = (db + 100) / 100 * 4
            let lower = min(3, Int(position))
            let fraction = position - Float(lower)
            for c in 0..<3 { result[index * 4 + c] = UInt8(stops[lower][c] * (1 - fraction) + stops[lower + 1][c] * fraction) }
        }
        return result
    }
}
