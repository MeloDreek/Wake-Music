//
//  PhoneSetManager.swift
//  KakaFoundation
//
//  Created by Kaka Inc.on 2021/11/11.
//

import Foundation
import CoreTelephony
import SmartCodable
import NetworkExtension

public enum Language: String, SmartCaseDefaultable {
    
    case arabic = "ar"  // 阿拉伯语
    case english = "en"  // 英语
    case chinese_simplified = "zh-CHS"  // 简体中文
    case chinese_traditional = "zh-CHT" // 繁体中文
    case french = "fr" // 法语
    case german = "de" // 德语
    case japanese = "ja" // 日语
    case korean = "ko" // 韩语
    case spanish = "es" // 西班牙语
    case portuguese = "pt" // 葡萄牙语
    case russian = "ru"   // 俄罗斯
    
    case hindi = "hi" // 印地语
    case yuenan = "vi" // 越南语
    case tailand = "th" // 泰语
    case yinni = "id"  // 印尼语
    case turkish = "tr" // 土耳其语
    case malay = "ms" // 马来语
    case italian = "it" // 意大利语
    case hebren = "he" // 希伯來語
}

public enum Country: String, SmartCaseDefaultable {
    case unSupport = "unSupport"// 默认
    case chinese = "CN"      // 中国大陆
    case taiwan = "TW"       // 中国台湾
    case japan = "JP"        // 日本
    case tailand = "TH"      // 泰国
    case korea = "KR"        // 韩国
    case russian = "RU"      // 俄罗斯
    case USA = "US"          // 美国
    
    // 支持ASM
    case saudi = "SA"       // 沙特阿拉伯🇸🇦 3218万 # 34400美元
    case arabEmirat = "AE"  // 阿联酋🇦🇪 1017万 # 47700美元
    case egypt = "EG"       // 埃及🇪🇬 1.04亿 # 3780美元
    case oman = "OM"        // 阿曼🇴🇲 # 508万 # 19000美元
    case kuwait = "KW"      // 科威特🇰🇼 482.4万 # 39000美元
    case qatar = "QA"       // 卡塔尔🇶🇦 # 297万 # 81800美元
    case jordan = "JO"      // 约旦🇯🇴 1130万 # 4100美元
    case lebanon = "LB"     // 黎巴嫩🇱🇧 607万 # 4576美元

    case bahrain = "BH"     // 巴林🇧🇭 150万 # 23500美元
    case algeria = "DZ"     // 阿尔及利亚🇩🇿 4508万 # 4150 美元
    case djibouti = "DJ"    // 吉布提🇩🇯 110万
    case comoros = "KM"     // 科摩罗🇰🇲 87万 # 1484美元
    case Iraq = "IR"        // 伊拉克🇮🇶 4335万 # 5021美元
    case libya = "LY"       // 利比亚🇱🇾 710万 # 5465美元
    case mauritania = "MR"  // 毛里塔尼亚🇲🇷 480万 # 2330美元
    case morocco = "MA"     // 摩洛哥🇲🇦 3667万 # 3900美元
    case palestine = "PS"   // 巴勒斯坦🇵🇸 # 1350万 # 3655美元
    case somalia = "SO"     // 索马里🇸🇴 1544万 # 543美元
    case sudan = "SD"       // 苏丹🇸🇩 4668万 # 592美元
    case tunisia = "TN"     // 突尼斯🇹🇳 1200万 # 3820美元
    case yemen = "YE"       // 也门🇾🇪 3298万 # 691美元
    case syrian = "SY"      // 叙利亚🇸🇾 1929万 # 948美元
}

public class PhoneSetManager {
    
    // 当前语言类型-为了给后台
    public static func formatLanguage() -> Language {
        let languages = NSLocale.preferredLanguages
        
        guard let firstLanguage = languages.first else {
            return .english
        }
        
//        debugPrint("用戶的語言 = \(firstLanguage)")
                
        if firstLanguage.contains(Language.english.rawValue) {
            return .english
        }else if firstLanguage.contains("zh-Hans") {
            return .chinese_simplified
        }else if firstLanguage.contains("zh-Hant") || firstLanguage.contains("zh-HK") || firstLanguage.contains("zh-TW") {
            return .chinese_traditional
        }else if firstLanguage.contains(Language.arabic.rawValue) {
            return .arabic
        }else if firstLanguage.contains(Language.japanese.rawValue) {
            return .japanese
        }else if firstLanguage.contains(Language.korean.rawValue) {
            return .korean
        }else if firstLanguage.contains(Language.french.rawValue) {
            return .french
        }else if firstLanguage.contains(Language.spanish.rawValue) {
            return .spanish
        }else if firstLanguage.contains(Language.portuguese.rawValue) {
            return .portuguese
        }else if firstLanguage.contains(Language.russian.rawValue) {
            return .russian
        }else if firstLanguage.contains(Language.yuenan.rawValue) {
            return .yuenan
        }else if firstLanguage.contains(Language.german.rawValue) {
            return .german
        }else if firstLanguage.contains(Language.hebren.rawValue) {
            return .hebren
        }
        else{
            return .english
        }
        
    }
    
    // 国家
    public static func localPhoneCountry() -> Country {
        let regionCode = self.regionCode()
        
        let country = Country(rawValue: regionCode) ?? Country.unSupport
        return country
    }
    
    /// 是否为中国大陆
    public static func isChineseMainLand() -> Bool {
        return self.localPhoneCountry() == .chinese && self.formatLanguage() == .chinese_simplified
    }
    
    /// 是否为阿拉伯语或者希伯来语
    public static func isArabicLanguage() -> Bool {
        return self.formatLanguage() == .arabic || self.formatLanguage() == .hebren
    }
    
    /// 是否为阿拉伯国家
    public static func isArabicCountry() -> Bool {
        let arabCountryArray: [Country] = [.arabEmirat, .djibouti, .bahrain, .comoros, .egypt, .Iraq, .jordan, .kuwait, .lebanon, .libya, .mauritania, .morocco, .oman, .palestine, .qatar, .saudi, .somalia, .sudan, .tunisia, .arabEmirat, .yemen, .syrian]
        let country = self.localPhoneCountry()
        
        return arabCountryArray.contains(country)
    }
    
    /// zh_CN、en_US
    public static func languge_region() -> String {

        return self.langugeCode() + "_" + self.regionCode()
    }
    
    // 语言：cn、en、ar
    public static func langugeCode() -> String {

        var languageCode = NSLocale.current.languageCode

        if #available(iOS 16.0, macOS 13.0, *) {
            languageCode = NSLocale.current.language.languageCode?.identifier
        } else {
            languageCode = NSLocale.current.languageCode
        }
        
        return languageCode ?? "en"
    }
    
    // 地区：CN、US、ST
    public static func regionCode() -> String {

        var regionCode = NSLocale.current.regionCode

        if #available(iOS 16.0, macOS 13.0, *) {
            regionCode = NSLocale.current.region?.identifier
        } else {
            regionCode = NSLocale.current.regionCode
        }
                
        return regionCode ?? "US"
        
    }
    
    // 共同缅怀乔布斯
    public static func steveJobsURL() -> URL? {
         var steveStr = "https://www.apple.com/stevejobs/"
         let language = Self.localPhoneCountry()
         if language == .chinese {
             steveStr = "https://www.apple.com/cn/stevejobs/"
         }else if language == .taiwan {
             steveStr = "https://www.apple.com/tw/stevejobs/"
         }else if language == .japan {
             steveStr = "https://www.apple.com/jp/stevejobs/"
         }else if language == .korea {
             steveStr = "https://www.apple.com/kr/stevejobs/"
         }
         
         return URL(string: steveStr)
    }
    
    // 判断是否启用了VPN
    public static func isVPNConnected() -> Bool {
        guard let cfDict = CFNetworkCopySystemProxySettings() else {
            return false
        }
            
        let nsDict = cfDict.takeRetainedValue() as NSDictionary
        
        guard let keys = nsDict["__SCOPED__"] as? [String:Any] else {
            return false
        }
        
        let keyValues: [String] = [
            "tap",
            "tun",
            "ppp",
            "ipsec",
            "ipsec0",
        ]
        
        var result: Bool = false
        for key in keys.keys {
            keyValues.forEach { (value) in
                if key.contains(value) {
                    result = true
                }
            }
        }
        
        return result
    }
    
}

