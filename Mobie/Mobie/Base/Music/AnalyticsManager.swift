//
//  AnalyticsManager.swift
//  Wakemusic
//
//  Created by Melo on 7/29/24.
//

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
import AppGroupKit
import KakaFoundation

class AnalyticsManager: NSObject {
    
    
    static let shared = AnalyticsManager()
    
    private override init() {
        // 私有化初始化方法以确保单例模式
    }
    
    /// 记录事件
    /// - Parameters:
    ///   - name: 事件名称
    ///   - parameters: 事件参数，默认为空
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        
        if PhoneSetManager.isChineseMainLand() && !PhoneSetManager.isVPNConnected() {
            return
        }
        
        let appVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String
        let country = PhoneSetManager.regionCode()
        let language = PhoneSetManager.langugeCode()
        let osType = kaka_osType().rawValue
        let app_version = appVersion ?? ""
        
        var basicDic: [String: Any] = ["region": country, "language": language, "OS": osType, "app_version": app_version]
        if let parameters = parameters {
            basicDic.merge(parameters) { (_, new) in new }
        }
        
#if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: basicDic)
#endif
    }
    
    
}

