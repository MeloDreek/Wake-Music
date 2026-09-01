//
//  MusicTagEditorOperation.swift
//  Waketag
//
//  Created by kaka on 2026/6/24.
//

import KakaFoundation
import AppGroupKit
import KakaTaglibKit
import Kingfisher

/// 单个音乐文件处理的独立任务
final class MusicTagEditorOperation: AsynchronousOperation, @unchecked Sendable {
        
    private let model: MusicItemModel
    private let config: AutoEditConfig
    private let completionHandler: EmbeddedTagBlock

    private var audioMatcher: AudioFingerprintMatcher = {
        return AudioFingerprintMatcher()
    }()
    
    init(model: MusicItemModel, config: AutoEditConfig, onCompleted: @escaping EmbeddedTagBlock) {
        self.model = model
        self.config = config
        self.completionHandler = onCompleted
        super.init()
    }
    
    override func main() {
        // 检查是否在排队期间被取消了
        guard !self.isCancelled else {
            self.completionHandler(self.model, nil)
            self.finish()
            return
        }
        
        // 1. 开始音频指纹匹配
        var isRequestLyrics = self.config.fillMode == .forceOverwrite
        let isForcedFill = self.config.fillMode == .forceOverwrite

        if !isForcedFill {
            // 仅填充空白，无论是否有内嵌歌词
            let metaData = TaglibMetadataParser.readMetadata(withFileURL: self.model.mediaPlayURL, read: .all)
            if let lyrics = metaData?.lyricModel?.lyrics, lyrics.count > 0 {
                isRequestLyrics = false
            } else {
                isRequestLyrics = true
            }
        }
        
        self.audioMatcher.matchLocalAudio(model: model, isRequestLyrics: isRequestLyrics) { [weak self] result in
            guard let self = self else { return }
            
            if self.isCancelled {
                self.completionHandler(self.model, nil)
                self.finish()
                return
            }
            
            switch result {
            case .success(let tagsModel):
                // 2. 匹配成功，开启 Task 桥接 async/await 方法
                Task { [weak self] in
                    guard let self = self else { return }
                    
                    let (newModel, errorTags) = await self.embeddedAllMetadata(
                        model: self.model,
                        tagsModel: tagsModel,
                        config: self.config
                    )
                    
                    self.completionHandler(newModel, errorTags)
                    self.finish()
                }
                break
            case .failure(let failure):
                debugPrint("⚠️ 歌曲 [\(self.model.showTitleName())] 标签匹配失败: \(failure.errorDescription)")
                
                var newModel = self.model

                // 1️⃣ 强行写入歌词
                if !self.model.isHaveLyric() && self.config.isSetInstrumental {
                    // 无内嵌歌词 && 也没有匹配歌词时走默认
                    let lyricStr = "[00:00.000]" + "Instrumental · Enjoy the music".localStr()
                    let lyricModel = TaglibMetadataParser.parseSynchronizedLyrics(lyricStr).convertSwiftModel()
                    if TaglibMetadataParser.setLyris(lyricStr, toFileURL: newModel.mediaPlayURL) {
                        newModel.lyricModel = lyricModel
                    }else{
                        debugPrint("❌强行设置歌词错误：\(self.model.showTitleName())")
                    }
                }
                
                // 9️⃣ 强行写入注释
                let comment = "Powered by Wakemusic".localStr()
                if TaglibMetadataParser.setComment(comment, toFileURL: newModel.mediaPlayURL) {
                    newModel.comment = comment
                }
                
                self.completionHandler(newModel, nil)
                self.finish()
                break
            }
        }
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
        let comment = "Powered by Wakemusic".localStr()
        if TaglibMetadataParser.setComment(comment, toFileURL: fileURL) {
            newModel.comment = comment
        }
        
        // 🔟 重命名文件
        let updatedModel = await modifyFileName(model: newModel, config: config)
        
        return (updatedModel, errorTags.isEmpty ? nil : errorTags)
    }
    
    // 根据用户配置，修改文件名称
    func modifyFileName(model: MusicItemModel, config: AutoEditConfig) async -> MusicItemModel {
        guard config.fileName != .default else { return model }
        
        let oldFileURL = model.mediaPlayURL
        let fileExtension = oldFileURL.pathExtension
        let originalNameWithoutExtension = oldFileURL.deletingPathExtension().lastPathComponent
        let directoryURL = oldFileURL.deletingLastPathComponent()
        
        let cleanTitle = model.title?.trimmingCharacters(in: .whitespacesAndNewlines).standardFileName
        let cleanArtist = model.artist?.trimmingCharacters(in: .whitespacesAndNewlines).standardFileName
        
        let hasTitle = !(cleanTitle?.isEmpty ?? true)
        let hasArtist = !(cleanArtist?.isEmpty ?? true)
        
        if !hasTitle && !hasArtist {
            return model
        }
        
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
        
        if newFileNameWithoutExt == originalNameWithoutExtension {
            return model
        }
        
        let baseTargetURL = directoryURL
            .appendingPathComponent(newFileNameWithoutExt)
            .appendingPathExtension(fileExtension)
        
        var targetFileURL = baseTargetURL
        
        var counter = 1
        while FileManager.default.fileExists(atPath: targetFileURL.path) {
            if targetFileURL == oldFileURL {
                break
            }
            
            let uniqueName = "\(newFileNameWithoutExt) (\(counter))"
            targetFileURL = directoryURL
                .appendingPathComponent(uniqueName)
                .appendingPathExtension(fileExtension)
            counter += 1
        }
            
        do {
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


/// 经典的自定义异步 Operation 基类
class AsynchronousOperation: Operation, @unchecked Sendable {
    private let stateQueue = DispatchQueue(label: "com.musictag.operation.state", attributes: .concurrent)
    
    private var _isExecuting: Bool = false
    override var isExecuting: Bool {
        get { stateQueue.sync { _isExecuting } }
        set {
            willChangeValue(forKey: "isExecuting")
            stateQueue.async(flags: .barrier) { self._isExecuting = newValue }
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    private var _isFinished: Bool = false
    override var isFinished: Bool {
        get { stateQueue.sync { _isFinished } }
        set {
            willChangeValue(forKey: "isFinished")
            stateQueue.async(flags: .barrier) { self._isFinished = newValue }
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override var isAsynchronous: Bool { true }
    
    override func start() {
        if isCancelled {
            isFinished = true
            return
        }
        isExecuting = true
        main()
    }
    
    /// 子类重写 main 方法，并在异步任务彻底结束时手动调用 finish()
    override func main() {
        fatalError("子类必须重写 main() 且不要调用 super")
    }
    
    func finish() {
        isExecuting = false
        isFinished = true
    }
}
