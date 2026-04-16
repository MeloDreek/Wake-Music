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
        
        // 解析音乐文件
        self.parseURL(fileURL: self.fileURL) { result1 in
            switch result1 {
            case .success(let model):
                switch self.handleType {
                case .copy, .move:
                    // 1️⃣ 复制或者移动源文件
                    SandboxFileManager.shared.saveMusicToDocument(sourceURL: self.fileURL, targetFolderURL: self.targetFolderURL, model: model) { [weak self] newModel in
                        self?.completionHandler?(.success(newModel))
                        self?.cancel()
                    }
                    break
                case .link:
                    // 2️⃣ 只读取路径，同时更改本地路径的名称
                    self.completionHandler?(.success(model))
                    self.cancel()
                    break
                }
            case .failure(let failure):
                self.completionHandler?(.failure(failure))
                self.cancel()
            }
        }
        
    }
    
    /// 解析文件的元数据，同时写入JSON文件、附件图
    func parseURL(fileURL: URL, completion: @escaping (Result<MusicItemModel, KakaError>) -> Void) {
        
        // 1️⃣ 解析元数据
        let metaData: MetadataTagModel?
                
        if FileManager.default.isReadableFile(atPath: fileURL.path) {
            metaData = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all)
        } else if fileURL.startAccessingSecurityScopedResource() {
            defer {
                fileURL.stopAccessingSecurityScopedResource()
            }
            
            metaData = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all)
            
        } else {
            metaData = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all)
        }
        
        let musicModel = fileURL.createMusicModel(handleType: self.handleType, sourceType: self.sourceType, targetURL: self.targetFolderURL, metadata: metaData)
        
        // 2️⃣ 写入封面
        guard let coverArt = metaData?.coverArt else {
            completion(.success(musicModel))
            return
        }
        
        SandboxFileManager.shared.writeMusicthumbnailImage(model: musicModel, image: coverArt) { vURL in
            completion(.success(musicModel))
        } fail: { error in
            completion(.success(musicModel))
        }
    }
    
}
