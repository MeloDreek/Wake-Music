//
//  ImportFileType.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2024/6/25.
//


import KakaFoundation
import SmartCodable
import AppGroupKit

enum ImportGroupType: Int {
    case localGroup = 0
    case remoteServerGroup = 1
    case remoteCloudGroup = 2

    var localizedTitle: String {
        switch self {
        case .localGroup:
            return "Local".localStr()
        case .remoteServerGroup:
            return "\("Remote".localStr()) - NAS & \("Server".localStr())"
        case .remoteCloudGroup:
            return "\("Remote".localStr()) - \("Cloud Drive".localStr())"
        }
    }
}

struct ImportGroupModel {
    
    /// 区分是哪一组
    var group = ImportGroupType.localGroup
    
    /// 头部标题
    var headTitle: String?
    
    /// 数据源
    var itemArray: [ImportFileType] = []
    
    /// 底部文字
    var footTitle: String?
    
}


extension ImportFileType {
    /// Selection hints, shared by Import and the empty Connect screen.
    /// Speed hints are relevant to Chinese-language users. They describe throttling,
    /// not unlimited traffic or a guarantee of real-world connection throughput.
    func connectionTags() -> [String] {
        let language = PhoneSetManager.formatLanguage()
        let showSpeed = language == .chinese_simplified || language == .chinese_traditional
        let speedTags = showSpeed ? ["ConnectionTag.NoSpeedLimit".localStr()] : []
        switch self {
        case .fromSMB: return ["NAS", "ConnectionTag.Computer".localStr(), "ConnectionTag.LocalNetwork".localStr()]
        case .fromFTP: return ["NAS", "Server".localStr(), "ConnectionTag.SelfHosted".localStr()]
        case .fromWebDAV: return ["NAS", "ConnectionTag.PrivateCloud".localStr(), "Cloud Drive".localStr()]
        case .fromNavidrome: return ["NAS", "ConnectionTag.MusicServer".localStr(), "ConnectionTag.SelfHosted".localStr()]
        case .fromGoogleDrive: return ["ConnectionTag.Free15GBShared".localStr()] + speedTags
        case .fromDropboxDrive: return ["ConnectionTag.Free2GB".localStr()] + speedTags
        case .fromOneDrive: return ["ConnectionTag.Free5GBShared".localStr()] + speedTags
        case .fromePCloud: return ["ConnectionTag.Unlock10GB".localStr()] + speedTags
        case .fromYandexDrive: return ["ConnectionTag.Free5GB".localStr()]
        case .fromBoxDrive: return ["ConnectionTag.Free10GB".localStr()] + speedTags
        case .fromMEGADrive: return ["MEGA.Free20GB".localStr(), "MEGA.TransferQuota".localStr()]
            
        case .fromBaiduDrive:
            return ["ConnectionTag.FreeUpTo2TB".localStr()] + (showSpeed ? ["ConnectionTag.PartialStreaming".localStr()] : [])
        case .fromAliyunDrive:
            return ["ConnectionTag.Free100GB".localStr()] + (showSpeed ? ["ConnectionTag.PartialStreaming".localStr()] : [])
        case .from123Drive:
            return ["ConnectionTag.FreeUpTo2TB".localStr(), "ConnectionTag.CDNAcceleration".localStr()] + speedTags
        case .from115Drive:
            return ["ConnectionTag.Free15GB".localStr(), "ConnectionTag.UpTo5PB".localStr()]
        case .fromGuangyaDrive:
            return ["Guangya.Free2TB".localStr()] + (showSpeed ? ["Guangya.ByXunlei".localStr()] : []) + speedTags
        case .fromYidongDrive:
            return ["移动用户免费40GB", "非移动用户免费20GB", "不限速"]
        default: return []
        }
    }

    /// 图标名称
    public func iconImage() -> UIImage? {
        switch self {
    
        case .demoFile: return nil
        case .localFile: return nil
        case .fromFile:
            return UIImage(systemName: "doc.on.doc")
        case .fromFolder:
            return UIImage(systemName: "folder")
        case .fromVideos:
            if #available(iOS 17.0, *) {
                return UIImage(systemName: "video.badge.waveform")
            }else{
                return UIImage(systemName: "arrow.up.right.video")
            }
            
            
        case .fromWiFi:
            return UIImage(systemName: "wifi")
        case .fromUSB:
            return UIImage(systemName: "cable.connector")
            
        case .fromWebDAV:
            return Reasource.named("Import_webdav")
        case .fromNavidrome:
            return MusicServerConnectionIcon.image
        case .fromSMB:
            return Reasource.named("Import_smb")
        case .fromFTP:
            return Reasource.named("Import_ftp")
        case .fromJellyfin:
            return Reasource.named("Import_jellyfin")
        case .fromEmby:
            return Reasource.named("Import_emby")
        case .fromPlex:
            return Reasource.named("Import_plex")
            
        case .fromGoogleDrive:
            return Reasource.named("Drive_google")
        case .fromOneDrive:
            return Reasource.named("Drive_onedrive")
        case .fromBoxDrive:
            return Reasource.named("Drive_box")
        case .fromMEGADrive:
            return Reasource.named("Drive_mega")
        case .fromDropboxDrive:
            return Reasource.named("Drive_dropbox")
        case .fromYandexDrive:
            return Reasource.named("Drive_yandex")
        case .fromBaiduDrive:
            return Reasource.named("Drive_baidu")
        case .fromAliyunDrive:
            return Reasource.named("Drive_aliyun")
        case .fromYidongDrive:
            return Reasource.named("Drive_yidong")
        case .fromTianyiDrive:
            return Reasource.named("Drive_tianyi")
        case .fromePCloud:
            return Reasource.named("Drive_pcloud")
            
        case .fromQuarkDrive:
            return Reasource.named("Drive_quark")
        case .from115Drive:
            return Reasource.named("Drive_115")
        case .from123Drive:
            return Reasource.named("Drive_123")
        case .fromGuangyaDrive:
            return Reasource.named("Drive_guangya")
        case .fromJianguoDrive:
            return Reasource.named("Drive_jianguo")
        case .fromInfiniCloud:
            return Reasource.named("Drive_InfiniCloud")
        case .fromOwnCloud:
            return Reasource.named("Drive_ownCloud")
        case .fromNextcloud:
            return Reasource.named("Drive_nextcloud")
        }
        
    }
    
    public func titleStr() -> String {
        switch self {
        
        case .demoFile: return "Wakemusic".localStr()
        case .localFile: return "Local".localStr()
        case .fromFile:
            return "File".localStr()
        case .fromFolder:
            return "Folder".localStr()
        case .fromVideos:
            return "Video to Music".localStr()
            
        case .fromUSB:
            return "USB"
        case .fromWiFi:
            return "WiFi".localStr()
            
        case .fromWebDAV:
            return "WebDAV"
        case .fromNavidrome:
            return "Navidrome/Subsonic"
        case .fromSMB:
            return "SMB"
        case .fromFTP:
            return "FTP"
        case .fromJellyfin:
            return "Jellyfin"
        case .fromEmby:
            return "Emby"
        case .fromPlex:
            return "Plex"
            
        case .fromGoogleDrive:
            return "Google Drive".localStr()
        case .fromOneDrive:
            return "OneDrive"
        case .fromBoxDrive:
            return "Box"
        case .fromMEGADrive:
            return "MEGA"
        case .fromDropboxDrive:
            return "Dropbox"
        case .fromYandexDrive:
            return "Yandex Disk"
        case .fromBaiduDrive:
            return "Baidu Drive".localStr()
        case .fromAliyunDrive:
            return "Aliyun Drive".localStr()
        case .fromYidongDrive:
            return "CMI mCloud".localStr()
        case .fromTianyiDrive:
            return "TianYi Drive".localStr()
        case .fromePCloud:
            return "pCloud"
        
        case .fromQuarkDrive:
            return "Quark Drive".localStr()
        case .from115Drive:
            return "115 Drive".localStr()
        case .from123Drive:
            return "123 Drive".localStr()
        case .fromGuangyaDrive:
            return "Guangya.Name".localStr()
        case .fromJianguoDrive:
            return "Jianguo Drive".localStr()
        case .fromInfiniCloud:
            return "InfiniCloud"
        case .fromOwnCloud:
            return "OwnCloud"
        case .fromNextcloud:
            return "Nextcloud"
        }
    }
    
    public func freeDiskStr() -> String? {
        switch self {
        case .fromGoogleDrive: return nil
        case .fromOneDrive: return nil
        case .fromBaiduDrive: return nil
        case .fromDropboxDrive: return nil
        case .from115Drive: return nil
        default: return nil
        }
    }
    
    // 可用的服务器
    static func serverDriveArray() -> [ImportFileType] {
        return [.fromNavidrome, .fromWebDAV, .fromSMB, .fromFTP]
    }
    
    // 可用的网盘服务
    static func cloudDriveArray() -> [ImportFileType] {
#if canImport(MSAL)
        let internationalArray: [ImportFileType] = [.fromGoogleDrive, .fromDropboxDrive, .fromOneDrive, .fromePCloud, .fromBoxDrive, .fromMEGADrive, .fromYandexDrive]
#else
        let internationalArray: [ImportFileType] = [.fromGoogleDrive, .fromDropboxDrive, .fromePCloud, .fromBoxDrive, .fromMEGADrive, .fromYandexDrive]
#endif
        let mainlandChinaArray: [ImportFileType] = [.from123Drive, .fromAliyunDrive, .fromBaiduDrive, .from115Drive, .fromGuangyaDrive]

        // The device region is more relevant here than the UI language: an
        // English-language user in China still needs the local services first.
        // Keep the international order as the default for all other regions.
        switch PhoneSetManager.localPhoneCountry() {
        case .chinese:
            return mainlandChinaArray + internationalArray
        case .russian:
            return [.fromYandexDrive] + internationalArray.filter { $0 != .fromYandexDrive } + mainlandChinaArray
        default:
            return internationalArray + mainlandChinaArray
        }
    }
    
}

/// Both services use the same compatible-protocol connection; this is branding only.
/// Keep each official mark intact and cache the composition rather than redrawing per row.
private enum MusicServerConnectionIcon {
    static let image: UIImage = {
        let navidrome = Reasource.named("Import_navidrome")
        let subsonic = Reasource.named("Import_subsonic")
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80), format: format).image { context in
            navidrome.draw(in: CGRect(x: 0, y: 0, width: 58, height: 58))
            let badge = CGRect(x: 23, y: 33, width: 57, height: 47)
            context.cgContext.saveGState()
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 2,
                                       color: UIColor.black.withAlphaComponent(0.15).cgColor)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: badge, cornerRadius: 10).fill()
            context.cgContext.restoreGState()
            // The official Subsonic mark is not square. Fit it without stretching or cropping.
            let inset = badge.insetBy(dx: 3, dy: 3)
            let aspect = subsonic.size.width / max(1, subsonic.size.height)
            let width = min(inset.width, inset.height * aspect)
            let height = width / aspect
            subsonic.draw(in: CGRect(x: inset.midX - width / 2, y: inset.midY - height / 2,
                                    width: width, height: height))
        }.withRenderingMode(.alwaysOriginal)
    }()
}
    
