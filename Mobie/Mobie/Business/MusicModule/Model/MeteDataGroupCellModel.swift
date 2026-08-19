//
//  MeteDataGroupCellModel.swift
//  Mobie
//
//  Created by 张文 on 11/4/24.
//

import AppGroupKit

enum MeteDataCellGroupType: Int {
    case headGroup  = 0
    case basicGroup
    case audioFinger
    case otherGroup
    case readonlyGroup
    case exportGroup
}

// 【封面、歌名、歌手、专辑、歌词】，【年代、声道、流派、音轨】，【文件名、扩展名、文件大小、比特率、码率】
struct MeteDataGroupCellModel {
    
    /// 区分是哪一组
    var group = MeteDataCellGroupType.basicGroup
    
    /// 头部标题
    var headTitle: String?
    
    /// 数据源
    var itemArray: [MeteDataCellItemType] = []
    
    /// 底部文字
    var footTitle: String?
    
}

enum MeteDataCellItemType: Int {
    
    case headerTag = 0
    
    case coverImage
    case title
    case artist
    case album
    case lyrics
    
    case audioFinger
        
    case year
    case channel
    case genre
    case trackNumber
    case comment
    case bitRate
    case samples
    
    case fileName
    case fileExtension
    case fileSize
    case fileDuration
    case filePath
        
    func titleStr() -> String? {
        switch self {
        case .headerTag:
            return "Music tag refers to the metadata embedded in a music file, including cover image, lyrics, title, artist, album, era, genre, track, sampling rate, bit rate, etc.".localStr()
            
        case .coverImage:
            return MusicTagType.artWork.titleStr()
        case .title:
            return MusicTagType.title.titleStr()
        case .artist:
            return MusicTagType.artist.titleStr()
        case .album:
            return MusicTagType.album.titleStr()
        case .lyrics:
            return MusicTagType.lyrics.titleStr()
            
        case .audioFinger:
            return "Auto-Match".localStr()
            
        case .year:
            return MusicTagType.year.titleStr()
        case .genre:
            return MusicTagType.genre.titleStr()
        case .trackNumber:
            return MusicTagType.trackNumber.titleStr()
        case .comment:
            return MusicTagType.comment.titleStr()
            
        case .channel:
            return "Channel".localStr()
        case .bitRate:
            return "Bitrate".localStr()
        case .samples:
            return "Sample Rate".localStr()
        case .fileName:
            return "Name".localStr()
        case .fileExtension:
            return "Extension".localStr()
        case .fileSize:
            return "File Size".localStr()
        case .fileDuration:
            return "Duration".localStr()
        case .filePath:
            return "Path".localStr()
        
        }
    }
    
}

