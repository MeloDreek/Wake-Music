//
//  NavidromeSetModel.swift
//  AppGroupKit
//
//  Created by 张文 on 3/4/25.
//

import SmartCodable

public struct NavidromeSetModel: SmartCodableX {
    
    public init(starred: NaviArAlSongModel? = nil, randomSongs: [NavidromeSong]? = nil, playlists: [NavidromePlaylist]? = nil) {
        self.starred = starred
        self.randomSongs = randomSongs
        self.playlists = playlists
    }
    
    public init() {
        
    }
    
    /// 喜欢的歌曲、歌手、专辑
    public var starred: NaviArAlSongModel?
    
    /// 随机的100首歌曲
    public var randomSongs: [NavidromeSong]?
    
    /// 歌单列表
    public var playlists: [NavidromePlaylist]?
    
    /// 排序后的全部歌手
    public var allArtists: [NavidromeNameArtists]?
    
}

public struct NaviArAlSongModel: SmartCodableX {
    
    public init(artist: [NavidromeArtist]? = nil, album: [NavidromeAlbum]? = nil, song: [NavidromeSong]? = nil) {
        self.artist = artist
        self.album = album
        self.song = song
    }
    
    public init() {
        
    }
    
    /// 艺术家
    public var artist: [NavidromeArtist]?
    
    /// 专辑
    public var album: [NavidromeAlbum]?
    
    /// 歌曲
    public var song: [NavidromeSong]?
    
    /// 插入服务器数据
    public func update(_ navUser: NavidromeUserModel?) -> NaviArAlSongModel {
        var newModel = self
        
        var tempArray1 = self.artist ?? []
        var tempArray2 = self.album ?? []
        var tempArray3 = self.song ?? []
        
        let artistArray = tempArray1.map {
            var model = $0
            model.navUser = navUser
            return model
        }
        
        let albumArray = tempArray2.map {
            var model = $0
            model.navUser = navUser
            return model
        }
        
        let songArray = tempArray3.map {
            var model = $0
            model.navUser = navUser
            return model
        }
        
        newModel.artist = artistArray
        newModel.album = albumArray
        newModel.song = songArray
        
        return newModel
    }
    
    
}
