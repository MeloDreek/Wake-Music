//
//  MusicTagEditorOperation.swift
//  Waketag
//

import KakaFoundation
import AppGroupKit
import WaketagLibKit

/// One completion per input, including operations cancelled while still queued.
final class MusicTagEditorOperation: AsynchronousOperation, @unchecked Sendable {
    private let model: MusicItemModel
    private let config: AutoEditConfig
    private let completionHandler: EmbeddedTagBlock
    private let audioMatcher = AudioFingerprintMatcher()
    private let workLock = NSLock()
    private var didComplete = false
    private var embeddingStarted = false
    private var embeddingTask: Task<Void, Never>?
    private var metadataRequest: MetadataMatchRequest?

    init(model: MusicItemModel, config: AutoEditConfig, onCompleted: @escaping EmbeddedTagBlock) {
        self.model = model
        self.config = config
        self.completionHandler = onCompleted
        super.init()
    }

    override func main() {
        guard !isCancelled else {
            complete(model: model, errorTags: nil)
            return
        }
        let disk = TaglibMetadataParser.readMetadata(withFileURL: model.mediaPlayURL, read: .all)
        var matchingModel = disk?.mergeTagLibInfo(model) ?? model
        matchingModel.coverArt = disk?.coverArt
        let requestLyrics = config.fillMode == .forceOverwrite || (disk?.lyricModel?.lyrics?.count ?? 0) == 0
        let request = audioMatcher.matchLocalAudioMetadata(model: matchingModel, isRequestLyrics: requestLyrics) { [weak self] result in
            guard let self else { return }
            guard self.beginEmbedding() else {
                if self.isCancelled { self.complete(model: self.model, errorTags: nil) }
                return
            }

            let task = Task { [weak self] in
                guard let self else { return }
                let tags: AudioFingerprintModel
                let allowRename: Bool
                switch result {
                case .success(let value):
                    tags = value
                    allowRename = true
                case .failure(let error):
                    debugPrint("Metadata recognition failed: \(error.errorDescription)")
                    // Preserve the user's instrumental option, but the shared
                    // writer must first prove that on-disk lyrics are absent.
                    tags = AudioFingerprintModel()
                    allowRename = false
                }
                let result = await MusicTagEditor.shared.embeddedAllMetadata(
                    model: self.model, tagsModel: tags, config: self.config,
                    allowFileRename: allowRename, isCancelled: { [weak self] in
                        self?.isCancelled ?? true
                    }
                )
                self.complete(model: result.updatedModel, errorTags: result.errorTags)
            }
            self.store(task: task)
        }
        store(request: request)
    }

    override func cancel() {
        super.cancel()
        audioMatcher.cancelLocalMatching()
        workLock.lock()
        let task = embeddingTask
        let request = metadataRequest
        let hasEmbedding = embeddingStarted
        workLock.unlock()
        request?.cancel()
        task?.cancel()
        // Once a write has started, let it finish and return its actual disk
        // state. Before that, cancellation need not wait for any network reply.
        // A cancelled operation may not have been enqueued yet. Let start()
        // deliver that completion instead of marking a new operation finished.
        if !hasEmbedding, isExecuting { complete(model: model, errorTags: nil) }
    }

    override func cancelledBeforeStart() {
        complete(model: model, errorTags: nil)
    }

    private func beginEmbedding() -> Bool {
        workLock.lock()
        defer { workLock.unlock() }
        guard !didComplete, !embeddingStarted, !isCancelled else { return false }
        embeddingStarted = true
        return true
    }

    private func store(task: Task<Void, Never>) {
        workLock.lock()
        let shouldCancel = isCancelled || didComplete
        if !didComplete { embeddingTask = task }
        workLock.unlock()
        if shouldCancel { task.cancel() }
    }

    private func store(request: MetadataMatchRequest) {
        workLock.lock()
        let shouldCancel = isCancelled || didComplete
        if !didComplete { metadataRequest = request }
        workLock.unlock()
        if shouldCancel { request.cancel() }
    }

    private func complete(model: MusicItemModel, errorTags: [MusicTagType]?) {
        workLock.lock()
        guard !didComplete else { workLock.unlock(); return }
        didComplete = true
        embeddingTask = nil
        metadataRequest = nil
        workLock.unlock()
        completionHandler(model, errorTags)
        finish()
    }
}

/// Synchronous state changes keep OperationQueue's KVO observations coherent.
class AsynchronousOperation: Operation, @unchecked Sendable {
    private enum State { case ready, executing, finished }
    private let stateLock = NSRecursiveLock()
    private var state: State = .ready

    override var isExecuting: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return state == .executing
    }
    override var isFinished: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return state == .finished
    }
    override var isAsynchronous: Bool { true }

    override func start() {
        stateLock.lock()
        guard state == .ready else { stateLock.unlock(); return }
        if isCancelled {
            stateLock.unlock()
            cancelledBeforeStart()
            return
        }
        transition(to: .executing)
        stateLock.unlock()
        main()
    }

    override func main() {
        fatalError("Subclasses must implement main() and call finish().")
    }

    func cancelledBeforeStart() { finish() }
    func finish() { transition(to: .finished) }

    private func transition(to next: State) {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard state != .finished, state != next else { return }
        let executingChanged = (state == .executing) != (next == .executing)
        let finishedChanged = next == .finished
        if executingChanged { willChangeValue(forKey: "isExecuting") }
        if finishedChanged { willChangeValue(forKey: "isFinished") }
        state = next
        if finishedChanged { didChangeValue(forKey: "isFinished") }
        if executingChanged { didChangeValue(forKey: "isExecuting") }
    }
}
