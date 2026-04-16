//
//  MiniPlayerStyle+Extension.swift
//  Mobie
//
//  Created by 张文 on 10/29/24.
//

import AppGroupKit
import KSPlayer

extension MiniPlayerStyle {
    func formatStr() -> String {
        switch self {
        case .toolbarUI:
            return "Bottom Toolbar".localStr()
        case .floatUI:
            return "Classic MP3 Style".localStr()
        }
    }
    
    func iconImage() -> UIImage? {
        switch self {
        case .toolbarUI:
            return UIImage(systemName: "slider.horizontal.below.rectangle")
        case .floatUI:
            return UIImage(systemName: "candybarphone")
        }
    }
}

extension LyricSortStyle {
    func formatStr() -> String {
        switch self {
        case .dontShow:
            return "Don't show".localStr()
        case .firstLine:
            return "Line 1".localStr()
        case .secondLine:
            return "Line 2".localStr()
        }
    }
}

extension PlayerEngineType {
    
    func titleStr() -> String {
        switch self {
        case .avPlayer:
            return "System AVPlayer".localStr()
        case .wakePlayer:
            return "All-Format Player".localStr()
        case .autoPlayer:
            return "Auto".localStr()
        }
    }
    
    func descStr() -> String {
        switch self {
        case .avPlayer:
            return "Only the built-in AVPlayer is used for decoding. This is the same playback engine used by Apple Music, delivering top-tier sound quality. However, AVPlayer cannot decode most music formats, and even when it does, it cannot retrieve embedded cover art or lyrics from remote files.".localStr()
        case .wakePlayer:
            return "Decoding is handled entirely by the full-format playback engine. It supports all music formats, including DSD (DSF, DFF), DTS, APE, OGG, OPUS, WMA, S3M, TTA, MOD, WV, and more. It can also read embedded cover art and lyrics from remote files.".localStr()
        case .autoPlayer:
            return "AVPlayer, the system’s built-in engine, is used by default. If AVPlayer fails to play the file, it will automatically switch to the full-format player. Note: Even if AVPlayer succeeds, it may not be able to extract embedded cover art or lyrics from remote files.".localStr()
        }
    }
    
    func engineTypes() -> [MediaPlayerProtocol.Type]  {
        switch self {
        case .avPlayer:
            return [KSAVPlayer.self]
        case .wakePlayer:
            return [KSMEPlayer.self]
        case .autoPlayer:
            return [KSAVPlayer.self, KSMEPlayer.self]
        }
    }
    
}
