//
//  MusicGenreType.swift
//  Mobie
//
//  Created by 张文 on 12/7/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaTaglibKit
import SmartCodable

/// 音乐流派枚举
public enum MusicGenreType: String, SmartCaseDefaultable {
    case pop = "Pop" // 流行
    case rock = "Rock" // 摇滚
    case blues = "Blues" // 蓝调
    case jazz = "Jazz" // 爵士
    case country = "Country" // 乡村
    case classical = "Classical" // 古典
    case hipHop = "Hip-Hop" // 嘻哈
    case electronic = "Electronic" // 电子
    case reggae = "Reggae" // 雷鬼
    case metal = "Metal" // 金属
    case rnb = "R&B" // 节奏布鲁斯
    case soul = "Soul" // 灵魂
    case punk = "Punk" // 朋克
    case folk = "Folk" // 民谣
    case latin = "Latin" // 拉丁
    case kpop = "K-Pop" // 韩流
    case podcast = "Podcast" // 播客
    case audiobook = "Audiobook" // 电子书
    case gameSoundtrack = "Game" // 游戏原声
    case soundtracks = "Soundtracks" // 影视原声
    case house = "Mouse" // House音乐
    case indie = "Indie" // 独立音乐
    case disco = "Disco" // 迪斯科
    case ambient = "Ambient" // 氛围音乐
    case opera = "Opera" // 歌剧
    case gospel = "Gospel" // 福音
    case other = "Others" // 其他未知
    
    static func allGenreArray() -> [MusicGenreType] {
//        return [.pop, .rock, .blues, .country, .folk, .hipHop, .jazz, .rnb, .disco, .indie, .kpop, .electronic, .audiobook, .gameSoundtrack, .house, .podcast, .opera, .ambient, .punk, .reggae, .metal, .soundtracks, .classical, .latin, .soul, .gospel]
        return MusicGenreType.allCases
    }
    
    
    static func initGenre(_ string: String) -> MusicGenreType? {
        if let genre = MusicGenreType(rawValue: string) {
            return genre
        }
                
        // 如果大小写不一致，尝试忽略大小写并匹配
        let lowercaseString = string.lowercased()
        var musicGenre: MusicGenreType?
        
        for subGenre in Self.allGenreArray() {
            if lowercaseString.contains(subGenre.rawValue.lowercased()) {
                musicGenre = subGenre
            }
        }
        
        return musicGenre
        
    }
    
    func iconImage() -> UIImage? {
        let language = PhoneSetManager.formatLanguage()
        let isFozu = language == .chinese_simplified || language == .chinese_traditional || language == .japanese || language == .tailand
        switch self {
        case .pop:
            return UIImage(named: "Genre_pop")
        case .rock:
            return UIImage(named: "Genre_rock")
        case .jazz:
            return UIImage(named: "Genre_jazz")
        case .classical:
            return UIImage(named: "Genre_classical")
        case .hipHop:
            return UIImage(named: "Genre_HipHop")
        case .electronic:
            return UIImage(named: "Genre_electronic")
        case .blues:
            return UIImage(named: "Genre_blues")
        case .reggae:
            return UIImage(named: "Genre_reggae")
        case .country:
            return UIImage(named: "Genre_country")
        case .metal:
            return UIImage(named: "Genre_metal")
        case .rnb:
            return UIImage(named: "Genre_rnb")
        case .soul:
            return UIImage(named: "Genre_soul")
        case .punk:
            return UIImage(named: "Genre_punk")
        case .folk:
            return UIImage(named: "Genre_folk")
        case .latin:
            return UIImage(named: "Genre_latin")
        case .kpop:
            return UIImage(named: "Genre_kpop")
        case .soundtracks:
            return UIImage(named: "Genre_soundtracks")
        case .podcast:
            return UIImage(named: "Genre_podcast")
        case .audiobook:
            return UIImage(named: "Genre_books")
        case .gameSoundtrack:
            return UIImage(named: "Genre_game")
        case .indie:
            return UIImage(named: "Genre_indie")
        case .house:
            return UIImage(named: "Genre_house")
        case .disco:
            return UIImage(named: "Genre_disco")
        case .ambient:
            return UIImage(named: "Genre_ambient")
        case .opera:
            return UIImage(named: "Genre_opera")
        case .gospel:
            return UIImage(named: isFozu ? "Genre_pusa" : "Genre_Jesus")
        case .other:
            return UIImage(named: "Genre_other")
        }
    }

    func formatStr() -> String {
        if self == .other {
            return "Others".localStr().uppercased()
        }else{
            return self.rawValue.lowercased().localStr().uppercased()
        }
    }
}
