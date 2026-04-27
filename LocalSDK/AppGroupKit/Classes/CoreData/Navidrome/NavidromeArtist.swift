//
//  NavidromeArtist.swift
//  AppGroupKit
//
//  Created by 张文 on 2/21/25.
//

import SmartCodable

/// Nav艺术家
public struct NavidromeArtist: SmartCodableX, Hashable {
    
    public init(id: String, name: String, fullText: String? = nil, smallImageUrl: String? = nil, mediumImageUrl: String? = nil, largeImageUrl: String? = nil, artistImageUrl: String? = nil, externalUrl: String, biography: String, songCount: Int, albumCount: Int, starred: Bool, genres: String? = nil, similarArtist: [NavidromeArtist]? = nil) {
        self.id = id
        self.name = name
        self.fullText = fullText
        self.smallImageUrl = smallImageUrl
        self.mediumImageUrl = mediumImageUrl
        self.largeImageUrl = largeImageUrl
        self.artistImageUrl = artistImageUrl
        self.externalUrl = externalUrl
        self.biography = biography
        self.songCount = songCount
        self.albumCount = albumCount
        self.starred = starred
        self.genres = genres
        self.similarArtist = similarArtist
    }
    
    public init() {
        
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    /// ID
    public var id: String = ""
    
    /// 名字
    public var name: String = ""
    
    /// 全名
    public var fullText: String?
    
    /// 歌手接口
    public var smallImageUrl: String?
    public var mediumImageUrl: String?
    public var largeImageUrl: String?
    
    /// 搜索接口
    public var artistImageUrl: String?
    
    /// 第三方连接
    public var externalUrl: String = ""
    
    /// 个性签名
    public var biography: String?
    
    /// 歌曲个数
    public var songCount: Int?
    
    /// 专辑个数
    public var albumCount: Int?
    
    /// 是否收藏
    public var starred: Bool = false
    
    /// 流派
    public var genres: String?
    
    /// 当前服务器的配置
    public var navUser: NavidromeUserModel?
    
    /// 相似歌手
    public var similarArtist: [NavidromeArtist]?
    
    // 歌手头像地址
    public func artistAvatarURL() -> URL? {
        guard let navUser = self.navUser else { return nil }
        
        let urlStr = navUser.hostUrl + API.Subsonic.coverArt + navUser.subsonicParams() + "&id=ar-\(self.id)" + "&size=\(100.ckValue())"
        
        let placeStr = self.artistImageUrl ?? (self.smallImageUrl ?? self.mediumImageUrl ?? self.largeImageUrl)
                
        return URL(string: (urlStr ?? placeStr) ?? "")
        
    }
    
    // 找字母索引是一个相对昂贵的操作
    public func firstChar() -> String {
        
        let firstChar = FirstCharHelper.shared.firstChar(self.name)
        
        return firstChar
    }
    
    // 合并歌手模型信息
    public mutating func mergeArtistModel(_ otherModel: NavidromeArtist) -> NavidromeArtist {
        self.artistImageUrl = self.artistImageUrl ?? otherModel.artistImageUrl
        self.fullText = self.fullText ?? otherModel.fullText
        self.smallImageUrl = self.smallImageUrl ?? otherModel.smallImageUrl
        self.mediumImageUrl = self.mediumImageUrl ?? otherModel.mediumImageUrl
        self.largeImageUrl = self.largeImageUrl ?? otherModel.largeImageUrl
        self.biography = self.biography ?? otherModel.biography
        self.songCount = self.songCount ?? otherModel.songCount
        self.albumCount = self.albumCount ?? otherModel.albumCount
        self.navUser = self.navUser ?? otherModel.navUser
        self.similarArtist = self.similarArtist ?? otherModel.similarArtist
        return self
    }
}


/// 索引歌手列表接口
public struct NavidromeIndexesArtist: SmartCodableX {
    public init(index: [NavidromeNameArtists]) {
        self.index = index
    }
    
    public init() { }
    
    public var index: [NavidromeNameArtists] = []
}

public struct NavidromeNameArtists: SmartCodableX {
    
    public init(name: String, artist: [NavidromeArtist]) {
        self.name = name
        self.artist = artist
    }
    
    public init() { }
    
    /// 索引，A-Z
    public var name: String = ""
    
    /// 歌手列表
    public var artist: [NavidromeArtist] = []
}


public class FirstCharHelper {
    public static let shared = FirstCharHelper()
    private let collator = UILocalizedIndexedCollation.current()
    private var cache = [String: String]() // 缓存字母索引
    private let lock = NSLock() // 线程安全锁

    public func firstChar(_ name: String) -> String {
        // 处理空字符串
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "#"
        }

        lock.lock() // 确保线程安全
        if let cached = cache[name] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // 计算首字母
        let titleIndex = collator.section(for: name as NSString, collationStringSelector: #selector(NSString.description))

        // 确保索引有效
        let firstChar: String
        if titleIndex >= 0 && titleIndex < collator.sectionTitles.count {
            firstChar = collator.sectionTitles[titleIndex]
        } else {
            firstChar = "#"
        }

        // 存入缓存
        lock.lock()
        cache[name] = firstChar
        lock.unlock()

        return firstChar
    }
}
