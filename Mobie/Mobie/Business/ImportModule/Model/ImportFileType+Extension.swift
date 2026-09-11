//
//  ImportFileType.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2024/6/25.
//


import KakaFoundation
import SmartCodable
import AppGroupKit

/*
 1、本地（文件、文件夹、视频转音乐）
 2、计算机（USB、Wi-Fi）
 3、连接（Webdav、Navidrome、FTP、各大网盘）
 */

enum ImportGroupType: Int {
    case localGroup = 0
    case computerGroup = 1
    case serverGroup = 2
    case driveGroup = 3
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
    /// 图标名称
    public func iconImage() -> UIImage? {
        switch self {
    
        case .demoFile: return nil
        case .localFile: return nil
        case .fromFile:
            return UIImage(systemName: "doc.on.doc")
        case .fromFolder:
            return UIImage(systemName: "folder")
        case .fromApple:
            return UIImage(systemName: "applelogo")
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
            
        case .fromWebDav:
            return Reasource.named("Import_webdav")
        case .fromNavidrome:
            return Reasource.named("Import_navidrome")
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
        case .fromApple:
            return "Apple Music"
        case .fromVideos:
            return "Video to Music".localStr()
            
        case .fromUSB:
            return "USB"
        case .fromWiFi:
            return "WiFi".localStr()
            
        case .fromWebDav:
            return "WebDAV"
        case .fromNavidrome:
            return "Navidrome"
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
        case .fromDropboxDrive:
            return "Dropbox"
        case .fromYandexDrive:
            return "Yandex.disk"
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
        return [.fromWebDav, .fromNavidrome]
    }
    
    // 可用的网盘服务
    static func cloudDriveArray() -> [ImportFileType] {
        let language = PhoneSetManager.formatLanguage()
        
#if canImport(MSAL)
        let commonArray: [ImportFileType] = [.fromGoogleDrive, .fromDropboxDrive, .fromOneDrive, .fromePCloud, .fromBoxDrive]
#else
        let commonArray: [ImportFileType] = [.fromGoogleDrive, .fromDropboxDrive, .fromePCloud, .fromBoxDrive]
#endif
        let chineseArray: [ImportFileType] = [.fromBaiduDrive, .fromAliyunDrive, .from115Drive]
        let russaArray: [ImportFileType] = []
        
        switch language {
        case .chinese_simplified:
            return chineseArray + commonArray + russaArray
        case .chinese_traditional:
            return commonArray + chineseArray + russaArray
        case .russian:
            return russaArray + commonArray + chineseArray
        default:
            return commonArray + russaArray + chineseArray
        }
    }
    
}
    
