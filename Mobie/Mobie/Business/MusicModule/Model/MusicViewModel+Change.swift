//
//  MusicViewModel+Change.swift
//  Mobie
//
//  Created by 张文 on 12/27/24.
//

import KakaFoundation
import AppGroupKit
import KakaTaglibKit

extension MusicViewModel {

    
    /// 新增了文件
    func addNewMusics(newUrls: [URL], completion: (([MusicItemModel])->Void)? = nil) {
        
        var newArray = [MusicItemModel]()
        let dispatchGroup = DispatchGroup()
        
        // 使用串行队列来确保对 newArray 的线程安全访问
        let arrayQueue = DispatchQueue(label: "com.musicApp.newArrayQueue")
        
        for fileURL in newUrls {
            dispatchGroup.enter()
            
            let operation = BlockOperation {
                autoreleasepool {
                    if !fileURL.isSupportMusicFile(true) || fileURL.hasDirectoryPath {
                        // 不支持的文件格式，不写入
                        dispatchGroup.leave()
                        return
                    }

                    if fileURL.isLRCFile() {
                        SandboxFileManager.shared.saveLrcFileToDocument(lrcPath: fileURL, handleType: .move)
                        dispatchGroup.leave()
                        return
                    }

                    let metaData = MusicParseOperation.readMetadata(fileURL: fileURL, sourceType: .localFile,
                                                                   reuseCachedArtwork: true)
                    let musicModel = fileURL.createMusicModel(handleType: .link, sourceType: .localFile,
                                                             targetURL: self.baseFileURL, metadata: metaData)

                    if !MusicParseOperation.hasCurrentCachedArtwork(model: musicModel) {
                        SandboxFileManager.shared.writeMusicthumbnailImage(model: musicModel, image: metaData?.coverArt)
                    }
                    arrayQueue.async {
                        newArray.append(musicModel)
                        dispatchGroup.leave()
                    }
                }
            }
            
            self.parserManager.addOperation(operation)
        }
        
        dispatchGroup.notify(queue: .main) {
            
            debugPrint("🏠处理新增文件 = \(newArray.map({ $0.mediaPlayURL.lastPathComponent }))")
            
            // 使用串行队列来保证对 allMusicArray 的线程安全访问
            DispatchQueue.main.async {
                let modelArray = self.allMusicArray + newArray
                let sortedMusic = self.sortHomeMusics(modelArray)
                var tempSortArray = [MusicItemModel]()
                
                for title in self.musicIndexArray {
                    if let items = sortedMusic[title] {
                        tempSortArray.append(contentsOf: items)
                    }
                }
                
                self.allMusicArray = Array(Set(tempSortArray))
                
                completion?(modelArray)
            }
        }
    }


    
    /// 文件减少了
    func deleteMusics(newUrls: [URL], completion: (([MusicItemModel])->Void)? = nil) {
        
        // 所有音乐的本地路径
        var tempModelArray = self.allMusicArray

        // 遍历所有 URL，从后向前删除与 newUrls 匹配的元素
        for index in (0..<tempModelArray.count).reversed() {
            let subURL = tempModelArray[index].mediaPlayURL
            if newUrls.contains(where: { $0 == subURL }) {
                tempModelArray.remove(at: index)
            }
        }
        
        debugPrint("处理减少的文件")
        
        // 对剩余的音乐进行排序
        let sortedMusic = self.sortHomeMusics(tempModelArray)
        var tempSortArray = [MusicItemModel]()

        // 根据索引数组重新排列音乐
        for title in self.musicIndexArray {
            if let items = sortedMusic[title] {
                tempSortArray.append(contentsOf: items)
            }
        }
        
        // 更新 allMusicArray
        self.allMusicArray = tempSortArray
        
        // 异步回调
        DispatchQueue.main.async {
            completion?(self.allMusicArray)
        }
    }
    
}
