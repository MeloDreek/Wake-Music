//
//  NavidromeAlbum.swift
//  AppGroupKit
//
//  Created by 张文 on 2/21/25.
//

import SmartCodable

/// Nav专辑
public struct NavidromeAlbum: SmartCodable {
    
    public init(id: String, name: String, albumArtist: String, artist: String, albumCover: String, info: String, songs: [NavidromeSong], genre: String, minYear: Int) {
        self.id = id
        self.name = name
        self.albumArtist = albumArtist
        self.artist = artist
        self.albumCover = albumCover
        self.info = info
        self.songs = songs
        self.genre = genre
        self.minYear = minYear
    }
    
    public init() {
        
    }
    
    /// ID
    var id: String = ""
    
    /// 名称
    var name: String = ""
    
    /// 专辑艺术家
    var albumArtist: String = ""
    
    /// 艺术家
    var artist: String = ""
    
    /// 专辑封面
    var albumCover: String = ""
    
    /// 信息
    var info: String = ""
    
    /// 歌曲
    var songs: [NavidromeSong] = []
    
    /// 流派
    var genre: String = ""
    
    /// 年代
    var minYear: Int = 0
    
    /// 当前服务器的配置
    public var navUser: NavidromeUserModel?
    
}

