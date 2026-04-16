//
//  NavidromePlaylist.swift
//  AppGroupKit
//
//  Created by 张文 on 2/21/25.
//

import SmartCodable

/// Nav歌单
public struct NavidromePlaylist: SmartCodable {
    
    public init(id: String, name: String, comment: String, isPublic: Bool, ownerId: String, ownerName: String, songCount: Int, size: Double, duration: Double, createdAt: String, songs: [NavidromeSong]? = nil, entry: [NavidromeSong]? = nil) {
        self.id = id
        self.name = name
        self.comment = comment
        self.isPublic = isPublic
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.songCount = songCount
        self.size = size
        self.duration = duration
        self.createdAt = createdAt
        self.songs = songs
        self.entry = entry
    }
    
    public init() {
        
    }
    
    /// ID
    public var id: String = ""
    
    /// 名称
    public var name: String = ""
    
    /// 评论
    public var comment: String = ""
    
    /// 是否公开
    public var isPublic: Bool = false
    
    /// 所有者ID
    public var ownerId: String = ""
    
    /// 所有者名称
    public var ownerName: String = ""
    
    /// 歌曲数
    public var songCount: Int = 0
    
    /// 大小
    public var size: Double = 0
    
    /// 时长
    public var duration: Double = 0
    
    /// 2025-02-20T02:20:20.024100662Z
    public var createdAt: String = ""
    
    /// 当前服务器的配置
    public var navUser: NavidromeUserModel?
    
    /// 歌曲
    public var songs: [NavidromeSong]?
    
    /// 歌单详情页
    public var entry: [NavidromeSong]?
    
    /// 歌曲列表
    public func songArray() -> [NavidromeSong] {
        guard let entry = self.entry else {
            return self.songs ?? []
        }
        
        return entry
    }
    
    /// 封面地址
    public func coverImgURL() -> URL? {
        
        guard let navUser = self.navUser else { return nil }
        
        let urlStr = navUser.hostUrl + API.Subsonic.coverArt + navUser.subsonicParams() + "&id=pl-\(self.id)" + "&size=600"
        
        return URL(string: urlStr ?? "")
    }
    
}

