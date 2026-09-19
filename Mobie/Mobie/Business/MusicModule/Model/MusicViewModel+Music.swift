//
//  MusicViewModel+Music.swift
//  Mobie
//
//  Created by 张文 on 10/19/24.
//

import KakaFoundation
import AppGroupKit
import KakaTaglibKit

enum MusicKeyTitle: Equatable, Hashable, Comparable {
    case folder
    case likedSongs
    case missingTags
    case completeTags
    case customKey(String)
    
    func keyStr() -> String {
        switch self {
        case .folder: return "📁"
        case .likedSongs: return "♥"
        case .missingTags: return "❗️"
        case .completeTags: return "✅"
        case .customKey(let key): return key
        }
    }
    
    func titleStr() -> String {
        switch self {
        case .folder: return "📁" + "Folder".localStr() + " (\("Playlist".localStr()))"
        case .likedSongs: return "♥"
        case .missingTags: return "❗️" + "Missing Tags".localStr()
        case .completeTags: return "✅" + "Complete Tags".localStr()
        case .customKey(let key): return key
        }
    }

    // 定义排序优先级权值（越小越靠前）
    private var sortWeight: Int {
        switch self {
        case .folder: return 0
        case .likedSongs: return 1
        case .missingTags: return 2
        case .completeTags: return 3
        case .customKey: return 4
        }
    }

    // 实现 Comparable 协议
    static func < (lhs: MusicKeyTitle, rhs: MusicKeyTitle) -> Bool {
        if lhs.sortWeight != rhs.sortWeight {
            return lhs.sortWeight < rhs.sortWeight
        }
        
        // 如果都是 customKey，处理字符串排序（让 "#" 沉底到最后）
        if case .customKey(let str1) = lhs, case .customKey(let str2) = rhs {
            if str1 == "#" { return false } // str1 是 "#"，强制认定为大（排后面）
            if str2 == "#" { return true }  // str2 是 "#"，强制认定 str1 小（排前面）
            
            // 其它字母正常按照自然语言字母表顺序比较（自动处理大小写和本地化）
            return str1.localizedStandardCompare(str2) == .orderedAscending
        }
        
        return false
    }

}
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
                    if let items = sortedMusic[title], title != .likedSongs {
                        tempSortArray.append(contentsOf: items)
                    }
                }
                
                DispatchQueue.main.async {
                    self.allMusicArray = tempSortArray
                    NotificationCenter.default.post(name: .librarySnapshotDidChange, object: self)
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

            // Limit concurrent cover decoding, and release temporary ObjC/image
            // allocations after each file instead of retaining an entire scan.
            self.parserManager.addOperation {
                autoreleasepool {
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

                    let metaData = MusicParseOperation.readMetadata(fileURL: fileURL, sourceType: .localFile,
                                                                   reuseCachedArtwork: true)
                    let musicModel = fileURL.createMusicModel(handleType: .link, sourceType: .localFile,
                                                             targetURL: self.baseFileURL, metadata: metaData)

                    if !MusicParseOperation.hasCurrentCachedArtwork(model: musicModel) {
                        // The write is synchronous; only the lightweight notification
                        // is dispatched to main. Do not capture artwork in callbacks.
                        SandboxFileManager.shared.writeMusicthumbnailImage(model: musicModel, image: metaData?.coverArt)
                    }
                    modelArrayQueue.async {
                        modelArray.append(musicModel)
                        dispatchGroup.leave()
                    }
                }
            }
        }

        // 所有任务完成后调用 completion
        dispatchGroup.notify(queue: .main) { () in
            
            let sortedMusic = self.sortHomeMusics(modelArray)
            var tempSortArray = [MusicItemModel]()

            for title in self.musicIndexArray {
                if let items = sortedMusic[title], title != .likedSongs {
                    tempSortArray.append(contentsOf: items)
                }
            }
            
            self.allMusicArray = tempSortArray
            NotificationCenter.default.post(name: .librarySnapshotDidChange, object: self)
            completion?(modelArray)
        }
    }
    
    // 整理/排序首页数据源
    public func sortHomeMusics(_ allArray: [MusicItemModel]) -> [MusicKeyTitle: [MusicItemModel]] {
        var groupedDictionary = [MusicKeyTitle: [MusicItemModel]]()
        self.musicIndexArray.removeAll()
        
        let folderArray = self.folderArray.map { MusicItemModel(fileURL: $0, sourceType: .localFile) }
        
        var tempAllArray = allArray.filter { $0.mediaPlayURL.isSupportMusicFile(false) || $0.isFolder() }
        tempAllArray = Array(Set(tempAllArray))
        
        // 1️⃣ 不分组 <包括搜索>
        if self.groupType == .nonGroup || self.searchKey != nil {
            let starArray = tempAllArray.filter { $0.isFlagFavorite() && !$0.isFolder() }
            if !starArray.isEmpty {
                self.musicIndexArray.append(.likedSongs)
                groupedDictionary[.likedSongs] = Array(Set(starArray)).sorted {
                    $0.sortAnotherModel(model2: $1, sortType: self.sortType)
                }
            }
            
            self.musicIndexArray.append(.customKey("#"))
            groupedDictionary[.customKey("#")] = tempAllArray.sorted {
                $0.sortAnotherModel(model2: $1, sortType: self.sortType)
            }

            self.musicDictionary = groupedDictionary
            return groupedDictionary
        }
        
        // 2️⃣ 有分组
        if self.groupType == .musictagGroup {
            // 按照音乐标签完整度分组
            groupedDictionary = Dictionary(grouping: tempAllArray, by: {
                $0.isFullMusicTag() ? .completeTags : .missingTags
            })
            
            // 如果文件夹数组不为空，将文件夹单独塞入 .folder 组（借助 Weight: 1 自动实现置顶）
            if !folderArray.isEmpty {
                groupedDictionary[.folder] = folderArray.sorted {
                    $0.sortAnotherModel(model2: $1, sortType: self.sortType)
                }
            }
        } else {
            // 按照首字母等普通规则分组
            groupedDictionary = Dictionary(grouping: tempAllArray, by: {
                .customKey($0.firstChar(self.groupType))
            })
        }
        
        // 处理已收藏的音乐
        let starArray = tempAllArray.filter { $0.isFlagFavorite() }
        if !starArray.isEmpty {
            groupedDictionary[.likedSongs] = Array(Set(starArray)).sorted {
                $0.sortAnotherModel(model2: $1, sortType: self.sortType)
            }
        }
        
        // 组内排序
        for (key, value) in groupedDictionary {
            groupedDictionary[key] = value.sorted {
                $0.sortAnotherModel(model2: $1, sortType: self.sortType)
            }
        }
        
        // 生成排好序的索引数组 (借助 MusicKeyTitle 实现的 Comparable 自动按权重和字符排序)
        let indexArr = groupedDictionary.keys.sorted()
        
        self.musicIndexArray = indexArr
        self.musicDictionary = groupedDictionary
        return groupedDictionary
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
    public var musicIndexArray: [MusicKeyTitle] {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &MusicKeys.kMusicIndexKey) as? [MusicKeyTitle] else {
                let initArr = [MusicKeyTitle]()
                
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
    private var musicDictionary: [MusicKeyTitle: [MusicItemModel]] {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &MusicKeys.kMusicDictKey) as? [MusicKeyTitle: [MusicItemModel]] else {
                let initArr = [MusicKeyTitle: [MusicItemModel]]()
                
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
                let manager = OperationQueue()
                manager.name = "com.parser.operationQueue"
                manager.qualityOfService = .utility
                // Tag readers may decode large embedded artwork. CPU count is
                // not an appropriate memory budget for a library with 1,000+ files.
                manager.maxConcurrentOperationCount = 2
                
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
