//
//  AutoEditConfig.swift
//  Mobie
//
//  Created by kaka on 2026/8/12.
//

import Foundation
import AppGroupKit

enum FillModeType: Int {
    case fillEmptyOnly = 0
    case forceOverwrite = 1
    
    func titleStr() -> String {
        switch self {
        case .fillEmptyOnly:
            return "Fill empty only".localStr()
        case .forceOverwrite:
            return "Force overwrite".localStr()
        }
    }
}

enum FileNameType: Int, CaseIterable {
    case `default` = 0
    case title = 1
    case artist_title = 2
    case title_artist = 3
    
    func titleStr() -> String {
        switch self {
        case .default:
            return "Default".localStr()
        case .title:
            return MusicTagType.title.titleStr() + ".mp3"
        case .artist_title:
            return MusicTagType.artist.titleStr() + " - " + MusicTagType.title.titleStr() + ".mp3"
        case .title_artist:
            return MusicTagType.title.titleStr() + " - " + MusicTagType.artist.titleStr() + ".mp3"
        }
    }
    
}

enum AutoEditConfigType: Int {
    case fillmodeType = 0
    case fileNameType
    case lyricEditType
    case batchAutoEditBtn
    case upgradeLifetime
    
    func titleStr() -> String {
        switch self {
        case .fillmodeType:
            return "Fill Mode".localStr()
        case .fileNameType:
            return "File Name".localStr()
        case .lyricEditType:
            return MusicTagType.lyrics.titleStr()
        
        case .batchAutoEditBtn:
            return "Batch Auto-Embed".localStr()
        case .upgradeLifetime:
            return "★ " + "Upgrade to Lifetime".localStr()
        }
    }
    
    func secondsStr() -> String? {
        switch self {
        case .fillmodeType:
            return nil
        case .fileNameType:
            return nil
        case .lyricEditType:
            return "Set lyrics tag to Instrumental when no match is found".localStr()
            
        case .batchAutoEditBtn:
            return nil
        case .upgradeLifetime:
            return nil
        }
    }
    
    func footerStr() -> String? {
        switch self {
        case .fillmodeType:
            return nil
        case .fileNameType:
            return nil
        case .lyricEditType:
            return nil
            
        case .batchAutoEditBtn:
            let audioArray = AudioExtensionType.supportAutoEditArray.map {
                $0.rawValue.uppercased()
            }
            
            return "Formats supporting audio fingerprinting:".localStr() + audioArray.joined(separator: ", ")
        case .upgradeLifetime:
            return "Complimentary quota of 10 auto-identified and embedded audio fingerprint files during free trial, Lifetime Premium is recommended for immediate full library cleaning".localStr()
        }
    }
}

struct AutoEditConfig {
    
    /// 填充模式
    var fillMode = FillModeType.fillEmptyOnly
    
    /// 文件名称格式
    var fileName: FileNameType = .default
    
    /// 无歌词时，是否设置为纯音乐
    var isSetInstrumental: Bool = true
}

