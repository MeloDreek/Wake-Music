//
//  MusicActionType.swift
//  Wake Music
//
//  Created by Melo on 7/26/24.
//

import KakaFoundation
import AppGroupKit

enum MusicActionType {
    
    case searchCoverAI
    case searchLyricAI
    case musictag
    case autoRecognize
    
    case play
    case addFavirote
    case removeFavirote
    case addPlaylist
    case removePlaylist
    
    case artistDetial
    case albumDetial

    case coverArt
    case title
    case artist
    case album
        
    case export
    
    case showInFinder
    case deleteItem
    case download
    
    func formatStr() -> String {
        switch self {
            
        case .searchCoverAI:
            return "Search Album Cover With AI".localStr()
        case .searchLyricAI:
            return "Search Lyric With AI".localStr()
        case .musictag:
            return "Music Tag".localStr()
        case .autoRecognize:
            return "Auto Recognize".localStr()
            
        case .play:
            return "Play".localStr()
        case .addFavirote:
            return "Favorite".localStr()
        case .removeFavirote:
            return "Dislike".localStr()
        case .addPlaylist:
            return "Add to Playlist".localStr()
        case .removePlaylist:
            return "Remove from Playlist".localStr()
            
        case .coverArt:
            return "Artwork".localStr()
        case .title:
            return "Title".localStr()
        case .artist, .artistDetial:
            return "Artist".localStr()
        case .album, .albumDetial:
            return "Album".localStr()
            
        case .export:
            return "Export".localStr()
            
        case .showInFinder:
            return "Show in Finder".localStr()
        case .deleteItem:
            return "Delete".localStr()
        case .download:
            return "Download".localStr()
        }
    }
    
    func iconImage() -> UIImage? {
        switch self {
            
        case .searchCoverAI:
            return MusicTopMode.coverLibrary.iconImage()
        case .searchLyricAI:
            return MusicTopMode.lyricLibrary.iconImage()
        case .musictag:
            return Reasource.systemNamed("tag")
        case .autoRecognize:
            return Reasource.systemNamed("tag")
            
        case .play:
            return Reasource.systemNamed("play")
        case .addFavirote:
            return Reasource.systemNamed("heart")
        case .removeFavirote:
            return Reasource.systemNamed("heart.fill")
        case .addPlaylist:
            return Reasource.systemNamed("music.note.list")
        case .removePlaylist:
            return Reasource.systemNamed("minus.circle")
            
        case .coverArt:
            return UserInfoManager.shared.isVIP() ? UIImage(systemName: "photo.on.rectangle") : UIImage(named: "pro_crown")
        case .title:
            return UIImage(systemName: "at")
        case .artist, .artistDetial:
            return UIImage(systemName: "person.crop.rectangle.stack")
        case .album, .albumDetial:
            return UIImage(systemName: "rectangle.stack")
            
        case .export:
            return UIImage(systemName: "square.and.arrow.up")
            
        case .showInFinder:
            return UIImage(systemName: "location.fill.viewfinder")
        case .deleteItem:
            return UIImage(systemName: "trash")
        case .download:
            return UIImage(systemName: "icloud.and.arrow.down")
        }
    }
}
