//
//  SearchEngineType.swift
//  AppGroupKit
//
//  Created by Kaka Inc. on 2023/12/1.
//

import KakaFoundation
import SmartCodable

public enum SearchEngineType: String, SmartCaseDefaultable {
    case google = "engine_google"     // 默认谷歌
    case bing = "engine_bing"         // Bing
    case duckduck = "engine_duckduck" // 专注隐私
    case quark = "engine_quark"       // 中国大陆
    case yahooJapan = "engine_yahoo"  // 雅虎日本
    case naver = "engine_naver"       // 韩国
    case yandex = "engine_yandex"     // 俄罗斯
    
    public static func defaultEngine() -> SearchEngineType {
        let country = PhoneSetManager.localPhoneCountry()
        let language = PhoneSetManager.formatLanguage()
        
        if country == .chinese || language == .chinese_simplified {
            return Self.isHttpProxy() ? .google : .bing
        }else if (country == .russian || language == .russian){
            return .yandex
        }else if (country == .korea || language == .korean) {
            return .naver
        }else{
            return .google
        }
    }
    
    public func searchUrl() -> String {
        switch self {
        case .duckduck:
            return "https://duckduckgo.com/?q=%@"
        case .google:
            return "https://www.google.com/search?q=%@"
        case .quark:
            return "https://quark.sm.cn/s?q=%@&safe=0"
        case .bing:
            return "https://www.bing.com/search?q=%@"
        case .yahooJapan:
            return "https://search.yahoo.co.jp/search?p=%@"
        case .naver:
            return "https://search.naver.com/search.naver?query=%@"
        case .yandex:
            return "https://yandex.com/search/?text=%@"
        }
    }
    
    public func officeURL() -> String {
        switch self {
        case .duckduck:
            return "https://duckduckgo.com"
        case .google:
            return "https://www.google.com/"
        case .quark:
            return "https://quark.sm.cn/s?safe=0"
        case .bing:
            return "https://www.bing.com/"
        case .yahooJapan:
            return "https://search.yahoo.co.jp/"
        case .naver:
            return "https://www.naver.com/"
        case .yandex:
            return "https://yandex.com/"
        }
    }
    
    public func iconName() -> String {
        switch self {
        case .duckduck:
            return "engine_duckduck_icon"
        case .quark:
            return "engine_quark_icon"
        case .google:
            return "engine_google_icon"
        case .bing:
            return "engine_bing_icon"
        case .yahooJapan:
            return "engine_yahoo_icon"
        case .naver:
            return "engine_naver_icon"
        case .yandex:
            return "engine_yandex_icon"
        }
    }
    
    public func nameStr() -> String {
        switch self {
        case .duckduck:
            return "DuckDuckGo"
        case .quark:
            return PhoneSetManager.formatLanguage() == .chinese_simplified ? "夸克" : "Quark"
        case .google:
            return "Google"
        case .bing:
            return "Bing"
        case .yahooJapan:
            return "Yahoo"
        case .naver:
            return "Naver"
        case .yandex:
            return "Yandex"
        }
    }
    
    /// 判断用户是否连接代理
    public static func isHttpProxy() -> Bool {
        guard let proxy = CFNetworkCopySystemProxySettings()?.takeUnretainedValue() else { return false }
        guard let dict = proxy as? [String: Any] else { return false }
        guard let HTTPProxy = dict["HTTPProxy"] as? String else { return false }
        if(HTTPProxy.count > 0){
            return true;
        }
        return false
    }
}
