//
//  LRCLibLyricModel.swift
//  Mobie
//
//  Created by 张文 on 5/11/25.
//

import SmartCodable
import AppGroupKit
import WaketagLibKit

/// LRCLib接口的模型
struct LRCLibLyricModel: SmartCodableX {
    
    /// ID
    var id: Int = 0
    
    /// 标题
    var name: String = ""
    
    /// 艺术家
    var artistName: String = ""
    
    /// 专辑
    var albumName: String = ""
    
    /// 歌名
    var trackName: String = ""
    
    /// 时长
    var duration: TimeInterval?
    
    /// 无时间的歌词
    var plainLyrics: String?
    
    /// 同步歌词
    var syncedLyrics: String?
    
}

extension LRCLibLyricModel {
    func convertLyricModel() -> LyricInfoModel? {
        let lyricStr = self.syncedLyrics ?? self.plainLyrics ?? ""
        var model = TaglibMetadataParser.parseSynchronizedLyrics(lyricStr)?.convertSwiftModel()
        model?.title = self.name
        model?.artist = self.artistName
        model?.album = self.albumName
        model?.totalTime = self.duration
        return model
    }
}
