//
//  ITunesSongModel.swift
//  Mobie
//
//  Created by 张文 on 5/11/25.
//

import SmartCodable

struct ITunesSongModel: SmartCodableX, Equatable, Hashable {
    
    /// 类型：song、book、movie
    var kind: String = ""
    
    /// 艺术家ID
    var artistId: String = ""
    
    /// 艺术家名称
    var artistName: String = ""
    
    /// 名称
    var trackName: String = ""
    
    /// 30秒试听音频：可直接播放
    var previewUrl: String = ""
    
    /// 封面：30x30
    var artworkUrl30: String = ""
    
    /// 封面：100x100
    var artworkUrl100: String = ""
    
    /// 艺术家在AM的链接
    var artistViewUrl: String = ""
    
    /// 日期：2019-11-01T12:00:00Z
    var releaseDate: String = ""
    
    /// 专辑顺序
    var trackNumber: Int = 0
    
    /// 专辑数量
    var trackCount: Int = 0
    
    /// US
    var country: String = ""
    
    /// 音乐流派
    var primaryGenreName: String = ""
    
    /// 提高查找效率的方法
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.artistId)
        hasher.combine(self.artworkUrl100)
    }
    
    public static func == (lhs: ITunesSongModel, rhs: ITunesSongModel) -> Bool {
        return lhs.artistId == rhs.artistId &&
        lhs.artworkUrl100 == rhs.artworkUrl100
    }
    
}
