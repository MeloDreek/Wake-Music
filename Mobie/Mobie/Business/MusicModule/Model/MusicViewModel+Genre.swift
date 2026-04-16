//
//  MusicViewModel+Genre.swift
//  Mobie
//
//  Created by 张文 on 12/13/24.
//

import AppGroupKit

extension MusicViewModel {
    /// 整理专辑数据源
    public func refreshGenreDataAction(_ tempAllArray: [MusicItemModel]) {
        
        let currentTime = Date()

        // 检查是否距离上次刷新时间不到1秒
        if let lastTime = self.lastGenreRefreshTime, currentTime.timeIntervalSince(lastTime) < 1 {
            return
        }
        
        // 更新上次刷新时间
        self.lastGenreRefreshTime = currentTime
        
        debugPrint("### MusicViewModel.refreshGenreDataAction ###")
                
        let genreSet = Set(tempAllArray.map({ $0.musicGenreType() ?? .other }))
        self.genreArray = Array(genreSet)
        
        self.genreDictionary = self.sortGenreMusics(tempAllArray)
    }
    
    /// 根据流派获取数组
    func genreMusicArray(_ genre: MusicGenreType) -> [MusicItemModel] {
        let genreArray = self.genreDictionary[genre.formatStr()] ?? []
        let sortArray = Array(Set(genreArray)).sorted { (model1, model2) in
            let date1 = model1.mediaPlayURL.creationDate ?? Date.distantPast
            let date2 = model2.mediaPlayURL.creationDate ?? Date.distantPast
            return date1 > date2
        }
        
        return sortArray
    }
    
    private func sortGenreMusics(_ tempAllArray: [MusicItemModel]) -> [String: [MusicItemModel]] {
        // 创建一个空的二维字典，用于存储分组后的对象
        var groupedDictionary = [String: [MusicItemModel]]()
        
        for subGenre in self.genreArray {
            if groupedDictionary[subGenre.formatStr()] == nil {
                groupedDictionary[subGenre.formatStr()] = [MusicItemModel]()
            }
            
            // 获取当前专辑下的所有音乐
            let musicArray = tempAllArray.filter { ($0.musicGenreType() ?? .other).formatStr() == subGenre.formatStr() }
            
            groupedDictionary[subGenre.formatStr()] = musicArray
        }
        
        // 对音乐流派排序
        self.genreArray = self.genreArray.sorted {
            if $0 == .other {
                return false
            }
            if $1 == .other {
                return true
            }
            
            let count1 = groupedDictionary[$0.formatStr()]?.count ?? 0
            let count2 = groupedDictionary[$1.formatStr()]?.count ?? 0
            return count1 > count2 // 按照歌曲数量从大到小排序
        }
        
        return groupedDictionary
    }
    
    /// 根据流派分类的数据源
    public var genreArray: [MusicGenreType] {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &GenreKeys.kGenreArrKey) as? [MusicGenreType] else {
                let initArr = [MusicGenreType]()
                
                objc_setAssociatedObject(self, &GenreKeys.kGenreArrKey, initArr, .OBJC_ASSOCIATION_COPY_NONATOMIC)
                return initArr
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &GenreKeys.kGenreArrKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    
    /// 所有的流派数组
    private var genreDictionary: [String: [MusicItemModel]] {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &GenreKeys.kAllGenreKey) as? [String: [MusicItemModel]] else {
                let initArr = [String: [MusicItemModel]]()
                
                objc_setAssociatedObject(self, &GenreKeys.kAllGenreKey, initArr, .OBJC_ASSOCIATION_COPY_NONATOMIC)
                return initArr
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &GenreKeys.kAllGenreKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    
    /// 上次刷新的时间
    private var lastGenreRefreshTime: Date? {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &GenreKeys.kLastTimeKey) as? Date else {
                return nil
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &GenreKeys.kLastTimeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private struct GenreKeys {
        static var kGenreArrKey: Void?
        static var kAllGenreKey: Void?
        static var kLastTimeKey: Void?
    }
    
}
