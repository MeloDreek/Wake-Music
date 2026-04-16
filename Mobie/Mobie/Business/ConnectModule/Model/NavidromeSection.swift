//
//  ConnectCellSection.swift
//  Mobie
//
//  Created by 张文 on 3/1/25.
//

import AppGroupKit

enum ConnectCellSection: Int {
    case topSection = 0
    case starredSongs = 1
    case myPlaylists = 2
    case todayRandom = 3
    
    case rootDic = 4
    case folders = 5
    case musics = 6
    
    
    func titleStr(_ navUser: NavidromeUserModel?) -> String? {
        switch self {
        case .topSection:
            return "Artist".localStr()
        case .starredSongs:
            return "Favourite Songs".localStr()
        case .myPlaylists:
            return "My Playlists".localStr()
        case .todayRandom:
            let isLargeServer = navUser?.isLargeServer ?? false
            return isLargeServer ? "Random Songs".localStr() : "All Music".localStr()
            
        case .rootDic:
            return nil
        case .folders:
            return "♥ " + "Folder".localStr()
        case .musics:
            return "♥ " + "Songs".localStr()
        }
    }
    
}
