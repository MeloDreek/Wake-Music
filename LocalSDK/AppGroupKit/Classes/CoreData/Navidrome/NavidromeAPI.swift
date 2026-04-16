//
//  NavidromeAPI.swift
//  AppGroupKit
//
//  Created by 张文 on 3/4/25.
//

import KakaFoundation

/*
 我喜欢的，歌单、所有歌曲、歌手、专辑、电台
 */
public struct API {
    public static let NDAuthHeader = "X-ND-Authorization"

    public struct Navidrome {
        public static let login = "/auth/login"        // 登录Nav✅
        public static let keeplive = "/api/keepalive/keepalive" // 登录状态保活✅
        public static let getArtists = "/api/artist"  // 歌手列表✅
        public static let getSong = "/api/song"          // 歌曲列表
        public static let getPlaylists = "/api/playlist" // 歌单列表✅
//        public static let createPlaylist = "/api/playlist" // 创建歌单✅
//        public static let deletePlaylist = "api/playlist/%@" // 删除歌单✅
        public static let playlistSongs = "/api/playlist/%@/tracks" // 获取歌单中的歌曲列表
  }

    public struct Subsonic {
        public static let indexArtist = "/rest/getIndexes" // 带索引的歌手列表✅
        public static let artistInfo = "/rest/getArtistInfo2" // 歌手详情✅
        public static let topSongs = "/rest/getTopSongs"  // 获取歌手的热门歌曲✅
        public static let search = "/rest/search2" // 搜索歌曲/专辑/歌手✅
        public static let stream = "/rest/stream" // 歌曲播放链接✅
        public static let getStarred = "/rest/getStarred" // 获取收藏的歌曲/专辑/歌手✅
        public static let star = "/rest/star" // 收藏-歌曲/专辑/歌手✅
        public static let unstar = "/rest/unstar" // 取消收藏-歌曲/专辑/歌手✅
        public static let randomSongs = "/rest/getRandomSongs" // 随机获取一组歌曲✅
        public static let createPlaylist = "/rest/createPlaylist"  // 创建歌单✅
        public static let deletePlaylist = "/rest/deletePlaylist"  // 删除歌单✅
        public static let playlistDetial = "/rest/getPlaylist"      // 歌单下的歌曲列表✅
        public static let updatePlaylist = "/rest/updatePlaylist" // 更新歌单✅
        public static let coverArt = "/rest/getCoverArt" // 获取封面✅
        public static let getLyric = "/rest/getLyrics" // 获取歌词✅
  }
    
}


public enum AppMeta {
    public static let name = "Wake_Music"
    public static var subsonicApiVersion = "1.16.1"
    
    public static var identifier: String {
        get {
            let bundleID = (Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String) ?? Application.wakeMusic.appstoreID()
            return bundleID
        }
    }
}
