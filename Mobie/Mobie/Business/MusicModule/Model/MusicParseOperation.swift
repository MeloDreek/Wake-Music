//
//  FileTaskOperation.swift
//  Mobie
//
//  Created by 张文 on 10/2/24.
//

import KakaFoundation
import AppGroupKit
import KakaTaglibKit

final class MusicParseOperation: Operation, @unchecked Sendable {
    
    // 文件路径
    private let fileURL: URL
    
    // 目标文件夹
    private let targetFolderURL: URL
    
    // 操作方式
    private let handleType: FileHandleType
    
    /// 文件來源
    private let sourceType: ImportFileType
    
    // 回调
    private var completionHandler: ((Result<MusicItemModel, KakaError>) -> Void)?
    
    // 初始化
    init(fileURL: URL, sourceType: ImportFileType, targetFolderURL: URL = SandboxFileManager.shared.basePublicFileURL(), handleType: FileHandleType, completion: @escaping (Result<MusicItemModel, KakaError>) -> Void) {
        self.fileURL = fileURL
        self.sourceType = sourceType
        self.targetFolderURL = targetFolderURL
        self.handleType = handleType
        self.completionHandler = completion
        super.init()
    }
        
    // 重写 main 方法，实现任务逻辑
    override func main() {
        autoreleasepool {
            self.processFile()
        }
    }

    private func processFile() {
        // 检查操作是否已取消
        if self.isCancelled {
            self.completionHandler?(.failure(.custom("Canceled!")))
            return
        }
        
        // 处理歌词文件
        if self.fileURL.isLRCFile() {
            SandboxFileManager.shared.saveLrcFileToDocument(lrcPath: self.fileURL, handleType: .copy) { [weak self] vURL in
                guard let wSelf = self else { return }
                var model = MusicItemModel(fileURL: wSelf.fileURL, sourceType: wSelf.sourceType)
                model.handleType = wSelf.handleType
                
                wSelf.completionHandler?(.success(model))
                wSelf.cancel()
            }
            return
        }
        
        // Keep artwork scoped to this operation, never in MusicItemModel or a
        // main-queue completion. Imported files get a different cache identity.
        let metadata = Self.readMetadata(fileURL: self.fileURL, sourceType: self.sourceType,
                                         reuseCachedArtwork: self.handleType == .link)
        let model = self.fileURL.createMusicModel(handleType: self.handleType, sourceType: self.sourceType,
                                                 targetURL: self.targetFolderURL, metadata: metadata)

        switch self.handleType {
        case .copy, .move:
            // saveMusicToDocument completes synchronously with the final URL.
            // Only then may we derive the destination artwork cache key.
            SandboxFileManager.shared.saveMusicToDocument(sourceURL: self.fileURL, targetFolderURL: self.targetFolderURL,
                                                          model: model) { newModel in
                self.finish(model: newModel, metadata: metadata)
            }
        case .link:
            self.finish(model: model, metadata: metadata)
        }
    }

    private func finish(model: MusicItemModel, metadata: MetadataTagModel?) {
        if !model.isFolder(), !Self.hasCurrentCachedArtwork(model: model) {
            // The disk write is synchronous. A missing/invalid cover must not
            // prevent importing an otherwise playable audio file.
            SandboxFileManager.shared.writeMusicthumbnailImage(model: model, image: metadata?.coverArt)
        }
        self.completionHandler?(.success(model))
        self.completionHandler = nil
    }

    /// Cached covers are already on disk: refresh textual tags and lyrics
    /// without decoding the embedded image again for every library refresh.
    static func readMetadata(fileURL: URL, sourceType: ImportFileType,
                             reuseCachedArtwork: Bool) -> MetadataTagModel? {
        guard !fileURL.hasDirectoryPath else { return nil }
        let model = MusicItemModel(fileURL: fileURL, sourceType: sourceType)
        let hasCachedArtwork = reuseCachedArtwork && Self.hasCurrentCachedArtwork(model: model)
        let readType: TaglibReaderType = hasCachedArtwork ? .basicLyrics : .all
        let accessedResource = !FileManager.default.isReadableFile(atPath: fileURL.path) &&
            fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessedResource { fileURL.stopAccessingSecurityScopedResource() }
        }
        return TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: readType)
    }

    /// An external editor may change artwork while keeping the same filename.
    /// Missing source attributes must not make a stale thumbnail authoritative.
    static func hasCurrentCachedArtwork(model: MusicItemModel) -> Bool {
        let cachedURL = model.localArtworkCacheURL()
        guard FileManager.default.isReadableFile(atPath: cachedURL.path),
              let cacheValues = try? FileManager.default.attributesOfItem(atPath: cachedURL.path),
              cacheValues[.type] as? FileAttributeType == .typeRegular,
              let cacheSize = cacheValues[.size] as? NSNumber, cacheSize.int64Value > 0,
              let cacheDate = cacheValues[.modificationDate] as? Date,
              // URL.resourceValues can retain an old modification date inside
              // a reused model URL. Read fresh file attributes on each scan.
              let sourceValues = try? FileManager.default.attributesOfItem(atPath: model.mediaPlayURL.path),
              let sourceDate = sourceValues[.modificationDate] as? Date else { return false }
        return cacheDate >= sourceDate
    }
}
