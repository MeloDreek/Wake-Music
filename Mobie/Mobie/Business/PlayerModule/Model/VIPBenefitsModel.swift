//
//  VIPBenefitsModel.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/27.
//

import AppGroupKit


enum VIPBenefitsModel: CaseIterable {
    case allFormats
    case allPlayerStyle
    case allCloudDrive
    case allAppleOS
    
    case searchCoverAI
    case searchLyricAI
    case musicTagEditor
    case downloadCache
    case lyricFeature
    case advancedSetting
    case editVideoToMP3
    case themeColor
    case appLogo
    case newMore
    
    func titleStr() -> String {
        switch self {
        case .allFormats:
            return "All Music Formats".localStr()
        case .allPlayerStyle:
            return "All Player Styles".localStr()
        case .allCloudDrive:
            return "All Cloud Drive".localStr()
        case .allAppleOS:
            return "All Apple Devices".localStr()
            
        case .searchCoverAI:
            return MusicActionType.searchCoverAI.formatStr()
        case .searchLyricAI:
            return MusicActionType.searchLyricAI.formatStr()
        case .musicTagEditor:
            return "Music Tag Editor".localStr()
        case .downloadCache:
            return SettingCellItemType.cacheConfig.titleStr() ?? ""
        case .lyricFeature:
            return "Lyrics".localStr()
        case .advancedSetting:
            return "Advanced Settings".localStr()
        case .editVideoToMP3:
            return ImportFileType.fromVideos.titleStr()
        case .themeColor:
            return SettingCellItemType.appTintColor.titleStr() ?? ""
        case .appLogo:
            return SettingCellItemType.applogo.titleStr() ?? ""
        case .newMore:
            return "More Advanced Features".localStr()
        }
    }
    
    func descStr() -> String {
        switch self {
        case .allFormats:
            return "A more powerful player engine that supports music formats that Apple Music cannot decode, such as DSD (DSF, DFF), DTS, APE, OGG, OPUS, WMA, S3M, TTA, MOD, WV etc.".localStr()
        case .allPlayerStyle:
            return "All player styles including Vinyl, Cassette, custom backgrounds, etc.".localStr()
        case .allCloudDrive:
            return "Connect your remote music without taking up local disc space. For example, WebDav(Cloud Drive) and Navidrome, etc.".localStr()
        case .allAppleOS:
            return "Purchase now to unlock all Apple devices, including iPhone, iPad, Mac, as well as the upcoming Apple Watch, Apple TV, and CarPlay.".localStr()
            
        case .downloadCache:
            return CacheGroupCellItem.header.titleStr()
        case .searchCoverAI:
            return "Search album art with AI and embed it into local music files".localStr()
        case .searchLyricAI:
            return "Search lyric with AI and embed it into local music files".localStr()
        case .musicTagEditor:
            return "Complete music tag editor that supports parsing and editing embedded music tags such as title, artist, album, cover, lyrics, etc.".localStr()
        case .lyricFeature:
            return "Automatically parse the lyrics embedded in the file, support adding, editing, deleting, and following the playback".localStr()
        case .advancedSetting:
            return "Some advanced settings such as animations, music player, etc.".localStr()
        case .editVideoToMP3:
            return "Lossless audio format with automatic cropping of the last 3 seconds.".localStr()
        case .themeColor:
            return "Customize your favorite accent color".localStr()
        case .appLogo:
            return "Select your favorite desktop icon".localStr()
        case .newMore:
            return "Unlock all premium features at the lowest ever early bird price! Future price increases or adjustments to the subscription-only also do not affect your benefits.".localStr()
        }
    }

    func iconImage(_ maxSize: CGFloat) -> UIImage? {
        let imageConfig = UIImage.SymbolConfiguration(pointSize: maxSize, weight: .medium)
        switch self {
        case .allFormats:
            return Reasource.systemNamed("waveform", color: .label, config: imageConfig)
        case .allPlayerStyle:
            return Reasource.systemNamed("pause.rectangle", color: .label, config: imageConfig)
        case .allCloudDrive:
            return Reasource.systemNamed("externaldrive.badge.wifi", color: .label, config: imageConfig)
        case .allAppleOS:
            return Reasource.systemNamed("applelogo", color: .label, config: imageConfig)
            
        case .downloadCache:
            return Reasource.systemNamed("square.and.arrow.down", color: .label, config: imageConfig)
        case .searchCoverAI:
            if #available(iOS 16.0, *) {
                return Reasource.systemNamed("photo.stack", color: .label, config: imageConfig)
            }else{
                return Reasource.systemNamed("photo.on.rectangle", color: .label, config: imageConfig)
            }
        case .searchLyricAI:
            return Reasource.systemNamed("text.quote", color: .label, config: imageConfig)
        case .musicTagEditor:
            return Reasource.systemNamed("tag", color: .label, config: imageConfig)
        case .lyricFeature:
            return Reasource.systemNamed("quote.opening", color: .label, config: imageConfig)
        case .advancedSetting:
            return Reasource.systemNamed("switch.2", color: .label, config: imageConfig)
        case .editVideoToMP3:
            if #available(iOS 17.0, *) {
                return Reasource.systemNamed("video.badge.waveform", color: .label, config: imageConfig)
            }else{
                return Reasource.systemNamed("photo.on.rectangle", color: .label, config: imageConfig)
            }
        case .themeColor:
            if #available(iOS 16.0, *) {
                return Reasource.systemNamed("swatchpalette", color: .label, config: imageConfig)
            }else{
                return Reasource.systemNamed("paintpalette", color: .label, config: imageConfig)
            }
        case .appLogo:
            return Reasource.systemNamed("square.on.square", color: .label, config: imageConfig)
        case .newMore:
            return Reasource.systemNamed("ellipsis.rectangle", color: .label, config: imageConfig)
        }
    }
    
}
