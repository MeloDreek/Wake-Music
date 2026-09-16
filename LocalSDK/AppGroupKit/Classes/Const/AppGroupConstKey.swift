//
//  AppGroupConstKey.swift
//  AppGroupKit
//
//  Created by Kaka Inc. on 2023/11/30.
//

import KakaObjcKit
import KakaFoundation


// JSON
public let kUserInfoKey = StringEncoder.userJsonKey()

// 默认头像名称
public let avatarDefaultName = "user_place"

// 应用包名
public let AppBundleID = "com.OfflineMusic.www"

// 量江湖的key
public let LiangjianghuKey = "Pl45uU41UU9UjI6zes7yx1WqG6PyQzgj3BI4P0M0"

// 百度网盘配置
public let BaiduDriveAppKey = "ZYJ2Gq1u2F0WmxjVyZbo1g1VpGOPmInJ"
public let BaiduDriveRedirectURL = "oob"
public var BaiduDriveAuthURL: String {
    get {
        var display = "mobile"
        switch kaka_osType() {
        case .iOS: display = "mobile"
        case .iPadOS: display = "mobile"
        case .macOS: display = "mobile"
        }
        return String(format: "https://openapi.baidu.com/oauth/2.0/authorize?response_type=token&client_id=%@&redirect_uri=%@&scope=basic,netdisk&display=\(display)", BaiduDriveAppKey, BaiduDriveRedirectURL)
    }
}


// 谷歌网盘的配置
public let Google_Client_ID = "749270844204-1dejm1lm56j8c92brmb1qbq363hklpfb.apps.googleusercontent.com"
public let Google_Client_Secret = "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"
public let Google_Scopes = [
    "https://www.googleapis.com/auth/drive.readonly"]


// DropBox
public let DropBox_ApiKey = "ivt8gleyydx2ghj"
public let DropBox_Secret = "p7wnvf86pbnsoqn"
public let DropBox_Scopes = [
    "account_info.read",
    "files.metadata.read",
    "files.content.read"
]


// OneDrive
public let OneDrive_ClientID = "e4941369-cd73-4f3c-8e48-c1404e373719"
public let OneDrive_Authority = "https://login.microsoftonline.com/common/oauth2/v2.0"
public let OneDrive_GraphEndpoint = "https://graph.microsoft.com/"
public let OneDrive_Scopes = ["User.Read", "Files.Read"]
public var OneDrive_RedirectUri: String {
    get {
        let bundleID = (Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String) ?? ""
        let redirectURL = "msauth.\(bundleID)://auth"
        return redirectURL
    }
}


// Yandex.disk
public let Yandex_ClientID = "a1414a229c0b43669e696cb3a7c9e683"
public let Yandex_Secret = "7ae6b8a2364146048a4eeed9e5ec1782"


// 阿里云盘
public let Aliyun_AppID = "3c283ba503b64aaa8d83a3ef4a7e28c5"
public let Aliyun_Secret = "2046784efa414183a24ae9a1290dd57f"
public let Aliyun_Scopes = "user:base,file:all:read"

// pCloud
public let pCloud_AppID = "A7jNL6xFoK4"
public let pCloud_RedirectURL = "pclsdk-w-a7jnl6xfok4"

// 115: client-side authorization is a consciously accepted product trade-off.
// A shipped application cannot keep this application secret confidential.
public let Drive115_ClientID = "100196055"
public let Drive115_ClientSecret = "03c66caf7a8ee03769a6258060bc3d6c"
// Intercepted by WKNavigationDelegate; no callback endpoint is deployed.
public let Drive115_RedirectURL = "https://passlockapp.com/oauth/115/callback"

// BOX
public let Box_ClientID = "4t1hcuwcq410dxxq1krq3364og8oudtj"
public let Box_ClientSecret = "Xh4skrn1UaDQgDfMhGbIbUJQZgtS77Q0"
public let Box_DevelopToken = "De4B3j1y3kCMYjQk5I0dqshQP2iZdwSq"
public let Box_RedirectURL = "wakemusic-box://oauth/callback"

// 光鸭云盘
public let Guangya_ClientID = "aSWjpgxuXCmz2SSn"
public let Guangya_ProjectID = "356jld6jjlbjvygi5v9"
public let Guangya_Secret = "123"
public let Guangya_RedirectURL = "wakemusic-guangya://oauth/callback"

// 123网盘
public let Drive123_RedirectURL = "wakemusic-123pan://oauth/callback"
