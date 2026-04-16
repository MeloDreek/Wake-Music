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
    
    case playerStyle
    case playerBack
    case playAnimation
    case miniStyle
    case enableSide
    
    case showExtension
    case lyricStyle
    case lastTimeCache
    case showMissTags
    case randomSort
        
    case transcoding
    case targetFormat
    case targetMaxBitRate
            
    func titleStr() -> String {
        switch self {
            
        case .playerStyle:
            return "Player Style".localStr()
        case .playerBack:
            return "Player background".localStr()
        case .playAnimation:
            return "Play Animation".localStr()
        case .miniStyle:
            return "Mini Bar"
        case .enableSide:
            return "Auto attaches to the edge of the screen".localStr()
            
            
        case .showExtension:
            return "Show Extension".localStr()
        case .lyricStyle:
            return "Lyrics on screen".localStr()
        case .lastTimeCache:
            return "Record last progress".localStr()
        case .showMissTags:
            return "Show missing tags".localStr()
        case .randomSort:
            return "Shuffle".localStr()
        
                        
        case .transcoding:
            return "Transcoding".localStr()
        case .targetFormat:
            return "Transcoding Format".localStr()
        case .targetMaxBitRate:
            return "Max Bitrate".localStr()
            
        }
    }
    
    
}
