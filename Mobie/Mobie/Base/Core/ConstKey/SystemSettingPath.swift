//
//  SystemSettingPath.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2023/12/19.
//

import KakaFoundation

// 系统设置路径
enum SystemSettingPath: Int {
    case home = 0             // 设置主页
    case account = 1          // Apple ID主页，检测是否登录
    case iCloud = 2           // 检测iCloud是否开启
    case iCloudKeyChain = 3   // 检测iCloud Keychain是否开启
    case appleReport = 4      // Apple隐私报告
    case passwords = 5        // 引导密码自动填充扩展
    case vpn = 6              // VPN
    case network = 7          // 检查网络
    case appearance = 8       // 外观模式
    
    // 设置路径
    func settingPathStr() -> String {
        switch self {
        case .home:
            return kaka_IsMacOS() ? "x-apple.systempreferences:" : "App-Prefs:"
        case .account:
            return kaka_IsMacOS() ? "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane" : "App-Prefs:APPLE_ACCOUNT"
        case .iCloud:
            return kaka_IsMacOS() ? "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane?icloud" : "App-Prefs:APPLE_ACCOUNT&path=ICLOUD_SERVICE"
        case .iCloudKeyChain:
            return kaka_IsMacOS() ? "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane?icloud" : "App-Prefs:APPLE_ACCOUNT&path=ICLOUD_SERVICE/com.apple.Dataclass.KeychainSync"
        case .appleReport:
            return kaka_IsMacOS() ? "x-apple.systempreferences:com.apple.preference.security?General" : "App-Prefs:Privacy&path=PRIVACY_REPORT"
        case .passwords:
            return kaka_IsMacOS() ? "x-apple.systempreferences:com.apple.Passwords-Settings.extension" : "App-Prefs:PASSWORDS"
        case .vpn:
            return kaka_IsMacOS() ? "x-apple.systempreferences:com.apple.Network-Settings" : "App-Prefs:VPN"
        case .network:
            return kaka_IsMacOS() ? "x-apple.systempreferences:com.apple.Network-Settings" : "App-Prefs:WIFI"
        case .appearance :
            return kaka_IsMacOS() ? "x-apple.systempreferences:com.apple.Appearance" : "App-Prefs:APPEARANCE"
        }
    }
}
