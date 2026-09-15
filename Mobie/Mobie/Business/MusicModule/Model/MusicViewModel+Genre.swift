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

        let songs = tempAllArray.filter { !$0.isFolder() && !$0.isLRCFile() }
        let groups = Dictionary(grouping: songs) { ($0.musicGenreType() ?? .other).formatStr() }
        genreDictionary = groups
        genreArray = Array(Set(songs.map { $0.musicGenreType() ?? .other })).sorted {
            if $0 == $1 { return false }
            if $0 == .other { return false }
            if $1 == .other { return true }
            let lhs = groups[$0.formatStr()]?.count ?? 0, rhs = groups[$1.formatStr()]?.count ?? 0
            return lhs == rhs ? $0.formatStr().localizedStandardCompare($1.formatStr()) == .orderedAscending : lhs > rhs
        }
    }

    /// 根据流派获取数组
    func genreMusicArray(_ genre: MusicGenreType) -> [MusicItemModel] {
        let genreArray = self.genreDictionary[genre.formatStr()] ?? []
        let datedSongs: [(song: MusicItemModel, date: Date)] = Set(genreArray).map {
            (song: $0, date: $0.mediaPlayURL.creationDate ?? Date.distantPast)
        }
        let sortedSongs = datedSongs.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.song.showTitleName().localizedStandardCompare(rhs.song.showTitleName()) == .orderedAscending
        }
        let sortArray = sortedSongs.map { $0.song }

        return sortArray
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

    private struct GenreKeys {
        static var kGenreArrKey: Void?
        static var kAllGenreKey: Void?
    }

}
