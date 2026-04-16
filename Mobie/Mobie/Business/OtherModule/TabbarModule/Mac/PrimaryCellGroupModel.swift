//
//  PrimaryCellGroupModel.swift
//  Mobie
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import AppGroupKit

enum PrimaryCellGroupType: Int {
    case musicGroup = 0
    case importGroup = 1
    case connectGroup = 2
    case otherGroup = 3
}

struct PrimaryCellGroupModel {
    
    /// 区分是哪一组
    var group = PrimaryCellGroupType.importGroup
    
    /// 头部标题
    var headTitle: String?
    
    /// 数据源
    var itemArray: [PrimaryCellItemType] = []
    
    /// 底部文字
    var footTitle: String?
    
}

enum PrimaryCellItemType: String {
    
    case allMusics = "allMusics"
    case artist = "artist"
    case album = "album"
    case genre = "genre"
    case download = "download"
    case connect = "connect"
    
    case selectEngine = "selectEngine"
    case guideiOS = "guideiOS"
    case settings = "settings"
    
    func titleStr() -> String? {
        switch self {
            
        case .allMusics:
            return KakaTabbarType.musics.formatStr()
        case .artist:
            return CollectionType.artist.titleStr()
        case .album:
            return CollectionType.album.titleStr()
        case .genre:
            return CollectionType.genre.titleStr()
        case .download:
            return "Download".localStr()
            
        case .connect:
            return KakaTabbarType.connect.formatStr()
            
        case .selectEngine:
            return "Playback Engine".localStr()
        case .guideiOS:
            return "Download for iOS".localStr()
        case .settings:
            return KakaTabbarType.profile.formatStr()
        }
    }
    
    func cellImage() -> UIImage? {
                
        switch self {
            
        case .allMusics:
            return UIImage(systemName: "music.note.house")
        case .artist:
            return MusicActionType.artist.iconImage()
        case .album:
            return MusicActionType.album.iconImage()
        case .genre:
            return CollectionType.genre.iconImage()
        case .download:
            return MusicActionType.download.iconImage()
            
        case .connect:
            return KakaTabbarType.connect.normalImage()
            
        case .selectEngine:
            return UIImage(systemName: "play.rectangle")
        case .guideiOS:
            if #available(iOS 16.1, *) {
                return UIImage(systemName: "macbook.and.iphone")
            }else{
                return UIImage(systemName: "iphone")
            }
        case .settings:
            return KakaTabbarType.profile.normalImage()
        }
        
    }
    
}

