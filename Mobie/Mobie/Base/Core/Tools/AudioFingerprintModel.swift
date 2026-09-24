//
//  AudioFingerprintModel.swift
//  Waketag
//
//  Created by kaka on 2026/5/20.
//

import SmartCodable
import AppGroupKit
import ShazamKit

/// 音频指纹后的元数据
struct AudioFingerprintModel: SmartCodableX {
    /// Nil means acoustic identification. Catalog guesses are always fill-only.
    var metadataSource: String?
    var isCatalogFallback: Bool { metadataSource?.hasPrefix("appleCatalog") == true }
    
    /// 标题
    var title: String?
    
    /// 艺术家
    var artist: String?
    
    /// 专辑
    var album: String?
    
    /// 封面地址
    var coverArt: String?
    
    /// 歌词
    var lyrics: [LyricInfoModel]?
    
    
    /// 年代
    var year: Int?
    
    /// 流派
    var genres: String?
    
    /// 音轨号
    var trackNumber: Int?
    
    /// 时长
    var duration: TimeInterval?
    
    /// 国际标准音像制品编码
    var isrc: String?
    
    /// AM上的ID
    var appleMusicID: String?
    
    /// 歌曲URL
    var appleMusicURL: String?
    
    /// 歌手URL
    var artistURL: String?
    
}

extension SHMatchedMediaItem {
        
    /// 转换模型
    func convertAudioModel() -> AudioFingerprintModel {
        
        let firstSong = self.songs.first
        
        var model = AudioFingerprintModel()
        model.title = self.title
        model.artist = self.artist
        model.album = firstSong?.albumTitle
        model.coverArt = self.artworkURL?.absoluteString
        
        model.year = firstSong?.releaseDate?.year
        model.genres = firstSong?.genres?.title
        model.trackNumber = firstSong?.trackNumber
        model.duration = firstSong?.duration
        model.isrc = firstSong?.isrc
        model.appleMusicID = self.appleMusicID
        model.appleMusicURL = self.appleMusicURL?.absoluteString
        model.artistURL = firstSong?.artistURL?.absoluteString
        return model
    }
}
