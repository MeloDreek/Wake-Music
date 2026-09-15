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

        let groups = Dictionary(grouping: tempAllArray.filter { !$0.isFolder() && !$0.isLRCFile() }) {
            LibraryGrouping.name($0.album, fallback: "Unknown Album".localStr())
        }
        albumDictionary = groups
        albumArray = groups.keys.sorted {
            let lhs = groups[$0]?.count ?? 0, rhs = groups[$1]?.count ?? 0
            return lhs == rhs ? $0.localizedStandardCompare($1) == .orderedAscending : lhs > rhs
        }
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

    private struct AlbumKeys {
        static var kALbumArrKey: Void?
        static var kAlbumDictKey: Void?
    }

}
