//
//  SubsonicResponse.swift
//  Mobie
//
//  Created by 张文 on 2/28/25.
//

import SmartCodable
import AppGroupKit

struct SubsonicResponse: SmartCodableX {
    
    /// ok或failed
    var status: String = ""
    
    /// 版本
    var version: String = ""
    
    /// 类型：navidrome
    var type: String = ""
    
    /// 服务器版本
    var serverVersion: String = ""
    
    /// 是否为公开的Subsonic
    var openSubsonic: Bool = false
    
    /// 错误信息
    var error: SubsonicError?
    
    /// 收藏的歌曲
    var starred: NaviArAlSongModel?
    
    /// 随机歌曲
    var randomSongs: NaviArAlSongModel?
    
    /// 歌手详情信息和相似歌手
    var artistInfo2: NavidromeArtist?
    
    /// 歌手的热门歌曲
    var topSongs: NaviArAlSongModel?
    
    /// 新建歌单
    var playlist: NavidromePlaylist?
    
    /// 搜索结果
    var searchResult2: NaviArAlSongModel?
    
    /// 歌词
    var lyrics: NavidromeLyrics?
    
    /// 带索引的歌手列表
    var indexes: NavidromeIndexesArtist?
    
    
    func isSuccess() -> Bool {
        return self.status == "ok"
    }
    
}

struct SubsonicError: SmartCodableX {
    
    /// 错误码
    var code: Int = 0
    
    /// 错误信息
    var message: String = ""
}
