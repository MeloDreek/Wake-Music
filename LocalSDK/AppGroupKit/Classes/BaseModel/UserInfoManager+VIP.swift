//
//  UserInfoManager+VIP.swift
//  AppGroupKit
//
//  Created by 张文 on 9/20/25.
//

import KakaFoundation

extension UserInfoManager {
    
    /// 是否为VIP
    public func isPremium() -> Bool {
        let payStatus = self.payStatus
        return payStatus == .subscribing || payStatus == .lifetime
    }
    
    /// 是否为老用户，注册日期比今天更早的
    public func isOldUser() -> Bool {
        
        let registerDate = Date(timeIntervalSince1970: self.registerDate.rounded())
        let currentDate = Date()
        let oneDayAgo = currentDate.addingTimeInterval(-24 * 60 * 60) // 当前时间减去一天（24小时）
        return registerDate < oneDayAgo // 如果注册日期早于一天前，则为老用户
        
    }
    
    // 注册时的设备
    public func deviceOSType() -> String {
        guard let osType = self.registerOsType else { return "☎️" }
        switch osType {
        case .iOS:
            return "📱"
        case .iPadOS:
            return "🎛️"
        case .macOS:
            return "💻"
        }
    }
}
