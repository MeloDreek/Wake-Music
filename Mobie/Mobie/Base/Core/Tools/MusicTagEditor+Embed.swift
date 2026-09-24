//
//  MusicTagEditor+Embed.swift
//  Waketag
//
//  Created by kaka on 2026/6/24.
//

import KakaFoundation
import WaketagLibKit
import Kingfisher
import AppGroupKit

// 单个文件的处理回调
typealias EmbeddedTagBlock = (_ newModel: MusicItemModel, _ errorTags: [MusicTagType]?) -> ()


extension MusicTagEditor {
    
    /*
     批量编辑的进度回调
     curModel：当前文件
     completed：已完全的数量
     total：总数量
     */
    typealias BatchEmbeddedProgress = (_ curModel: MusicItemModel, _ completed: Int, _ total: Int) -> Void
    
    
    /* 批量编辑的总回调
     completedModels：已经处理过的模型，不是指完整标签的数组，反应进度值
     missingTagModels：缺失标签的模型：isFullMusicTag = false
    */
    typealias BatchEmbeddedCompletion = (_ completedModels: [MusicItemModel], _ missingTagModels: [MusicItemModel]?) -> Void

    /// 批量处理：使用 OperationQueue 彻底重构版（根治卡死与死锁）
    func batchEmbeddedMetadata(models: [MusicItemModel], config: AutoEditConfig, progress: @escaping BatchEmbeddedProgress, completion: @escaping BatchEmbeddedCompletion) {
        
        let totalCount = models.count
        guard totalCount > 0 else {
            completion([], nil)
            return
        }
        
        let dispatchGroup = DispatchGroup()
        let modelUpdateQueue = DispatchQueue(label: "com.musictag.yncmodelUpdate")
        var completedModels: [MusicItemModel] = []
        var missingTagModels: [MusicItemModel] = []
        
        for subModel in models {
            dispatchGroup.enter()
            let operation = MusicTagEditorOperation(model: subModel, config: config) { finalModel, errorTags in
                // Keep batch result arrays lightweight once the persisted cover
                // has a current disk thumbnail (the UI already reads that cache).
                let completedModel: MusicItemModel = {
                    var compact = finalModel
                    if MusicParseOperation.hasCurrentCachedArtwork(model: compact) {
                        compact.coverArt = nil
                    }
                    return compact
                }()
                
                modelUpdateQueue.sync {
                    
                    // ⚠️串行锁内的代码越少越好
                    debugPrint("✅完成的文件 = \(completedModel.mediaPlayURL.lastPathComponent)")
                    
                    if !completedModel.isFullMusicTag() || !(errorTags?.isEmpty ?? true) {
                        missingTagModels.append(completedModel)
                    }
                    completedModels.append(completedModel)
                    
                    let currentCount = completedModels.count
                    DispatchQueue.main.async {
                        progress(completedModel, currentCount, totalCount)
                    }
                }
                
                dispatchGroup.leave()
            }
            
            self.taskManager.addOperation(operation)
        }
        
        dispatchGroup.notify(queue: .main) {
            let finalMissTagModels = missingTagModels.isEmpty ? nil : missingTagModels
            completion(completedModels, finalMissTagModels)
        }
    }
    
    /// 取消批量内嵌队列
    func cancelBatchEmbeddedQueue() {
        self.taskManager.cancelAllOperations()
        debugPrint("🛑 用户触发了批量标签内嵌队列的取消操作")
    }

    
    // Network work may run concurrently; the final disk check and writes may not.
    private static let embeddingQueue = DispatchQueue(label: "com.musictag.embedding.commit")

    private static func onEmbeddingQueue<T>(_ action: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            embeddingQueue.async { continuation.resume(returning: action()) }
        }
    }

    /// Both interactive and batch editing use the same disk-backed decisions.
    @discardableResult
    func embeddedAllMetadata(
        model: MusicItemModel,
        tagsModel: AudioFingerprintModel,
        config: AutoEditConfig,
        allowFileRename: Bool = true,
        isCancelled: @escaping () -> Bool = { false }
    ) async -> (updatedModel: MusicItemModel, errorTags: [MusicTagType]?) {
        let cancellation = MetadataEmbeddingCancellation()
        return await withTaskCancellationHandler(operation: {
            let cancelled = { cancellation.isCancelled || isCancelled() }
            guard !Task.isCancelled, !cancelled() else { return (model, nil) }
            let fileURL = model.mediaPlayURL
            let forceOverwrite = config.fillMode == .forceOverwrite && !tagsModel.isCatalogFallback
            // An unreadable file is not evidence that its tags are absent.
            guard let initial = await Self.onEmbeddingQueue({
                TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all)
            }) else {
                return (model, [.title, .artist, .album, .artWork, .lyrics])
            }

            var downloadedArtwork: UIImage?
            if Self.nonblank(tagsModel.coverArt) != nil,
               forceOverwrite || (initial.coverArtData == nil && initial.coverArt == nil),
               !cancelled() {
                do {
                    downloadedArtwork = try await fetchArtworkImage(coverArt: tagsModel.coverArt!)
                } catch {
                    // Report a cover failure only if the final disk check still needs it.
                }
            }

            let artwork = downloadedArtwork
            let result = await Self.onEmbeddingQueue {
                self.commitMetadata(
                    model: model, tagsModel: tagsModel, config: config,
                    artwork: artwork, allowFileRename: allowFileRename,
                    isCancelled: cancelled
                )
            }
            if result.updatedModel.mediaPlayURL != model.mediaPlayURL {
                await MainActor.run {
                    AppLocalManager.shared.updateMediaURL(oldURL: model.mediaPlayURL,
                                                          newURL: result.updatedModel.mediaPlayURL)
                }
            }
            return result
        }, onCancel: {
            cancellation.cancel()
        })
    }

    private static func nonblank(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    /// No suspension points are allowed between this fresh read and the writes.
    private func commitMetadata(
        model: MusicItemModel,
        tagsModel: AudioFingerprintModel,
        config: AutoEditConfig,
        artwork: UIImage?,
        allowFileRename: Bool,
        isCancelled: () -> Bool
    ) -> (updatedModel: MusicItemModel, errorTags: [MusicTagType]?) {
        let fileURL = model.mediaPlayURL
        guard let disk = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all) else {
            return (model, isCancelled() ? nil : [.title, .artist, .album, .artWork, .lyrics])
        }
        var newModel = disk.mergeTagLibInfo(model)
        newModel.coverArt = disk.coverArt
        var errorTags: [MusicTagType] = []
        let forceOverwrite = config.fillMode == .forceOverwrite && !tagsModel.isCatalogFallback
        var wroteAnyTag = false

        func writeText(_ proposed: String?, existing: String?, tag: MusicTagType,
                       action: (String) -> Bool, update: (String) -> Void) {
            guard !isCancelled(), let value = Self.nonblank(proposed),
                  forceOverwrite || Self.nonblank(existing) == nil else { return }
            if action(value) {
                wroteAnyTag = true
                update(value)
            } else { errorTags.append(tag) }
        }

        if !isCancelled(), Self.nonblank(tagsModel.coverArt) != nil,
           forceOverwrite || (disk.coverArtData == nil && disk.coverArt == nil) {
            if let artwork, TaglibMetadataParser.setCoverArt(artwork, toFileURL: fileURL) {
                wroteAnyTag = true
                newModel.coverArt = artwork
            } else { errorTags.append(.artWork) }
        }
        writeText(tagsModel.title, existing: disk.title, tag: .title,
                  action: { TaglibMetadataParser.setTitle($0, toFileURL: fileURL) },
                  update: { newModel.title = $0 })
        writeText(tagsModel.artist, existing: disk.artist, tag: .artist,
                  action: { TaglibMetadataParser.setArtist($0, toFileURL: fileURL) },
                  update: { newModel.artist = $0 })
        writeText(tagsModel.album, existing: disk.album, tag: .album,
                  action: { TaglibMetadataParser.setAlbum($0, toFileURL: fileURL) },
                  update: { newModel.album = $0 })
        writeText(tagsModel.genres, existing: disk.genre, tag: .genre,
                  action: { TaglibMetadataParser.setGenre($0, toFileURL: fileURL) },
                  update: { newModel.genre = $0 })

        if !isCancelled(), let year = tagsModel.year, year > 0, forceOverwrite || disk.year == 0 {
            if let value = Int32(exactly: year), TaglibMetadataParser.setYear(value, toFileURL: fileURL) {
                wroteAnyTag = true
                newModel.year = year
            } else { errorTags.append(.year) }
        }
        if !isCancelled(), let track = tagsModel.trackNumber, track > 0, forceOverwrite || disk.track == 0 {
            if let value = Int32(exactly: track), TaglibMetadataParser.setTrack(value, toFileURL: fileURL) {
                wroteAnyTag = true
                newModel.track = track
            } else { errorTags.append(.trackNumber) }
        }

        let candidates = tagsModel.lyrics ?? []
        let orderedLyrics = candidates.filter { $0.isSelected } + candidates.filter { !$0.isSelected }
        let lyricText = orderedLyrics.lazy.compactMap { candidate -> String? in
            guard let text = Self.nonblank(candidate.toLyricString()),
                  let parsed = TaglibMetadataParser.parseSynchronizedLyrics(text),
                  parsed.lyrics?.contains(where: { Self.nonblank($0.realLyric) != nil }) == true else { return nil }
            return text
        }.first
        let hasDiskLyrics = (disk.lyricModel?.lyrics?.count ?? 0) > 0
        var proposedLyrics = lyricText
        // Catalog metadata (including artwork-only matches) is not evidence of an instrumental.
        // Even explicit overwrite must not replace existing lyrics with this placeholder.
        if proposedLyrics == nil, config.isSetInstrumental, !hasDiskLyrics, !tagsModel.isCatalogFallback {
            proposedLyrics = "[00:00.000]" + "Instrumental · Enjoy the music".localStr()
        }
        if !isCancelled(), let lyrics = proposedLyrics, forceOverwrite || !hasDiskLyrics {
            if TaglibMetadataParser.setLyrics(lyrics, toFileURL: fileURL) {
                wroteAnyTag = true
                newModel.lyricModel = TaglibMetadataParser.parseSynchronizedLyrics(lyrics)?.convertSwiftModel()
            } else { errorTags.append(.lyrics) }
        }
        // Never write branding or synthetic comments during automatic editing.

        // The returned model and thumbnail describe persisted content, not recognition guesses.
        let persisted = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all)
        if let persisted {
            newModel = persisted.mergeTagLibInfo(newModel)
            newModel.coverArt = persisted.coverArt
        }
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }
        if !isCancelled(), allowFileRename, !tagsModel.isCatalogFallback, persisted != nil {
            newModel = renamedMetadataModel(model: newModel, config: config, isCancelled: isCancelled)
        }
        if let persisted, let image = persisted.coverArt,
           wroteAnyTag || newModel.mediaPlayURL != model.mediaPlayURL ||
               !MusicParseOperation.hasCurrentCachedArtwork(model: newModel) {
            SandboxFileManager.shared.writeMusicthumbnailImage(model: newModel, image: image)
        }
        return (newModel, errorTags.isEmpty ? nil : errorTags)
    }

    // 根据用户配置，修改文件名称
    private func renamedMetadataModel(model: MusicItemModel, config: AutoEditConfig, isCancelled: () -> Bool) -> MusicItemModel {
        guard !isCancelled(), config.fileName != .default else { return model }
        
        let oldFileURL = model.mediaPlayURL
        let fileExtension = oldFileURL.pathExtension
        let originalNameWithoutExtension = oldFileURL.deletingPathExtension().lastPathComponent
        let directoryURL = oldFileURL.deletingLastPathComponent() // 获取原文件所在的文件夹路径
        
        // 1. 清理标题与艺术家的非法字符（/, :, \, ?, 等）
        let cleanTitle = model.title?.trimmingCharacters(in: .whitespacesAndNewlines).standardFileName
        let cleanArtist = model.artist?.trimmingCharacters(in: .whitespacesAndNewlines).standardFileName
        
        let hasTitle = !(cleanTitle?.isEmpty ?? true)
        let hasArtist = !(cleanArtist?.isEmpty ?? true)
        
        if !hasTitle && !hasArtist {
            return model
        }
        
        // 3. 根据配置计算新的文件名（不含后缀）
        var newFileNameWithoutExt = originalNameWithoutExtension
        
        switch config.fileName {
        case .title:
            if hasTitle, let title = cleanTitle {
                newFileNameWithoutExt = title
            }
            
        case .title_artist:
            if hasTitle && hasArtist, let title = cleanTitle, let artist = cleanArtist {
                newFileNameWithoutExt = "\(title) - \(artist)"
            } else if hasTitle, let title = cleanTitle {
                newFileNameWithoutExt = title
            } else if hasArtist, let artist = cleanArtist {
                newFileNameWithoutExt = artist
            }
            
        case .artist_title:
            if hasTitle && hasArtist, let title = cleanTitle, let artist = cleanArtist {
                newFileNameWithoutExt = "\(artist) - \(title)"
            } else if hasTitle, let title = cleanTitle {
                newFileNameWithoutExt = title
            } else if hasArtist, let artist = cleanArtist {
                newFileNameWithoutExt = artist
            }
            
        default:
            break
        }
        
        // 如果文件名没有实质改变，直接返回原 model
        if newFileNameWithoutExt == originalNameWithoutExtension {
            return model
        }
        
        // 3. 构建完整的目标 URL（带路径和后缀）
        let baseTargetURL = directoryURL
            .appendingPathComponent(newFileNameWithoutExt)
            .appendingPathExtension(fileExtension)
        
        var targetFileURL = baseTargetURL
        
        var counter = 1
        while FileManager.default.fileExists(atPath: targetFileURL.path) {
            // 如果就是原文件自己（比如大小写重命名或者没变），无需递增序号
            if targetFileURL == oldFileURL {
                break
            }
            
            let uniqueName = "\(newFileNameWithoutExt) (\(counter))"
            targetFileURL = directoryURL
                .appendingPathComponent(uniqueName)
                .appendingPathExtension(fileExtension)
            counter += 1
        }
            
        // 5. 执行文件重命名操作
        do {
            // 如果文件路径完全没变，直接返回
            if targetFileURL == oldFileURL {
                return model
            }
            
            guard !isCancelled() else { return model }
            try FileManager.default.moveItem(at: oldFileURL, to: targetFileURL)
            
            var newModel = model
            newModel.mediaPlayURL = targetFileURL
            return newModel
            
        } catch {
            debugPrint("❌重命名失败: \(error.localizedDescription)")
            return model
        }
    }
    
    /// 优先从缓存获取封面图片，若无缓存则自动下载
    func fetchArtworkImage(coverArt: String) async throws -> UIImage {
        // 1. 验证 URL 合法性
        try Task.checkCancellation()
        guard let value = Self.nonblank(coverArt), let downloadURL = URL(string: value),
              ["https", "http"].contains(downloadURL.scheme?.lowercased() ?? ""),
              downloadURL.host != nil else {
            throw KakaError.custom("invalid artwork url")
        }
        
        // 2. 先尝试读取本地缓存
        if let cachedValue = try? await ImageCache.default.retrieveImage(forKey: coverArt),
           let cachedImage = cachedValue.image {
            debugPrint("成功获取缓存图片，来源: \(cachedValue.cacheType)")
            try Task.checkCancellation()
            return cachedImage
        }
        
        // 3. 缓存未命中，启动网络下载
        try Task.checkCancellation()
        debugPrint("该图片暂无缓存，开始远程下载...")
        do {
            let downloadResult = try await ImageDownloader.default.downloadImage(with: downloadURL, options: nil)
            try Task.checkCancellation()
            let downloadedImage = downloadResult.image
            debugPrint("远程图片下载成功")
            
            // 4. 写入缓存
            try await ImageCache.default.store(downloadedImage, forKey: coverArt)
            return downloadedImage
        } catch {
            debugPrint("远程图片下载失败: \(error)")
            throw KakaError.custom("download artwork failed")
        }
    }
    
}

extension MusicTagEditor {
    /// 多线程管理器
    private var taskManager: OperationQueue {
        get {
            guard let queue = objc_getAssociatedObject(self, &EmbeddedKey.kQueueKey) as? OperationQueue else {
                let manager = OperationQueue()
                manager.name = "com.musictag.batchOperationQueue"
                manager.qualityOfService = .userInteractive
                manager.maxConcurrentOperationCount = self.maxTaskCount
                
                objc_setAssociatedObject(self, &EmbeddedKey.kQueueKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return manager
            }
            
            return queue
        }
        set {
            objc_setAssociatedObject(self, &EmbeddedKey.kQueueKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// 音频指纹识别器
    private var audioMatcher: AudioFingerprintMatcher {
        get {
            guard let queue = objc_getAssociatedObject(self, &EmbeddedKey.kMatchKey) as? AudioFingerprintMatcher else {
                let manager = AudioFingerprintMatcher()
                
                objc_setAssociatedObject(self, &EmbeddedKey.kMatchKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return manager
            }
            
            return queue
        }
        set {
            objc_setAssociatedObject(self, &EmbeddedKey.kMatchKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // 多线程最大并发数
    var maxTaskCount: Int {
        let cpuCoreCount = ProcessInfo.processInfo.activeProcessorCount
        let maxConcurrentCount = max(2, min(cpuCoreCount / 2, 6))
        return maxConcurrentCount
    }
    
    private struct EmbeddedKey {
        static var kQueueKey: Void?
        static var kMatchKey: Void?
    }
}

/// Cancellation is checked on the commit queue as well as in the awaiting task.
private final class MetadataEmbeddingCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}
