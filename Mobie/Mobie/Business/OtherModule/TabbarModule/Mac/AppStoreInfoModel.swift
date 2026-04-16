//
//  AppStoreInfoModel.swift
//  Mobie
//
//  Created by 张文 on 5/7/25.
//

import SmartCodable

/// App Store上的应用信息
public struct AppStoreInfoModel: SmartCodable {
    
    public init() {
        
    }
    
    /// 版本号
    var version: String = ""
    
    /// 产品名称
    var trackName: String = ""
    
    /// 产品名称
    var trackCensoredName: String = ""

    /// 开发者主页链接
    var artistViewUrl: String = ""
    
    /// 512尺寸的LOGO链接
    var artworkUrl512: String = ""
    
    /// 屏幕截屏
    var screenshotUrls: [String] = []
    
    /// iPad屏幕截图
    var ipadScreenshotUrls: [String] = []
    
    /// 版本更新说明
    var releaseNotes: String = ""
    
    /// AppStore链接
    var trackViewUrl: String = ""
    
    /// 支持的语言
    var languageCodesISO2A: [String] = []
    
    /// 营销网站
    var sellerUrl: String = ""
    
    /// 新版本时间：2023-03-02T16:12:51Z
    var currentVersionReleaseDate: String = ""
    
    /// 描述
    var description: String = ""
    
}
