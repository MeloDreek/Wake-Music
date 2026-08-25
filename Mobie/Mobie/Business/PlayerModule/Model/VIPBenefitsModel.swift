//
//  VIPBenefitsModel.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/27.
//

import AppGroupKit


enum VIPBenefitsModel: CaseIterable {
    case allFormats
    case audioFingerprint
    case batchAutoEdit
    case allPlayerStyle
    case allCloudDrive
    case lyricFeature
    case advancedSetting
    case allAppleOS
    case newMore
    
    
    func titleStr() -> String {
        switch self {
        case .allFormats:
            return "All Audio Formats".localStr()
        case .audioFingerprint:
            return "Audio Fingerprint".localStr()
        case .batchAutoEdit:
            return "Batch Auto-Embed".localStr()
        case .allPlayerStyle:
            return "All Player Themes".localStr()
        case .allCloudDrive:
            return "All Cloud Services".localStr()
        case .lyricFeature:
            return "Lyrics".localStr()
        case .advancedSetting:
            return "Premium Customization".localStr()
        case .allAppleOS:
            return "Across All Your Apple Devices".localStr()
        case .newMore:
            return "More Advanced Features".localStr()
        }
    }
    
    func descStr() -> String {
        switch self {
        case .allFormats:
            return "Full-format playback engine, supporting audio formats unsupported by Apple Music. E.g., DSD (DSF, DFF), DTS, APE, OGG, OPUS, WMA, S3M, TTA, MOD, WV, etc.".localStr()
        case .audioFingerprint:
            return "Auto-identify music metadata via audio fingerprinting and embed into tags".localStr()
        case .batchAutoEdit:
            return "Auto-repair music tags in bulk via audio fingerprinting to complete missing metadata".localStr()
        case .allPlayerStyle:
            return "All player styles, including Vinyl, Cassette, Custom Backgrounds, and more".localStr()
        case .allCloudDrive:
            return "Connect to your remote music limitlessly, saving local storage. E.g., WebDAV, Navidrome, and more".localStr()
        case .lyricFeature:
            return "Complete Lyrics Experience".localStr()
        case .advancedSetting:
            return "Premium customization options, including dynamic animations, advanced audio engine, and more.".localStr()
        case .allAppleOS:
            return "One-time purchase. Unlock all features on iPhone, iPad, and Mac.".localStr()
        case .newMore:
            return "All future premium features! E.g., Apple Watch, native CarPlay, more cloud storage, and more".localStr()
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
            
        case .audioFingerprint:
            return Reasource.systemNamed("touchid", color: .label, config: imageConfig)
        case .batchAutoEdit:
            return Reasource.systemNamed("pencil.and.outline", color: .label, config: imageConfig)
        case .lyricFeature:
            return Reasource.systemNamed("quote.opening", color: .label, config: imageConfig)
        case .advancedSetting:
            return Reasource.systemNamed("switch.2", color: .label, config: imageConfig)
        case .newMore:
            return Reasource.systemNamed("ellipsis.rectangle", color: .label, config: imageConfig)
        }
    }
    
}
