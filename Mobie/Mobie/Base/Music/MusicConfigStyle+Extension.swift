//
//  MusicConfigStyle+Extension.swift
//  Mobie
//
//  Created by 张文 on 10/29/24.
//

import AppGroupKit
import KSPlayer

extension LyricSortStyle {
    func formatStr() -> String {
        switch self {
        case .dontShow:
            return "Don’t Show".localStr()
        case .firstLine:
            return "First Line".localStr()
        case .secondLine:
            return "Line 2".localStr()
        }
    }
}

extension PlayerEngineType {
    
    func titleStr() -> String {
        switch self {
        case .avPlayer:
            return "Apple Audio Engine".localStr()
        case .wakePlayer:
            return "All-Format Audio Engine".localStr()
        case .autoPlayer:
            return "Auto".localStr()
        }
    }
    
    func descStr() -> String {
        switch self {
        case .avPlayer:
            return "Use only Apple's built-in AVPlayer for playback. It is also the playback engine used by Apple Music and delivers excellent audio quality. However, AVPlayer cannot decode most music formats, and even when playback succeeds, it cannot read embedded cover art or lyrics from remote files.".localStr()
        case .wakePlayer:
            return "Use only the All-Format Audio Engine for decoding. It can parse embedded artwork and lyrics from remote files and supports all music formats, including DSD (DSF, DFF), DTS, APE, OGG, OPUS, WMA, S3M, TTA, MOD, WV, and more.".localStr()
        case .autoPlayer:
            return "Prefer Apple's built-in AVPlayer. If AVPlayer fails to play a file, playback will automatically switch to the All-Format Audio Engine. If AVPlayer successfully decodes the file, this mode may not be able to read embedded artwork and lyrics from remote files.".localStr()
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
