//
//  MusicViewModel+Parse.swift
//  Mobie
//
//  Created by 张文 on 9/29/24.
//

import KakaFoundation
import AppGroupKit


/*
 1、直接将音频文件写入All_Assets文件夹，以歌曲名作为文件名，需要判断是否重名
 2、使用VLC解析文件的元数据，将元数据的JSON（歌名、歌手名、专辑名等）写入到All_Music文件夹，并且以歌名为文件名称（歌名.json）
 3、将封面写入到Music_Cover，如果有，并且以歌名为文件名称。从而完成一个文件的写入和解析并回调出MusicItemModel对象，进入下一个循环。
 */
extension MusicViewModel {
    
    /// 批量处理音频文件
    /// - Parameters:
    ///   - handleType: 源文件导入方式：复制、link链接、移动
    ///   - targetFolderURL: 目标路径
    ///   - musicURLs: 音频链接
    ///   - oneBlock: 完成一个到回调
    ///   - completion: 完成所有的解析
    public func handleAudioURLs(handleType: FileHandleType, sourceType: ImportFileType, targetFolderURL: URL = SandboxFileManager.shared.basePublicFileURL(), musicURLs: [URL], oneBlock: @escaping (Result<MusicItemModel, KakaError>) -> Void, completion: (([MusicItemModel])->Void)? = nil) {

        // 用于存储所有已处理的音乐模型
        var musicArray = [MusicItemModel]()
        
        // 创建一个调度组，用于同步任务完成
        let dispatchGroup = DispatchGroup()
        
        for subURL in musicURLs {
            // 进入调度组
            dispatchGroup.enter()
            
            // 添加文件任务
            let operation = MusicParseOperation(fileURL: subURL, sourceType: sourceType, targetFolderURL: targetFolderURL, handleType: handleType) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let model):
                        oneBlock(.success(model))
                        musicArray.append(model)
                    case .failure(let error):
                        oneBlock(.failure(error))
                    }
                    
                    // 离开调度组
                    dispatchGroup.leave()
                }
            }
            
            self.taskManager.addOperation(operation)
        }
        
        // 所有任务完成后调用 completion
        dispatchGroup.notify(queue: .main) { () in
            if handleType == .link {
                let urlArray = musicArray.compactMap { $0.mediaPlayURL }
                SandboxFileManager.shared.addLocalMusicFiles(urlArray)
            }
            completion?(musicArray)
        }
        
    }
    
    /// 多线程管理器
    private var taskManager: OperationQueue {
        get {
            guard let queue = objc_getAssociatedObject(self, &ParseKeys.kTaskKey) as? OperationQueue else {
                let manager = OperationQueue()
                manager.name = "com.audioManager.operationQueue"
                manager.qualityOfService = .userInteractive
                manager.maxConcurrentOperationCount = 1
                
                objc_setAssociatedObject(self, &ParseKeys.kTaskKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return manager
            }
            
            return queue
        }
        set {
            objc_setAssociatedObject(self, &ParseKeys.kTaskKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private struct ParseKeys {
      static var kTaskKey: Void?
    }
}
