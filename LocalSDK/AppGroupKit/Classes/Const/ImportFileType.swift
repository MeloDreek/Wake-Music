//
//  ImportFileType.swift
//  AppGroupKit
//
//  Created by 张文 on 12/24/24.
//

import SmartCodable

// ⚠️ 不能修改值
public enum ImportFileType: String, CaseIterable, SmartCaseDefaultable {
    
    case demoFile = "demoFile"
    
    case localFile = "localFile"
    case fromFile = "fromFile"
    case fromFolder = "fromFolder"
    case fromVideos = "fromVideos"
    
    case fromUSB = "fromUSB"
    case fromWiFi = "fromWiFi"
    
    case fromWebDAV = "fromWebDAV"
    case fromNavidrome = "fromNavidrome"
    case fromSMB = "fromSMB"
    case fromFTP = "fromFTP"
    case fromJellyfin = "fromJellyfin"
    case fromEmby = "fromEmby"
    case fromPlex = "fromPlex"
    
    case fromGoogleDrive = "fromGoogleDrive"
    case fromOneDrive = "fromOneDrive"
    case fromDropboxDrive = "fromDropboxDrive"
    case fromYandexDrive = "fromYandexDrive"
    case fromBaiduDrive = "fromBaiduDrive"
    case fromAliyunDrive = "fromAliyunDrive"
    case fromYidongDrive = "fromYidongDrive"
    case fromTianyiDrive = "fromTianyiDrive"
    case fromBoxDrive = "fromBoxDrive"
    case fromMEGADrive = "fromMEGADrive"
    case fromePCloud = "fromePCloud"
    
    case fromQuarkDrive = "fromQuarkDrive"
    case from115Drive = "from115Drive"
    case from123Drive = "from123Drive"
    case fromGuangyaDrive = "fromGuangyaDrive"
    case fromJianguoDrive = "fromJianguoDrive"
    case fromInfiniCloud = "fromInfiniCloud"
    case fromOwnCloud = "fromOwnCloud"
    case fromNextcloud = "fromNextcloud"
    
    public func isAvailble() -> Bool {
        if self == .fromMEGADrive || self == .from123Drive { return true }
        let isAvailble = self == .fromUSB || self == .fromFile || self == .fromFolder || self == .fromVideos || self == .fromWebDAV || self == .fromWiFi || self == .fromNavidrome || self == .fromBaiduDrive || self == .fromAliyunDrive || self == .from115Drive || self == .fromGoogleDrive || self == .fromDropboxDrive || self == .fromePCloud || self == .fromYandexDrive || self == .fromBoxDrive || self == .fromSMB || self == .fromGuangyaDrive
        
        return isAvailble
    }
    
    public static func welcomeArray() -> [ImportFileType] {
        let avaibleArray: [ImportFileType] = ImportFileType.allCases.filter { $0.isAvailble() }
        let importArray = avaibleArray.filter({ subType in
            return (subType != .demoFile) &&
            (subType != .fromFile) &&
            (subType != .fromVideos) &&
            (subType != .fromFolder) &&
            (subType != .fromUSB) &&
            (subType != .fromWiFi)
        })
        
        return importArray
    }
    
}

/*
 Google Drive、OneDrive、Dropbox、Yandex Disk、Box、pCloud、MEGA、InfiniCloud、Kakao Cloud、Never Cloud、百度网盘、阿里云盘、115网盘、123云盘、移动云盘、天翼云盘、腾讯微云
 */
