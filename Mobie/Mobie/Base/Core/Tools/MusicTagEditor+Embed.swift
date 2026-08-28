//
//  MusicTagEditor+Embed.swift
//  Waketag
//
//  Created by kaka on 2026/6/24.
//

import KakaFoundation
import KakaTaglibKit
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
                
                var currentCount = 0
                modelUpdateQueue.sync {
                    
                    // ⚠️串行锁内的代码越少越好
                    debugPrint("✅完成的文件 = \(finalModel.mediaPlayURL.lastPathComponent)")
                    
                    if !finalModel.isFullMusicTag() {
                        missingTagModels.append(finalModel)
                    }
                    completedModels.append(finalModel)
                    
                    currentCount = completedModels.count
                }
                
                DispatchQueue.main.async {
                    progress(finalModel, currentCount, totalCount)
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

    
    /// 单个文件：自动填充所有标签
    /// - Parameters:
    ///   - model: 文件模型
    ///   - tagsModel: 元数据信息
    ///   - config: 配置信息
    /// - Returns: 更新后的模型及失败的标签类型
    @discardableResult
    func embeddedAllMetadata(
        model: MusicItemModel,
        tagsModel: AudioFingerprintModel,
        config: AutoEditConfig
    ) async -> (updatedModel: MusicItemModel, errorTags: [MusicTagType]?) {
        
        var newModel = model
        var errorTags = [MusicTagType]()
        let fileURL = model.mediaPlayURL
        let isForcedFill = config.fillMode == .forceOverwrite
        
        // 💡 Helper: 通用字段写入逻辑
        func writeField<T>(
            value: T?,
            hasOldValue: Bool,
            tagType: MusicTagType,
            action: (T) -> Bool,
            updateModel: (T) -> Void
        ) {
            guard let value = value else { return }
            if !isForcedFill && hasOldValue {
                debugPrint("已有旧\(tagType)，且非强刷模式，跳过写入")
                return
            }
            if action(value) {
                updateModel(value)
            } else {
                errorTags.append(tagType)
            }
        }
        
        // 1️⃣ 处理封面
        if let coverArt = tagsModel.coverArt, !coverArt.isEmpty {
            var hasOldCover = model.coverArt != nil
            if !hasOldCover {
                let metaData = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .basicCover)
                hasOldCover = metaData?.coverArt != nil
            }
            
            if !isForcedFill && hasOldCover {
                debugPrint("已有旧封面，且非强刷模式，跳过写入")
            } else {
                // 直接 await 获取
                if let image = try? await fetchArtworkImage(coverArt: coverArt) {
                    if TaglibMetadataParser.setCoverArt(image, toFileURL: fileURL) {
                        newModel.coverArt = image
                    } else {
                        errorTags.append(.artWork)
                    }
                } else {
                    errorTags.append(.artWork)
                }
            }
        }
        
        // 2️⃣ 标题
        writeField(
            value: tagsModel.title,
            hasOldValue: !(model.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
            tagType: .title,
            action: { TaglibMetadataParser.setTitle($0, toFileURL: fileURL) },
            updateModel: { newModel.title = $0 }
        )
        
        // 3️⃣ 艺术家
        writeField(
            value: tagsModel.artist,
            hasOldValue: !(model.artist?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
            tagType: .artist,
            action: { TaglibMetadataParser.setArtist($0, toFileURL: fileURL) },
            updateModel: { newModel.artist = $0 }
        )
        
        // 4️⃣ 专辑
        writeField(
            value: tagsModel.album,
            hasOldValue: !(model.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
            tagType: .album,
            action: { TaglibMetadataParser.setAlbum($0, toFileURL: fileURL) },
            updateModel: { newModel.album = $0 }
        )
        
        // 5️⃣ 年代
        if let year = tagsModel.year, year > 0 {
            writeField(
                value: Int32(year),
                hasOldValue: (model.year ?? 0) > 0,
                tagType: .year,
                action: { TaglibMetadataParser.setYear($0, toFileURL: fileURL) },
                updateModel: { _ in newModel.year = year }
            )
        }
        
        // 6️⃣ 音轨号
        if let trackNumber = tagsModel.trackNumber, trackNumber > 0 {
            writeField(
                value: Int32(trackNumber),
                hasOldValue: (model.track ?? 0) > 0,
                tagType: .trackNumber,
                action: { TaglibMetadataParser.setTrack($0, toFileURL: fileURL) },
                updateModel: { _ in newModel.track = trackNumber }
            )
        }
        
        // 7️⃣ 流派
        writeField(
            value: tagsModel.genres,
            hasOldValue: !(model.genre?.isEmpty ?? true),
            tagType: .genre,
            action: { TaglibMetadataParser.setGenre($0, toFileURL: fileURL) },
            updateModel: { newModel.genre = $0 }
        )
        
        // 8️⃣ 歌词
        if let lyrics = tagsModel.lyrics, !lyrics.isEmpty {
            let lyricModel = lyrics.first(where: { $0.isSelected }) ?? lyrics[0]
            writeField(
                value: lyricModel.toLyricString(),
                hasOldValue: (model.lyricModel?.lyrics?.count ?? 0) > 0,
                tagType: .lyrics,
                action: { TaglibMetadataParser.setLyris($0, toFileURL: fileURL) },
                updateModel: { _ in newModel.lyricModel = lyricModel }
            )
        } else {
            if !model.isHaveLyric() && config.isSetInstrumental {
                // 无内嵌歌词 && 也没有匹配歌词时走默认
                let lyricStr = "[00:00.000]" + "Instrumental · Enjoy the music".localStr()
                let lyricModel = TaglibMetadataParser.parseSynchronizedLyrics(lyricStr).convertSwiftModel()
                if TaglibMetadataParser.setLyris(lyricStr, toFileURL: fileURL) {
                    newModel.lyricModel = lyricModel
                }
            }
        }
        
        // 9️⃣ 注释
        let comment = "Powered by Wake Music".localStr()
        if TaglibMetadataParser.setComment(comment, toFileURL: fileURL) {
            newModel.comment = comment
        }
        
        // 🔟 重命名文件（无缝顺序调用，完美消灭时序隐患）
        let updatedModel = await modifyFileName(model: newModel, config: config)
        
        return (updatedModel, errorTags.isEmpty ? nil : errorTags)
    }
    
    // 根据用户配置，修改文件名称
    func modifyFileName(model: MusicItemModel, config: AutoEditConfig) async -> MusicItemModel {
        guard config.fileName != .default else { return model }
        
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
            
            try FileManager.default.moveItem(at: oldFileURL, to: targetFileURL)
            
            AppLocalManager.shared.updateMediaURL(oldURL: oldFileURL, newURL: targetFileURL)
            
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
        guard !coverArt.isEmpty, let downloadURL = URL(string: coverArt) else {
            throw KakaError.custom("invalid artwork url")
        }
        
        // 2. 先尝试读取本地缓存
        if let cachedValue = try? await ImageCache.default.retrieveImage(forKey: coverArt),
           let cachedImage = cachedValue.image {
            debugPrint("成功获取缓存图片，来源: \(cachedValue.cacheType)")
            return cachedImage
        }
        
        // 3. 缓存未命中，启动网络下载
        debugPrint("该图片暂无缓存，开始远程下载...")
        do {
            let downloadResult = try await ImageDownloader.default.downloadImage(with: downloadURL, options: nil)
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
