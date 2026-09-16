//
//  NavidromeSong.swift
//  AppGroupKit
//
//  Created by 张文 on 2/21/25.
//

import SmartCodable

/// Navidrome歌曲
public struct NavidromeSong: SmartCodableX {
    
    public init(id: String, title: String, artist: String, artistId: String? = nil, album: String, albumId: String? = nil, trackNumber: Int, playCount: Int, discNumber: Int, bitRate: Int, musicBrainzId: String, isVideo: Bool, genres: [String], samplingRate: Int, suffix: String, path: String? = nil, year: Int? = nil, starred: Bool, date: String? = nil, duration: Int, mediaFileId: String? = nil, channelCount: Int, size: Int, genre: String? = nil, lyrics: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artistId = artistId
        self.album = album
        self.albumId = albumId
        self.trackNumber = trackNumber
        self.playCount = playCount
        self.discNumber = discNumber
        self.bitRate = bitRate
        self.musicBrainzId = musicBrainzId
        self.isVideo = isVideo
        self.genres = genres
        self.samplingRate = samplingRate
        self.suffix = suffix
        self.path = path
        self.year = year
        self.starred = starred
        self.date = date
        self.duration = duration
        self.mediaFileId = mediaFileId
        self.channelCount = channelCount
        self.size = size
        self.genre = genre
        self.lyrics = lyrics
    }
    
    public init() {  }
    
    /// ID
    public var id: String = ""
    
    /// 名称
    public var title: String = ""
    
    /// 艺术家
    public var artist: String = ""
    public var artistId: String?
    
    /// 专辑
    public var album: String = ""
    public var albumId: String?
    
    /// 封面图："mf-733e5e2e8295f80297575f4b5f0c5553_6772baa3"
    public var coverArt: String = ""
    
    /// 音轨号
    public var trackNumber: Int = 0
    
    /// 播放次数
    public var playCount: Int = 0
    
    /// 音轨
    public var discNumber: Int = 0
    
    /// 比特率
    public var bitRate: Int = 0
    
    /// 音乐大脑ID
    public var musicBrainzId: String = ""
    
    /// 是不是视频
    public var isVideo: Bool = false
    
    /// 文件大小
    public var size: Int = 0
    
    /// 音乐流派
    public var genres: [String] = []
    
    /// 采样率
    public var samplingRate: Int = 0
    
    /// 音频格式
    public var suffix: String = ""
    
    /// 路径："/volume1/music/张宇/雨一直下/张宇-雨一直下.flac"
    public var path: String?
    
    /// 年份
    public var year: Int?
    
    /// 收藏状态
    public var starred: Bool = false
    
    /// 年代
    public var date: String?
    
    /// 时间
    public var duration: Int = 0
    
    /// 媒体文件ID
    public var mediaFileId: String?
    
    /// 声道
    public var channelCount: Int = 2
    
    /// 音乐流派
    public var genre: String?
        
    /// 歌词
    public var lyrics: String?
    
    /// 当前服务器的配置
    public var navUser: NavidromeUserModel?
    
    
    /// 播放地址
    public func mediaPlayURL() -> URL? {
        guard let navUser = self.navUser else { return nil }
        
        let maxBitRate = MusicConfigManager.shared.navMaxBitRate
        let format = MusicConfigManager.shared.navFormats.rawValue
        return navUser.subsonicURL(endpoint: "/rest/stream", parameters: [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "maxBitRate", value: String(maxBitRate.rawValue)),
            URLQueryItem(name: "format", value: format)
        ])
    }
    
    /// 下载地址
    public func downloadResURL() -> URL? {
        guard let navUser = self.navUser else { return nil }
        
        return navUser.subsonicURL(endpoint: "/rest/stream", parameters: [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "maxBitRate", value: "0"),
            URLQueryItem(name: "format", value: "raw")
        ])
    }
    
    /// 封面地址
    public func coverImgURL() -> URL? {
        guard let navUser = self.navUser else { return nil }
        
        return navUser.subsonicURL(endpoint: API.Subsonic.coverArt, parameters: [
            URLQueryItem(name: "id", value: coverArt.isEmpty ? id : coverArt),
            URLQueryItem(name: "size", value: "300")
        ])
    }
    
}
