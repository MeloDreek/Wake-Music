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
    
    /// 是否处于3天内的免费试用中
    public func isFreeTrail3Days_Local() -> Bool {
        guard let firstFileDate = self.firstFileDate else {
            return true // 如果没有首次创建文件的时间，返回 false
        }
            
        // 将 firstFileDate 转换为日期对象
        let fileDate = Date(timeIntervalSince1970: firstFileDate.rounded())
        
        // 获取当前日期
        let currentDate = Date()
        
        // 计算时间差
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: fileDate, to: currentDate)
        
        // 判断是否在3天内
        return components.day ?? 0 < 3
    }
    
    /// 远程功能：是否处于3天内的免费试用中
    public func isFreeTrail3Days_Remote() -> Bool {
        guard let firstRemoteDate = self.firstRemoteDate else {
            return true // 如果没有首次创建文件的时间，返回 false
        }
            
        // 将 firstRemoteDate 转换为日期对象
        let fileDate = Date(timeIntervalSince1970: firstRemoteDate.rounded())
        
        // 获取当前日期
        let currentDate = Date()
        
        // 计算时间差
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: fileDate, to: currentDate)
        
        // 判断是否在3天内
        return components.day ?? 0 < 3
        
        return false
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
