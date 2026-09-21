//
//  MusicSceneType.swift
//  Mobie
//
//  Created by 张文 on 5/9/25.
//

import KakaFoundation

enum MusicCellType: Int {
    case none = 0
    case local = 1
    case download = 2
    case cloudDrive = 3
    
    case navidromeTrack = 4
    case navArtistDetial = 5
    case navPlaylistDetial = 6
    
    
    func iconImage() -> UIImage? {
        switch self {
        case .none:
            return nil
        case .download:
            return MusicActionType.download.iconImage()
        case .local, .cloudDrive, .navidromeTrack, .navArtistDetial, .navPlaylistDetial:
            return Reasource.systemNamed(kaka_IsMacOS() ? "ellipsis.circle" : "ellipsis")
        }
    }
    
}
