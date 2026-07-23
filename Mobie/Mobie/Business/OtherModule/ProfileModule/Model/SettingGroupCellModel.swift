//
//  SettingGroupCellModel.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/19.
//

import KakaFoundation

enum SettingCellGroupType: Int {
    case unLoginGroup = 0    // 未登录
    case accountGroup = 1    // 账户相关：用户信息
    case guideVIPGroup = 2   // 引导成为VIP的卡片
    case safetyGroup = 3     // 自定义设置
    case othersGroup = 4     // 其他设置：关于我们
    case rantingGroup = 5    // 引导评论和分享
}

struct SettingGroupCellModel {
    
    /// 区分是哪一组
    var group = SettingCellGroupType.accountGroup
    
    /// 头部标题
    var headTitle: String?
    
    /// 数据源
    var itemArray: [SettingCellItemType] = []
    
    /// 底部文字
    var footTitle: String?
    
}

enum SettingCellItemType {
    case loginAccount
    
    case guideVIP
    
    case selectPlayer
    case playConfig
    case cacheConfig
    case applogo
    case appTintColor
    case appearance
    
    case types
    case donate
    case guideiOS
    case FAQ
    case abountUS
    
    case guideRanting
    
    func titleStr() -> String? {
        switch self {
        case .loginAccount:
            return nil
        
        case .guideVIP:
            return nil
            
        case .selectPlayer:
            return "Playback Engine".localStr()
        case .playConfig:
            return "Preferences".localStr()
        case .cacheConfig:
            return "Playback Cache".localStr()
        case .applogo:
            return "App Logo"
        case .appTintColor:
            return "Accent Color".localStr()
        case .appearance:
            return "Appearance".localStr()
        
        case .types:
            return "All Music Formats".localStr()
        case .donate:
            return "Donate".localStr()
        case .guideiOS:
            return "Download for iOS".localStr()
        case .FAQ:
            return "FAQ".localStr()
        case .abountUS:
            return "About Us".localStr()
            
        case .guideRanting:
            return nil
        }
    }
    
    func cellImage() -> UIImage? {
        
        switch self {
        case .loginAccount:
            return nil
        
        case .guideVIP:
            return nil
            
            
        case .selectPlayer:
            return Reasource.systemNamed("play.rectangle", color: appMainColor)
        case .playConfig:
            return Reasource.systemNamed("slider.vertical.3", color: appMainColor)
        case .cacheConfig:
            return Reasource.systemNamed("square.and.arrow.down", color: appMainColor)
        case .applogo:
            return Reasource.systemNamed("square.on.square", color: appMainColor)
        case .appTintColor:
            if #available(iOS 16.0, *) {
                return Reasource.systemNamed("swatchpalette", color: appMainColor)
            }else{
                return Reasource.systemNamed("paintpalette", color: appMainColor)
            }
        case .appearance:
            return Reasource.systemNamed("moon.circle.fill", color: appMainColor)
        
        case .donate:
            return Reasource.systemNamed("heart", color: appMainColor)
        case .types:
            return Reasource.systemNamed("checkmark.circle", color: appMainColor)
        case .guideiOS:
            if #available(iOS 16.1, *) {
                return Reasource.systemNamed("macbook.and.iphone", color: appMainColor)
            }else{
                return Reasource.systemNamed("iphone", color: appMainColor)
            }
        case .FAQ:
            return Reasource.systemNamed("questionmark.circle", color: appMainColor)
        case .abountUS:
            return Reasource.systemNamed("ellipsis.circle", color: appMainColor)
            
        case .guideRanting:
            return nil
        }
        
    }
    
}
