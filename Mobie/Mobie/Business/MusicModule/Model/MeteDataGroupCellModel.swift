//
//  MeteDataGroupCellModel.swift
//  Mobie
//
//  Created by 张文 on 11/4/24.
//

import AppGroupKit

enum MeteDataCellGroupType: Int {
    case headGroup  = 0
    case basicGroup = 1
    case searchAI = 2
    case otherGroup  = 3
    case readonlyGroup  = 4
    case exportGroup = 5
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
    
    case coverImage = 1
    case title = 2
    case artist = 3
    case album = 4
    case lyrics = 5
    
    case searchAI = 6
    
    case year    = 7
    case channel = 8
    case genre   = 9
    case track   = 10
    case comment = 11
    case bitRate = 12
    case samples = 13
    
    case fileName = 14
    case fileExtension = 15
    case fileSize = 16
    case fileDuration = 17
    case filePath = 18
    
    case export = 19
    
    func titleStr() -> String? {
        switch self {
        case .headerTag:
            return "Music tags refer to the tag metadata embedded in the current music file. By modifying these metadata, the cover, title, artist, album, lyrics, etc. can be displayed perfectly even if you update the device.".localStr()
            
        case .coverImage:
            return "Album Cover".localStr()
        case .title:
            return "Title".localStr()
        case .artist:
            return "Artist".localStr()
        case .album:
            return "Album".localStr()
        case .lyrics:
            return "Lyrics".localStr()
            
        case .searchAI:
            return "Search with AI".localStr()
            
        case .year:
            return "Year".localStr()
        case .channel:
            return "Channel".localStr()
        case .genre:
            return "Genre".localStr()
        case .track:
            return "Track".localStr()
        case .comment:
            return "Comment".localStr()
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
            return "File Path".localStr()
        
        case .export:
            return "Export".localStr()
        
        }
    }
    
}

