//
//  KakaApplication.swift
//  KakaFoundation
//
//  Created by 张文 on 8/12/25.
//

import Foundation

/// 我的应用程序
public enum Application: Int, CaseIterable {
    case wakeMusic = 0
    case wakeTag = 1
    case playlistPort = 2
    case photoVault = 3
    case passLock = 4
    case vid2Audio = 5
    
    /// 应用程序ID
    public func appstoreID() -> String {
        
        let bundleID = (Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String) ?? ""
        let isProTarget = bundleID.contains("pro")
        
        switch self {
        case .wakeMusic:
            return isProTarget ? "6740429002" : "6544783918"
        case .wakeTag:
            return isProTarget ? "6743993728" : "6738013677"
        case .playlistPort:
            return isProTarget ? "6749791601" : "6749790210"
        case .photoVault:
            return "6476168171"
        case .passLock:
            return "1669178334"
        case .vid2Audio:
            return "6756813177"
        }
    }
    
    /// 共享容器的键
    public func sharedGroupName() -> String {
        let bundleID = (Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String) ?? ""
        let isProTarget = bundleID.contains("pro")
        
        switch self {
        case .wakeMusic:
            return isProTarget ? "group.com.OfflineMusic.www.pro" : "group.com.OfflineMusic.www"
        case .wakeTag:
            return isProTarget ? "group.com.musictag.www.pro" : "group.com.musictag.www"
        case .playlistPort:
            return isProTarget ? "group.com.PlaylistPort.www.pro" : "group.com.PlaylistPort.www"
        case .photoVault:
            return "group.com.PrivatePhotoVault.www"
        case .passLock:
            return "group.sharepassword.PassLock"
        case .vid2Audio:
            return "6756813177"
        }
    }
    
    /// 应用商店URL
    public func appstoreURL() -> URL {
        let iosURL = "https://apps.apple.com/app/id\(self.appstoreID())"
        let macURL = "itms-apps://itunes.apple.com/app/id\(self.appstoreID())"
        
        let pathStr = kaka_IsMacOS() ? macURL : iosURL
        
        return URL(string: pathStr) ?? URL(fileURLWithPath: "")
    }
    
    /// 评论地址URL
    public func appstoreWriteURL() -> URL {
        let iosURL = "https://apps.apple.com/app/id\(self.appstoreID())?action=write-review"
        let macURL = "itms-apps://itunes.apple.com/app/id\(self.appstoreID())?action=write-review"
        
        let pathStr = kaka_IsMacOS() ? macURL : iosURL
        
        return URL(string: pathStr) ?? URL(fileURLWithPath: "")
    }
    
    /// 是否已下载
    public func isInstalled() -> Bool {
        let UD = UserDefaults(suiteName: self.sharedGroupName()) ?? UserDefaults.standard
        guard let userJson = (UD.object(forKey: "kUserInfoKey") as? String), !userJson.isEmpty else {
            return false
        }
        
        return true
    }
    
    /// 名称
    public func appTitle() -> String {
        switch self {
        case .wakeMusic:
            return "Wakemusic".localStr()
        case .wakeTag:
            return "Waketag".localStr()
        case .playlistPort:
            return "PlaylistPort".localStr()
        case .photoVault:
            return "Kakabox".localStr()
        case .passLock:
            return "PassLock".localStr()
        case .vid2Audio:
            return "Vid2Audio".localStr()
        }
    }
    
    /// 描述
    public func appDesc() -> String {
        switch self {
        case .wakeMusic:
            return "Ultimate Music Player".localStr()
        case .wakeTag:
            return "Music Tag Editor".localStr()
        case .playlistPort:
            return "Easily Transfer Your Favourite Playlists".localStr()
        case .photoVault:
            return "Hide your private photos and videos".localStr()
        case .passLock:
            return "Encrypt your important files and passwords".localStr()
        case .vid2Audio:
            return "MP3 Converter".localStr()
        }
    }
    
    public func appLogo() -> UIImage? {
        switch self {
        case .wakeMusic:
            return UIImage(named: "app_wakeMusic")
        case .wakeTag:
            return UIImage(named: "app_musicTag")
        case .playlistPort:
            return UIImage(named: "app_playlistPort")
        case .photoVault:
            return UIImage(named: "app_photoVault")
        case .passLock:
            return UIImage(named: "app_passLock")
        case .vid2Audio:
            return UIImage(named: "app_vid2Audio")
        }
    }
    
    /// 二维码
    public func qrcodeImage() -> UIImage? {
        switch self {
        case .wakeMusic:
            return UIImage(named: "app_wakeMusic_qr")
        case .wakeTag:
            return UIImage(named: "app_musicTag_qr")
        case .playlistPort:
            return UIImage(named: "app_playlistPort_qr")
        case .photoVault:
            return UIImage(named: "app_photoVault_qr")
        case .passLock:
            return UIImage(named: "app_passLock_qr")
        case .vid2Audio:
            return UIImage(named: "app_vid2Audio_qr")
        }
    }
    
}
