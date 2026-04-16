//
//  SocialMediaType.swift
//  Mobie
//
//  Created by 张文 on 10/3/24.
//

import KakaFoundation

enum SocialMediaType: String {
    case wechat = "wechat"
    case redbook = "redbook"
    case twitter = "twitter"
    
    case faceboook = "facebook"
    case telegram = "telegram"
    case line = "line"
    case russiaVK = "vk"
    
    case email = "email"
    
    
    static func socialArray() -> [SocialMediaType] {
        
#if DEBUG
        return [.twitter, .telegram, .line, .russiaVK, .wechat, .redbook, .email]
#else
        let language = PhoneSetManager.formatLanguage()
        
        switch language {
        case .chinese_simplified:
            var isCanOpenTG = false
            if let vURL = URL(string: "telegram://"), UIApplication.shared.canOpenURL(vURL) {
                isCanOpenTG = true
            }
            return (isCanOpenTG || PhoneSetManager.isVPNConnected()) ? [.redbook, .telegram, .wechat, .email] : [.redbook, .wechat, .email]
        case .russian:
            return [.russiaVK, .telegram, .twitter, .email]
        case .chinese_traditional, .japanese, .tailand:
            return [.line, .telegram, .email]
        default:
            return [.telegram, .twitter, .email]
        }
#endif
        
    }
    
    func iconImage() -> UIImage {
        switch self {
        case .wechat:
            return Reasource.named("social_wechat")
        case .redbook:
            return Reasource.named("social_redbook")
        case .faceboook:
            return Reasource.named("social_facebook")
        case .twitter:
            return Reasource.named("social_twitter")
        case .telegram:
            return Reasource.named("social_telegram")
        case .russiaVK:
            return Reasource.named("social_vk")
        case .line:
            return Reasource.named("social_line")
        case .email:
            return Reasource.named("social_email")
        }
    }
    
    func titleStr() -> String {
        
        let language = PhoneSetManager.formatLanguage()
        let region = PhoneSetManager.localPhoneCountry()
        let isChinese = language == .chinese_simplified || language == .chinese_traditional || region == .chinese || region == .taiwan
        
        switch self {
        case .wechat:
            return isChinese ? "微信" : "WeChat"
        case .redbook:
            return isChinese ? "小红书" : "RedNote"
        case .twitter:
            return "Twitter/X"
        case .faceboook:
            return "Facebook"
            
        case .line:
            return "Line"
        case .telegram:
            return "Telegram"
            
        case .russiaVK:
            return "VK"
            
        case .email:
            return "E-Mail".localStr()
        }
    }
    
    func socialMediaURL() -> (fullURL: URL?, mediaID: String?) {
        switch self {
        case .wechat:
            return (nil, nil)
        case .redbook: // 郭：5fbcc82c0000000001007128 & 陈：64967c74000000001c02a280
            let mediaID = "64967c74000000001c02a280"
            return (nil, mediaID)
            
        case .twitter:
            let vURL = URL(string: "https://x.com/melodreek")
            return (vURL, nil)
            
        case .russiaVK:
            let vkURL = URL(string: "https://vk.com/id857258767")
            return (vkURL, nil)
            
        case .faceboook:
            let faceURL = URL(string: "https://www.facebook.com/MeloDreek")
            return (faceURL, nil)
            
        case .telegram:
            let cnURL = URL(string: "https://t.me/wakemusicplay")
            let enURL = URL(string: "https://t.me/melodreek")
            let isChinese = PhoneSetManager.formatLanguage() == .chinese_simplified || PhoneSetManager.localPhoneCountry() == .chinese
            return (isChinese ? cnURL : enURL, nil)
        case .line:
            let lineMe = "https://line.me/ti/p/xTaVnYClW6"
            return (URL(string: lineMe), lineMe)
        case .email:
            return (nil, nil)
        }
    }
    
}
