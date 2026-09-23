//
//  PlayConfigGroupModel.swift
//  Mobie
//
//  Created by 张文 on 10/29/24.
//

import Foundation

enum PlayConfigGroupType {
    case playerGroup
    case otherGroup
    case naviGroup
}

struct PlayConfigGroupModel {
    
    /// 区分是哪一组
    var group = PlayConfigGroupType.playerGroup
    
    /// 头部标题
    var headTitle: String?
    
    /// 数据源
    var itemArray: [PlayConfigItemType] = []
    
    /// 底部文字
    var footTitle: String?
    
}

enum PlayConfigItemType {
    case preDownload
    
    case playerStyle
    case playerBack
    case playAnimation
    
    case showExtension
    case lyricStyle
    case lastTimeCache
    case showMissTags
        
    case transcoding
    case targetFormat
    case targetMaxBitRate
            
    func titleStr() -> String {
        switch self {
        case .preDownload:
            return "Pre-download".localStr()
            
        case .playerStyle:
            return "Player Style".localStr()
        case .playerBack:
            return "Player Background".localStr()
        case .playAnimation:
            return "Play Animation".localStr()
            
        case .showExtension:
            return "Show File Extension".localStr()
        case .lyricStyle:
            return "On-Screen Lyrics".localStr()
        case .lastTimeCache:
            return "Remember Last Position".localStr()
        case .showMissTags:
            return "Show Missing Tags".localStr()
        
                        
        case .transcoding:
            return "Transcoding".localStr()
        case .targetFormat:
            return "Transcoding Format".localStr()
        case .targetMaxBitRate:
            return "Max Bitrate".localStr()
            
        }
    }
    
    
}
