//
//  MusicViewModel+Music.swift
//  Mobie
//
//  Created by 张文 on 10/19/24.
//

import KakaFoundation
import AppGroupKit
import KakaTaglibKit

extension MusicViewModel {
    /// 获取所有音乐数据
    func refreshMusicDataAction(completion: (([MusicItemModel])->Void)? = nil, fail: ((String?)->Void)? = nil) {
        let currentTime = Date()

        if let lastTime = self.lastMusicRefreshTime, currentTime.timeIntervalSince(lastTime) < 2 {
            fail?(nil)
            return
        }

        self.lastMusicRefreshTime = currentTime
        debugPrint("### MusicViewModel.refreshMusicDataAction ###")
        
        let cacheArray = self.isBaseDoc ? AppLocalManager.shared.refreshCachePaths() : []
        let tempURLArray = cacheArray + SandboxFileManager.shared.getAllSubFiles(self.baseFileURL)
        
        if !self.isBaseDoc {
            // 子文件夹
            self.handleAudioURLs(handleType: .link, sourceType: .localFile, targetFolderURL: self.baseFileURL, musicURLs: tempURLArray) { result in
                
            } completion: { models in
                let sortedMusic = self.sortHomeMusics(models)
                var tempSortArray = [MusicItemModel]()

                for title in self.musicIndexArray {
                    if let items = sortedMusic[title], title != "♥" {
                        tempSortArray.append(contentsOf: items)
                    }
                }
                
                self.allMusicArray = tempSortArray
                
                DispatchQueue.main.async {
                    completion?(tempSortArray)
                }
            }

            return
        }
        
        
        // 用于存储所有已处理的音乐模型
        var modelArray = [MusicItemModel]()

        // 创建一个串行队列来确保对 modelArray 的访问是线程安全的
        let modelArrayQueue = DispatchQueue(label: "com.musicApp.modelArrayQueue")

        // 创建一个调度组，用于同步任务完成
        let dispatchGroup = DispatchGroup()

        for fileURL in tempURLArray {
            // 进入调度组
            dispatchGroup.enter()

            // 使用并发队列来执行每个文件的元数据解析任务
            let operationQueue = DispatchQueue(label: "com.musicApp.operationQueue", attributes: .concurrent)

            operationQueue.async {
                
                if fileURL.hasDirectoryPath {
                    // 不写入文件夹
                    dispatchGroup.leave()
                    return
                }
                
                if fileURL.isLRCFile() {
                    SandboxFileManager.shared.saveLrcFileToDocument(lrcPath: fileURL, handleType: .move)
                    dispatchGroup.leave()
                    return
                }
                
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
                
                let musicModel = fileURL.createMusicModel(handleType: .link, sourceType: .localFile, targetURL: self.baseFileURL, metadata: metaData)
                
                if FileManager.default.fileExists(atPath: musicModel.coverThumbnailURL().path) {
                    // 使用串行队列来保证对 modelArray 的线程安全
                    modelArrayQueue.async {
                        modelArray.append(musicModel)
                        dispatchGroup.leave()
                    }
                } else {
                    SandboxFileManager.shared.writeMusicthumbnailImage(model: musicModel, image: metaData?.coverArt) { imageURL in
                        // 使用串行队列来保证对 modelArray 的线程安全
                        modelArrayQueue.async {
                            modelArray.append(musicModel)
                            dispatchGroup.leave()
                        }
                    } fail: { error in
                        // 使用串行队列来保证对 modelArray 的线程安全
                        modelArrayQueue.async {
                            modelArray.append(musicModel)
                            dispatchGroup.leave()
                        }
                    }
                }

            }
        }

        self.parserManager.addOperation {
            dispatchGroup.wait() // 等待所有任务完成
        }

        // 所有任务完成后调用 completion
        dispatchGroup.notify(queue: .global(qos: .default)) { () in
            
            let sortedMusic = self.sortHomeMusics(modelArray)
            var tempSortArray = [MusicItemModel]()

            for title in self.musicIndexArray {
                if let items = sortedMusic[title], title != "♥" {
                    tempSortArray.append(contentsOf: items)
                }
            }
            
            self.allMusicArray = tempSortArray
            
            DispatchQueue.main.async {
                completion?(modelArray)
            }
        }
    }
    
    // 整理/排序首页数据源
    public func sortHomeMusics(_ allArray: [MusicItemModel]) -> [String: [MusicItemModel]] {
        var groupedDictionary = [String: [MusicItemModel]]()
        self.musicIndexArray.removeAll()
        
        var tempAllArray = allArray.filter { $0.mediaPlayURL.isSupportMusicFile(false) || $0.isFolder() }
        tempAllArray = Array(Set(tempAllArray))
        
        if self.groupType == .nonGroup || self.searchKey != nil {
            // 1️⃣ 不分组<包括搜索>
            let starArray = tempAllArray.filter { $0.isFlagFavorite() && !$0.isFolder() }
            if (starArray.count > 0) {
                self.musicIndexArray.append("♥")
                groupedDictionary["♥"] = Array(Set(starArray)).sorted(by: { element1, element2 in
                    return element1.sortAnotherModel(model2: element2, sortType: self.sortType)
                })
            }
            
            self.musicIndexArray.append("#")
            groupedDictionary["#"] = tempAllArray.sorted(by: { element1, element2 in
                return element1.sortAnotherModel(model2: element2, sortType: self.sortType)
            })

            self.musicDictionary = groupedDictionary
            return groupedDictionary
        }else{
            // 2️⃣ 有分组
            
            if self.groupType == .musictagGroup {
                let sectionTitles = UILocalizedIndexedCollation.current().sectionTitles
                groupedDictionary = Dictionary(grouping: tempAllArray, by: {
                    $0.isFullMusicTag() ? "✅" : "❗️"
                })
                
                for (key, value) in groupedDictionary {
                    // 内部组的排序
                    groupedDictionary[key] = value.sorted(by: { element1, element2 in
                        return element1.sortAnotherModel(model2: element2, sortType: self.sortType)
                    })
                }
                            
                // 分组内部按照文件大小排序
                let sortedDictory = groupedDictionary.sorted { element1, element2 in
                    guard let index1 = sectionTitles.firstIndex(of: element1.key), let index2 = sectionTitles.firstIndex(of: element2.key) else {
                        return false
                    }
                    
                    return index1 < index2
                }
                
                var indexArr = sortedDictory.map(\.key).sorted { $0 > $1 }
                
                // 处理已收藏的音乐
                let starArray = tempAllArray.filter { $0.isFlagFavorite() }
                if (starArray.count > 0) {
                    indexArr.insert("♥", at: 0)
                    groupedDictionary["♥"] = Array(Set(starArray)).sorted(by: {element1, element2 in
                        return element1.sortAnotherModel(model2: element2, sortType: self.sortType)
                    })
                }
                
                self.musicIndexArray = indexArr
                self.musicDictionary = groupedDictionary
                return groupedDictionary
                
            }else{
                let sectionTitles = UILocalizedIndexedCollation.current().sectionTitles

                groupedDictionary = Dictionary(grouping: tempAllArray, by: { $0.firstChar(self.groupType)
                })
                
                for (key, value) in groupedDictionary {
                    // 内部组的排序
                    groupedDictionary[key] = value.sorted(by: { element1, element2 in
                        return element1.sortAnotherModel(model2: element2, sortType: self.sortType)
                    })
                }
                            
                // 分组内部按照文件大小排序
                let sortedDictory = groupedDictionary.sorted { element1, element2 in
                    guard let index1 = sectionTitles.firstIndex(of: element1.key), let index2 = sectionTitles.firstIndex(of: element2.key) else {
                        return false
                    }
                    
                    return index1 < index2
                }
                
                var indexArr = sortedDictory.map(\.key).sorted { $0 < $1 }
                
                // 处理已收藏的音乐
                let starArray = tempAllArray.filter { $0.isFlagFavorite() }
                if (starArray.count > 0) {
                    indexArr.insert("♥", at: 0)
                    groupedDictionary["♥"] = Array(Set(starArray)).sorted(by: {element1, element2 in
                        return element1.sortAnotherModel(model2: element2, sortType: self.sortType)
                    })
                }
                
                self.musicIndexArray = indexArr
                self.musicDictionary = groupedDictionary
                return groupedDictionary
            }
        }
        
    }
    
    // 正在播放中的音乐所在的索引
    func playingMusicIndex(_ model: MusicItemModel) -> Int {
        let index = self.allMusicArray.firstIndex {
            $0 == model
        }
        
        return index ?? 0
    }
    
    // 根据音乐模型查找对应的索引
    func findMusicIndexPath(_ model: MusicItemModel) -> IndexPath? {
        // 遍历 musicIndexArray 来获取有序的 section key
        for (sectionIndex, sectionKey) in musicIndexArray.enumerated() {
            // 从 musicDictionary 获取该 section 对应的数组
            if let items = musicDictionary[sectionKey] {
                // 在该数组中查找 recordID 匹配的对象
                if let rowIndex = items.firstIndex(where: { $0 == model }) {
                    // 找到后返回 IndexPath，其中 section 对应的是 musicIndexArray 中的索引，row 是数组中的索引
                    return IndexPath(row: rowIndex, section: sectionIndex)
                }
            }
        }
        // 如果未找到，返回 nil
        return nil
    }
    
    // 提取首页音乐数组
    public func homeSectionArray(_ index: Int) -> [MusicItemModel] {
        if self.musicIndexArray.count <= index { return [] }
        
        let key = self.musicIndexArray[index]
        let dataArr = self.musicDictionary[key] ?? []
        return dataArr
    }
    
    /// 首页音乐的索引
    public var musicIndexArray: [String] {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &MusicKeys.kMusicIndexKey) as? [String] else {
                let initArr = [String]()
                
                objc_setAssociatedObject(self, &MusicKeys.kMusicIndexKey, initArr, .OBJC_ASSOCIATION_COPY_NONATOMIC)
                return initArr
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &MusicKeys.kMusicIndexKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    
    /// 首页索引—>排序后的音乐
    private var musicDictionary: [String: [MusicItemModel]] {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &MusicKeys.kMusicDictKey) as? [String: [MusicItemModel]] else {
                let initArr = [String: [MusicItemModel]]()
                
                objc_setAssociatedObject(self, &MusicKeys.kMusicDictKey, initArr, .OBJC_ASSOCIATION_COPY_NONATOMIC)
                return initArr
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &MusicKeys.kMusicDictKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    
    /// 所有已排序后的音乐路径
    public var allMusicArray: [MusicItemModel] {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &MusicKeys.kAllMusicKey) as? [MusicItemModel] else {
                let initArr = [MusicItemModel]()
                
                objc_setAssociatedObject(self, &MusicKeys.kAllMusicKey, initArr, .OBJC_ASSOCIATION_COPY_NONATOMIC)
                return initArr
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &MusicKeys.kAllMusicKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    
    /// 上次刷新的时间
    public var lastMusicRefreshTime: Date? {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &MusicKeys.kLastTimeKey) as? Date else {
                return nil
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &MusicKeys.kLastTimeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// 多线程管理器
    public var parserManager: OperationQueue {
        get {
            guard let queue = objc_getAssociatedObject(self, &MusicKeys.kTaskKey) as? OperationQueue else {
                let cpuCount = ProcessInfo.processInfo.activeProcessorCount
                let manager = OperationQueue()
                manager.name = "com.parser.operationQueue"
                manager.qualityOfService = .userInteractive
                
                let cpuCoreCount = ProcessInfo.processInfo.activeProcessorCount
                manager.maxConcurrentOperationCount = max(2, min(cpuCoreCount / 2, 6))
                
                objc_setAssociatedObject(self, &MusicKeys.kTaskKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return manager
            }
            
            return queue
        }
        set {
            objc_setAssociatedObject(self, &MusicKeys.kTaskKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private struct MusicKeys {
        static var kTaskKey: Void?
        static var kMusicIndexKey: Void?
        static var kMusicDictKey: Void?
        static var kAllMusicKey: Void?
        static var kLastTimeKey: Void?
    }
    
}

