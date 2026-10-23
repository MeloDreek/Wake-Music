//
//  AudioFingerprintMatcher.swift
//  Waketag
//
//  Created by kaka on 2026/5/20.
//

import KakaFoundation
import AppGroupKit
import AVFoundation
import ShazamKit
import Alamofire

/// Local decoding is bounded and off the main thread. Every request owns its session and
/// metadata context: identical signatures and concurrent batch edits cannot mix results.
class AudioFingerprintMatcher: NSObject, SHSessionDelegate {
    private typealias Completion = (Result<AudioFingerprintModel, KakaError>) -> Void

    private final class Request {
        let id = UUID()
        let model: MusicItemModel?
        let requestsLyrics: Bool
        let completion: Completion
        let generation: UInt
        var session: SHSession?
        var signatures: [SHSignature] = []
        var nextSignature = 0
        var timeout: DispatchWorkItem?

        init(model: MusicItemModel?, requestsLyrics: Bool, generation: UInt,
             completion: @escaping Completion) {
            self.model = model
            self.requestsLyrics = requestsLyrics
            self.generation = generation
            self.completion = completion
        }
    }

    private static let decodingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.wakemusic.fingerprint-decoding"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

    // Requests, delegates and callbacks are confined to main. The generation also protects
    // already-enqueued starts and conversion work when cancellation originates off-main.
    private var requests: [UUID: Request] = [:]
    private let generationLock = NSLock()
    private var generation: UInt = 0

    private let normalError = "Audio fingerprint generated, but no matching track was found in global music databases. It may be an unreleased edit or remix, often related to unique waveform characteristics. Please edit manually.".localStr()
    private let formatError = "This specific audio format is not supported for fingerprinting. We highly recommend using modern popular formats such as FLAC, M4A, WAV, or MP3. Please edit manually.".localStr()

    deinit {
        for request in requests.values {
            request.timeout?.cancel()
            request.session?.delegate = nil
        }
    }

    private func currentGeneration() -> UInt {
        generationLock.lock()
        defer { generationLock.unlock() }
        return generation
    }

    /// Cancels local work without calling its completion. Callers cancelling an Operation
    /// should finish that operation themselves. In particular, cancellation is not a failed
    /// fingerprint and must not launch a catalog-search fallback or metadata writes.
    func cancelLocalMatching() {
        generationLock.lock()
        generation &+= 1
        generationLock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for request in Array(self.requests.values)
                where request.generation != self.currentGeneration() {
                self.remove(request)
            }
        }
    }

    func matchLocalAudio(model: MusicItemModel, isRequestLyrics: Bool = true,
                         completion: @escaping (Result<AudioFingerprintModel, KakaError>) -> Void) {
        let request = Request(model: model, requestsLyrics: isRequestLyrics,
                              generation: currentGeneration(), completion: completion)
        DispatchQueue.main.async { [weak self] in
            guard let self, request.generation == self.currentGeneration() else { return }
            self.requests[request.id] = request
            self.scheduleTimeout(for: request, seconds: 45) { [weak self] request in
                guard let self else { return }
                self.finish(request, with: .failure(.custom(self.normalError)))
            }
            let catalog = SHSession().catalog
            let minimum = catalog.minimumQuerySignatureDuration
            let maximum = min(12, catalog.maximumQuerySignatureDuration)
            Self.decodingQueue.addOperation { [weak self] in
                guard let self, self.currentGeneration() == request.generation else { return }
                let result: Result<[SHSignature], KakaError>
                do {
                    result = .success(try self.makeSignatures(url: model.mediaPlayURL,
                        minimumDuration: minimum, maximumDuration: maximum,
                        isCancelled: { self.currentGeneration() != request.generation }))
                } catch let error as KakaError {
                    result = .failure(error)
                } catch {
                    result = .failure(.custom(self.formatError))
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.isActive(request) else { return }
                    switch result {
                    case .success(let signatures):
                        request.signatures = signatures
                        self.submitNextSignature(request)
                    case .failure(let error):
                        self.finish(request, with: .failure(error))
                    }
                }
            }
        }
    }

    /// Streams fresh input once, at its actual sample rate, until the converter reaches EOF.
    /// Returning the same buffer on every converter input callback repeats samples and used
    /// to truncate high-rate audio (or pad short files with duplicated audio).
    private func makeSignatures(url: URL, minimumDuration: TimeInterval,
                                maximumDuration: TimeInterval,
                                isCancelled: @escaping () -> Bool) throws -> [SHSignature] {
        guard url.isFileURL else { throw KakaError.custom(formatError) }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let file = try AVAudioFile(forReading: url)
        let inputFormat = file.processingFormat
        guard inputFormat.sampleRate.isFinite, inputFormat.sampleRate > 0,
              inputFormat.sampleRate <= 768_000,
              inputFormat.channelCount > 0, inputFormat.channelCount <= 32,
              file.length > 0,
              maximumDuration.isFinite, maximumDuration >= minimumDuration,
              let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        else { throw KakaError.custom(formatError) }

        let duration = Double(file.length) / inputFormat.sampleRate
        guard duration >= minimumDuration else {
            throw KakaError.custom("Audio sample is too short or invalid for fingerprinting. The duration is insufficient for acoustic analysis. Please edit it manually.".localStr())
        }
        // Avoid long silent intros on full-length tracks. One other non-overlapping sample
        // is available only if the first query fails; never upload the whole recording.
        let firstOffset = duration > 30 ? min(15, duration * 0.1) : 0
        var offsets = [min(firstOffset, max(0, duration - maximumDuration))]
        // Cap source decoding at roughly 72 seconds even for long mixes/podcasts.
        let middleOffset = min(60, duration / 2, max(0, duration - maximumDuration))
        if middleOffset - offsets[0] >= maximumDuration { offsets.append(middleOffset) }

        var signatures: [SHSignature] = []
        var sourceFrame: AVAudioFramePosition = 0
        for offset in offsets {
            if isCancelled() { throw KakaError.youhaveCanceled }
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat),
                  let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 8192),
                  let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: 4096)
            else { throw KakaError.custom(formatError) }
            let startFrame = AVAudioFramePosition(offset * inputFormat.sampleRate)
            // Some compressed files open successfully but AVAudioFile.framePosition's getter
            // AND setter raise Objective-C exceptions (not catchable by Swift do/catch).
            // Count actual decoded frames and advance via bounded reads; never query or seek.
            while sourceFrame < startFrame {
                if isCancelled() { throw KakaError.youhaveCanceled }
                let count = min(AVAudioFramePosition(input.frameCapacity), startFrame - sourceFrame)
                try file.read(into: input, frameCount: AVAudioFrameCount(count))
                guard input.frameLength > 0 else { break }
                sourceFrame += AVAudioFramePosition(input.frameLength)
            }
            guard sourceFrame >= startFrame else { continue }
            let endFrame = min(file.length, startFrame + AVAudioFramePosition(maximumDuration * inputFormat.sampleRate))
            let generator = SHSignatureGenerator()
            var outputFrames: AVAudioFramePosition = 0
            let maximumOutputFrames = AVAudioFramePosition(maximumDuration * targetFormat.sampleRate)
            var hasAudibleSamples = false
            var reachedEnd = false
            var iterations = 0
            while !reachedEnd && outputFrames < maximumOutputFrames {
                if isCancelled() { throw KakaError.youhaveCanceled }
                // A corrupt decoder/converter must not keep a batch edit running forever.
                iterations += 1
                guard iterations <= 1024 else { throw KakaError.custom(formatError) }
                output.frameLength = 0
                var conversionError: NSError?
                var readError: Error?
                let status = converter.convert(to: output, error: &conversionError) { requested, state in
                    guard !isCancelled(), sourceFrame < endFrame else {
                        state.pointee = .endOfStream
                        return nil
                    }
                    do {
                        let count = min(Int64(requested), Int64(input.frameCapacity), endFrame - sourceFrame)
                        try file.read(into: input, frameCount: AVAudioFrameCount(count))
                        guard input.frameLength > 0 else {
                            state.pointee = .endOfStream
                            return nil
                        }
                        sourceFrame += AVAudioFramePosition(input.frameLength)
                        state.pointee = .haveData
                        return input
                    } catch {
                        readError = error
                        state.pointee = .endOfStream
                        return nil
                    }
                }
                if let readError { throw readError }
                if let conversionError { throw conversionError }
                guard status != .error else { throw KakaError.custom(formatError) }
                if output.frameLength > 0 {
                    output.frameLength = min(output.frameLength, AVAudioFrameCount(maximumOutputFrames - outputFrames))
                    if let samples = output.floatChannelData?[0], !hasAudibleSamples {
                        for index in 0..<Int(output.frameLength) where abs(samples[index]) > 0.0001 {
                            hasAudibleSamples = true
                            break
                        }
                    }
                    try generator.append(output, at: AVAudioTime(sampleTime: outputFrames, atRate: targetFormat.sampleRate))
                    outputFrames += AVAudioFramePosition(output.frameLength)
                }
                reachedEnd = status == .endOfStream || (status == .inputRanDry && output.frameLength == 0)
            }
            let signature = generator.signature()
            if hasAudibleSamples, signature.duration >= minimumDuration,
               signature.duration <= maximumDuration + 0.001 {
                signatures.append(signature)
            }
        }
        guard !signatures.isEmpty else {
            throw KakaError.custom("Failed to generate a valid acoustic signature. Please check if the audio file is muted or completely silent. Please edit it manually.".localStr())
        }
        return signatures
    }

    private func isActive(_ request: Request) -> Bool {
        requests[request.id] === request && request.generation == currentGeneration()
    }

    private func remove(_ request: Request) {
        request.timeout?.cancel()
        request.timeout = nil
        request.session?.delegate = nil
        request.session = nil
        requests.removeValue(forKey: request.id)
    }

    private func finish(_ request: Request, with result: Result<AudioFingerprintModel, KakaError>) {
        guard isActive(request) else { return }
        remove(request)
        request.completion(result)
    }

    private func scheduleTimeout(for request: Request, seconds: TimeInterval, action: @escaping (Request) -> Void) {
        request.timeout?.cancel()
        let work = DispatchWorkItem { [weak self, weak request] in
            guard let self, let request, self.isActive(request) else { return }
            action(request)
        }
        request.timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func submitNextSignature(_ request: Request) {
        guard isActive(request) else { return }
        request.session?.delegate = nil
        guard request.nextSignature < request.signatures.count else {
            finish(request, with: .failure(.custom(normalError)))
            return
        }
        let signature = request.signatures[request.nextSignature]
        request.nextSignature += 1
        // A fresh session per attempt also makes a late delegate from a timed-out request harmless.
        let session = SHSession()
        session.delegate = self
        request.session = session
        scheduleTimeout(for: request, seconds: 12) { [weak self] request in
            self?.submitNextSignature(request)
        }
        session.match(signature)
    }

    func session(_ session: SHSession, didFind match: SHMatch) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let request = self.requests.values.first(where: { $0.session === session }),
                  self.isActive(request) else { return }
            request.session?.delegate = nil
            request.session = nil
            guard let first = match.mediaItems.first else {
                self.submitNextSignature(request)
                return
            }
            var audioModel = first.convertAudioModel()
            if audioModel.duration == nil || audioModel.duration! <= 0, let localModel = request.model {
                audioModel.duration = TimeInterval(localModel.durationSeconds)
            }
            guard request.requestsLyrics else {
                self.finish(request, with: .success(audioModel))
                return
            }
            let recognized = audioModel
            // Missing/slow lyrics must never throw away a successful acoustic match.
            self.scheduleTimeout(for: request, seconds: 18) { [weak self] request in
                self?.finish(request, with: .success(recognized))
            }
            self.fetchLRCLyricArray(audioModel: recognized, model: request.model) { [weak self] result in
                guard let self, self.isActive(request) else { return }
                var final = recognized
                if case .success(let lyrics) = result { final.lyrics = lyrics }
                self.finish(request, with: .success(final))
            }
        }
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let request = self.requests.values.first(where: { $0.session === session }),
                  self.isActive(request) else { return }
            self.submitNextSignature(request)
        }
    }
}

extension AudioFingerprintMatcher {
    /// Candidates must identify the same recording before synchronized text receives a small
    /// preference. A different song's timed lyrics must not outrank this song's plain lyrics.
    func fetchLRCLyricArray(audioModel: AudioFingerprintModel, model: MusicItemModel?,
                           completion: @escaping (Result<[LyricInfoModel], KakaError>) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.fetchLRCLyricArray(audioModel: audioModel, model: model, completion: completion)
            }
            return
        }
        var completed = false
        var timeout: DispatchWorkItem?
        let finish: (Result<[LyricInfoModel], KakaError>) -> Void = { result in
            guard !completed else { return }
            completed = true
            timeout?.cancel()
            timeout = nil
            completion(result)
        }
        let deadline = DispatchWorkItem { finish(.failure(.emptyData)) }
        timeout = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 18, execute: deadline)
        var target = audioModel
        if Self.normalized(target.title).isEmpty { target.title = model?.title }
        if Self.normalized(target.artist).isEmpty { target.artist = model?.artist }
        if target.duration == nil || target.duration! <= 0, let localModel = model {
            target.duration = TimeInterval(localModel.durationSeconds)
        }
        let resolved = target
        requestFingerLRCLyricLib(audioModel: resolved) { result in
            switch result {
            case .failure(let error): finish(.failure(error))
            case .success(let candidates):
                var seen = Set<String>()
                let ranked = candidates.enumerated().compactMap { index, candidate -> (Int, Int, LRCLibLyricModel)? in
                    guard let score = Self.lyricMatchScore(candidate, target: resolved) else { return nil }
                    let key = "\(candidate.id)|\(candidate.name)|\(candidate.artistName)|\(candidate.syncedLyrics ?? candidate.plainLyrics ?? "")"
                    guard seen.insert(key).inserted else { return nil }
                    return (score, index, candidate)
                }.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 > $1.0 }
                let lyrics = ranked.compactMap { entry -> LyricInfoModel? in
                    var candidate = entry.2
                    // Some responses contain an empty syncedLyrics string alongside usable plainLyrics.
                    if candidate.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                        candidate.syncedLyrics = nil
                    }
                    return candidate.convertLyricModel()
                }
                finish(lyrics.isEmpty ? .failure(.emptyData) : .success(lyrics))
            }
        }
    }

    func requestEmbedLRCLyricLib(model: MusicItemModel?, completion: @escaping (Result<[LRCLibLyricModel], KakaError>) -> Void) {
        guard let model else { completion(.failure(.emptyData)); return }
        var target = AudioFingerprintModel()
        target.title = model.title
        target.artist = model.artist
        target.album = model.album
        target.duration = TimeInterval(model.durationSeconds)
        requestFingerLRCLyricLib(audioModel: target, completion: completion)
    }

    func requestFingerLRCLyricLib(audioModel: AudioFingerprintModel,
                                 completion: @escaping (Result<[LRCLibLyricModel], KakaError>) -> Void) {
        guard !Self.normalized(audioModel.title).isEmpty,
              !Self.normalized(audioModel.artist).isEmpty else { completion(.failure(.emptyData)); return }
        var parameters: Parameters = ["track_name": audioModel.title ?? "", "artist_name": audioModel.artist ?? ""]
        if let album = audioModel.album, !album.isEmpty { parameters["album_name"] = album }
        if let duration = audioModel.duration, duration.isFinite, duration >= 1, duration <= 3600 {
            parameters["duration"] = duration
        }
        Self.lyricsRequest("get", parameters: parameters).responseData { [weak self] response in
            guard let self else { return }
            switch response.result {
            case .failure(let error): completion(.failure(.custom(error.localizedDescription)))
            case .success(let data):
                if response.response?.statusCode == 200,
                   let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidate = LRCLibLyricModel.deserialize(from: dictionary),
                   Self.lyricMatchScore(candidate, target: audioModel) != nil {
                    completion(.success([candidate]))
                } else if response.response?.statusCode == 404 || response.response?.statusCode == 200 {
                    // Do not turn rate limiting or server failures into additional requests.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                        self?.performBlurrySearch(audioModel: audioModel, completion: completion)
                    }
                } else {
                    completion(.failure(.emptyData))
                }
            }
        }
    }

    private static func lyricsRequest(_ endpoint: String, parameters: Parameters) -> DataRequest {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1"
        return AF.request("https://lrclib.net/api/\(endpoint)", method: .get, parameters: parameters,
                          headers: ["User-Agent": "Wakemusic/\(version) (https://passlockapp.com)"])
            { request in request.timeoutInterval = 8 }
    }

    private func performBlurrySearch(audioModel: AudioFingerprintModel,
                                     completion: @escaping (Result<[LRCLibLyricModel], KakaError>) -> Void) {
        // Structured search avoids a word from the artist accidentally matching only an album name.
        let parameters: Parameters = ["track_name": audioModel.title ?? "", "artist_name": audioModel.artist ?? ""]
        Self.lyricsRequest("search", parameters: parameters).responseData { response in
            switch response.result {
            case .failure(let error): completion(.failure(.custom(error.localizedDescription)))
            case .success(let data):
                guard response.response?.statusCode == 200,
                      let dictionaries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let candidates = [LRCLibLyricModel].deserialize(from: dictionaries) else {
                    completion(.failure(.emptyData))
                    return
                }
                let matches = candidates.filter { Self.lyricMatchScore($0, target: audioModel) != nil }
                completion(matches.isEmpty ? .failure(.emptyData) : .success(matches))
            }
        }
    }

    private static func normalized(_ value: String?) -> String {
        (value ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                              locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    private static func lyricMatchScore(_ candidate: LRCLibLyricModel, target: AudioFingerprintModel) -> Int? {
        let title = normalized(target.title)
        let candidateTitle = normalized(candidate.trackName.isEmpty ? candidate.name : candidate.trackName)
        let artist = normalized(target.artist)
        guard !title.isEmpty, title == candidateTitle, !artist.isEmpty,
              artist == normalized(candidate.artistName) else { return nil }
        let synchronized = candidate.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let plain = candidate.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !synchronized.isEmpty || !plain.isEmpty else { return nil }
        var score = 1000
        if let expected = target.duration, expected.isFinite, expected > 0,
           let actual = candidate.duration, actual.isFinite, actual > 0 {
            let difference = abs(expected - actual)
            // Synchronization is recording-specific. Prefer no automatic lyric over a different edit.
            guard difference <= (synchronized.isEmpty ? 8 : 3) else { return nil }
            score += difference <= 2 ? 30 : 0
        }
        if !synchronized.isEmpty { score += 10 }
        if !normalized(target.album).isEmpty, normalized(target.album) == normalized(candidate.albumName) { score += 5 }
        return score
    }
}
