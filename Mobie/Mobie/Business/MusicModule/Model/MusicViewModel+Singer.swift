//
//  MusicViewModel+Singer.swift
//  Mobie
//
//  Created by 张文 on 10/19/24.
//

import KakaFoundation
import AppGroupKit

extension Notification.Name {
    static let librarySnapshotDidChange = Notification.Name("WakeMusic.librarySnapshotDidChange")
}

enum LibraryGrouping {
    static func name(_ value: String?, fallback: String) -> String {
        let value = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? fallback : value.precomposedStringWithCanonicalMapping
    }

    static func artists(_ value: String, fallback: String) -> [String] {
        let names = value.components(separatedBy: CharacterSet(charactersIn: ",&|;/–+、，；"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping }
            .filter { !$0.isEmpty }
        return names.isEmpty ? [fallback] : Array(Set(names)).sorted()
    }
}

extension MusicViewModel {

    /// 整理歌手数据源
    public func refreshSingerDataAction(_ tempAllArray: [MusicItemModel]) {

        // Build names and membership together, using the SAME display-name rule.
        // This includes demo tracks and prevents empty / substring-only groups.
        var groups = [String: [MusicItemModel]]()
        for item in tempAllArray where !item.isFolder() && !item.isLRCFile() {
            for name in LibraryGrouping.artists(item.showArtistName(), fallback: "Unknown Artist".localStr()) {
                groups[name, default: []].append(item)
            }
        }
        singerDictionary = groups
        singerArray = groups.keys.sorted {
            let lhs = groups[$0]?.count ?? 0, rhs = groups[$1]?.count ?? 0
            return lhs == rhs ? $0.localizedStandardCompare($1) == .orderedAscending : lhs > rhs
        }
    }

    // 根据歌手名来分组
    public func singerMusicArray(_ singer: String) -> [MusicItemModel] {
        let singerArray = self.singerDictionary[singer] ?? []
        // Preserve newest-first ordering without stat-ing files inside every comparison.
        let datedSongs: [(song: MusicItemModel, date: Date)] = Set(singerArray).map {
            (song: $0, date: $0.mediaPlayURL.creationDate ?? Date.distantPast)
        }
        let sortedSongs = datedSongs.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.song.showTitleName().localizedStandardCompare(rhs.song.showTitleName()) == .orderedAscending
        }
        let sortArray = sortedSongs.map { $0.song }

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

    private struct SingerKeys {
        static var kSingerArrKey: Void?
        static var kSingerDictKey: Void?
        static var kSingerIndextKey: Void?
    }

}
