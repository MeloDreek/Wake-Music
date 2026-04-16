//
//  MusicViewModel+Album.swift
//  Mobie
//
//  Created by 张文 on 10/19/24.
//

import KakaFoundation
import AppGroupKit

extension MusicViewModel {
    
    /// 整理专辑数据源
    public func refreshAlbumDataAction(_ tempAllArray: [MusicItemModel]) {
        
        let currentTime = Date()

        // 检查是否距离上次刷新时间不到1秒
        if let lastTime = self.lastAlbumRefreshTime, currentTime.timeIntervalSince(lastTime) < 1 {
            return
        }
        
        // 更新上次刷新时间
        self.lastAlbumRefreshTime = currentTime
        
        debugPrint("### MusicViewModel.refreshAlbumDataAction ###")
                
        let albumSet = Set(tempAllArray.map({ $0.album ?? "Unknown Album".localStr() }))
        self.albumArray = Array(albumSet)
        
        self.albumDictionary = self.sortAlbumMusics(tempAllArray)

    }
    
    /// 按照专辑内的音轨号排序
    func albumMusicArray(_ album: String) -> [MusicItemModel] {
        let albumArray = self.albumDictionary[album] ?? []
        let sortArray = Array(Set(albumArray)).sorted { (model1, model2) in
            let date1 = model1.track ?? 0
            let date2 = model2.track ?? 0
            return date1 < date2
        }
        
        return sortArray
    }
    
    private func sortAlbumMusics(_ tempAllArray: [MusicItemModel]) -> [String: [MusicItemModel]] {
        // 创建一个空的二维字典，用于存储分组后的对象
        var groupedDictionary = [String: [MusicItemModel]]()
        
        for albumName in self.albumArray {
            if groupedDictionary[albumName] == nil {
                groupedDictionary[albumName] = [MusicItemModel]()
            }
            
            // 获取当前专辑下的所有音乐
            var musicArray = tempAllArray.filter { $0.album ?? "Unknown Album".localStr() == albumName }
            
            // 对当前专辑下的音乐按照音轨号进行排序
            musicArray.sort { ($0.track ?? 0) < ($1.track ?? 0) }
            
            groupedDictionary[albumName] = musicArray
        }
        
        // 对专辑名排序
        self.albumArray = self.albumArray.sorted {
            let count1 = groupedDictionary[$0]?.count ?? 0
            let count2 = groupedDictionary[$1]?.count ?? 0
            return count1 > count2 // 按照歌曲数量从大到小排序
        }
        
        return groupedDictionary
    }
    
    /// 专辑名称—>音乐数组
    private var albumDictionary: [String: [MusicItemModel]] {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &AlbumKeys.kAlbumDictKey) as? [String: [MusicItemModel]] else {
                let initArr = [String: [MusicItemModel]]()
                
                objc_setAssociatedObject(self, &AlbumKeys.kAlbumDictKey, initArr, .OBJC_ASSOCIATION_COPY_NONATOMIC)
                return initArr
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &AlbumKeys.kAlbumDictKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    
    /// 根据专辑分类的数据源
    public var albumArray: [String] {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &AlbumKeys.kALbumArrKey) as? [String] else {
                let initArr = [String]()
                
                objc_setAssociatedObject(self, &AlbumKeys.kALbumArrKey, initArr, .OBJC_ASSOCIATION_COPY_NONATOMIC)
                return initArr
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &AlbumKeys.kALbumArrKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    
    /// 上次刷新的时间
    private var lastAlbumRefreshTime: Date? {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &AlbumKeys.kLastTimeKey) as? Date else {
                return nil
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &AlbumKeys.kLastTimeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private struct AlbumKeys {
        static var kALbumArrKey: Void?
        static var kAlbumDictKey: Void?
        static var kLastTimeKey: Void?
    }
    
}
