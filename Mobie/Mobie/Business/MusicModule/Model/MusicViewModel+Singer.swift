//
//  MusicViewModel+Singer.swift
//  Mobie
//
//  Created by 张文 on 10/19/24.
//

import KakaFoundation
import AppGroupKit

extension MusicViewModel {
    
    /// 整理歌手数据源
    public func refreshSingerDataAction(_ tempAllArray: [MusicItemModel]) {
        
        let currentTime = Date()

        // 检查是否距离上次刷新时间不到1秒
        if let lastTime = self.lastSingerRefreshTime, currentTime.timeIntervalSince(lastTime) < 1 {
            return
        }
        
        // 更新上次刷新时间
        self.lastSingerRefreshTime = currentTime
        
        debugPrint("### MusicViewModel.refreshSingerDataAction ###")
                        
        // 提取所有歌手名称
        var artistSet = Set<String>()
        for item in tempAllArray {
            let artistNames = item.showArtistName().components(separatedBy: CharacterSet(charactersIn: ",&|;/–+"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            artistSet.formUnion(artistNames)
        }
        self.singerArray = Array(artistSet)
        
        self.singerDictionary = self.sortSingerMusics(tempAllArray)
        
    }
    
    // 整理歌手页数据源
    private func sortSingerMusics(_ tempAllArray: [MusicItemModel]) -> [String: [MusicItemModel]] {
        var groupedDictionary = [String: [MusicItemModel]]()
        
        for artist in self.singerArray {
            if groupedDictionary[artist] == nil {
                groupedDictionary[artist] = [MusicItemModel]()
            }
            
            // 获取当前专辑下的所有音乐
            var musicArray = tempAllArray.filter { ($0.artist ?? "Unknown Artist".localStr()).contains(artist) }
            
            // 对当前专辑下的音乐按照音轨号进行排序
            musicArray.sort { ($0.year ?? 0) < ($1.year ?? 0) }
            
            groupedDictionary[artist] = musicArray
        }
        
        // 对歌手名排序
        self.singerArray = self.singerArray.sorted {
            let count1 = groupedDictionary[$0]?.count ?? 0
            let count2 = groupedDictionary[$1]?.count ?? 0
            return count1 > count2 // 按照歌曲数量从大到小排序
        }
        
        return groupedDictionary
    }
    
    // 根据歌手名来分组
    public func singerMusicArray(_ singer: String) -> [MusicItemModel] {
        let singerArray = self.singerDictionary[singer] ?? []
        let sortArray = Array(Set(singerArray)).sorted { (model1, model2) in
            let date1 = model1.mediaPlayURL.creationDate ?? Date.distantPast
            let date2 = model2.mediaPlayURL.creationDate ?? Date.distantPast
            return date1 > date2
        }
        
        return sortArray
    }
    
    // 根据歌手分类的数据源
    public var singerArray: [String] {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &SingerKeys.kSingerArrKey) as? [String] else {
                let initArr = [String]()
                
                objc_setAssociatedObject(self, &SingerKeys.kSingerArrKey, initArr, .OBJC_ASSOCIATION_COPY_NONATOMIC)
                return initArr
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &SingerKeys.kSingerArrKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    
    /// 艺术家首字母—>音乐
    private var singerDictionary: [String: [MusicItemModel]] {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &SingerKeys.kSingerDictKey) as? [String: [MusicItemModel]] else {
                let initArr = [String: [MusicItemModel]]()
                
                objc_setAssociatedObject(self, &SingerKeys.kSingerDictKey, initArr, .OBJC_ASSOCIATION_COPY_NONATOMIC)
                return initArr
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &SingerKeys.kSingerDictKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    
    /// 上次刷新的时间
    private var lastSingerRefreshTime: Date? {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &SingerKeys.kLastTimeKey) as? Date else {
                return nil
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &SingerKeys.kLastTimeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private struct SingerKeys {
        static var kSingerArrKey: Void?
        static var kSingerDictKey: Void?
        static var kSingerIndextKey: Void?
        static var kLastTimeKey: Void?
    }
    
}

