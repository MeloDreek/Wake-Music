//
//  KakaApplication.swift
//  KakaFoundation
//
//  Created by 张文 on 8/12/25.
//

import Foundation

/// 我的应用程序
public enum Application: Int {
    case wakeMusic = 0
    case musicTag = 1
    case playlistPort = 2
    
    /// 应用程序ID
    public func appstoreID() -> String {
        
        let bundleID = (Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String) ?? ""
        let isProTarget = bundleID.contains("pro")
        
        switch self {
        case .wakeMusic:
            return isProTarget ? "6740429002" : "6544783918"
        case .musicTag:
            return isProTarget ? "6743993728" : "6738013677"
        case .playlistPort:
            return isProTarget ? "6749791601" : "6749790210"
        }
    }
    
    /// 共享容器的键
    public func sharedGroupName() -> String {
        let bundleID = (Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String) ?? ""
        let isProTarget = bundleID.contains("pro")
        
        switch self {
        case .wakeMusic:
            return isProTarget ? "group.com.OfflineMusic.www.pro" : "group.com.OfflineMusic.www"
        case .musicTag:
            return isProTarget ? "group.com.musictag.www.pro" : "group.com.musictag.www"
        case .playlistPort:
            return isProTarget ? "group.com.PlaylistPort.www.pro" : "group.com.PlaylistPort.www"
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
    
}
