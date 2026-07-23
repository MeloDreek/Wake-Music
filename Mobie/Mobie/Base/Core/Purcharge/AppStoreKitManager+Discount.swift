//
//  AppStoreKitManager+Discount.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/4/18.
//

import KakaFoundation
import AppGroupKit
import SmartCodable

/// 终身限免折扣管理器
public struct DiscountIAPManager: SmartCodableX {
    public init() {}
    
    public static let shared = DiscountIAPManager.read()
    
    /// 上次触发/重置折扣倒计时的时间戳 (Unix 时间戳)
    public var lastDiscountTime: TimeInterval? {
        didSet {
            save()
        }
    }
    
    // 倒计时时长（调试环境 1 小时，正式环境 24 小时）
#if DEBUG
    private(set) var maxDiscountTime: Double = 0.1 * 60 * 60
#else
    private(set) var maxDiscountTime: Double = 24 * 60 * 60
#endif
    
    // 冷却天数（调试环境 1 天，正式环境 3 天）
#if DEBUG
    private(set) var defaultDays: Double = 1
#else
    private(set) var defaultDays: Double = 3
#endif
    
    // MARK: - 核心判断逻辑
    
    /// 是否应该显示终身折扣价
    /// - Returns: true -> 显示折扣价 (倒计时中 / 超过3天冷却期 / 首次进入)； false -> 显示原价 (处于3天冷却期内)
    public func isShowDiscount() -> Bool {
        guard let lastDiscountTime = self.lastDiscountTime, lastDiscountTime > 0 else {
            // 首次进入，无历史记录，默认应该显示折扣
            return true
        }
        
        let now = Date().timeIntervalSince1970
        let elapsedTime = now - lastDiscountTime
        
        // 1. 处于 24 小时倒计时期间 -> 显示折扣
        if elapsedTime < maxDiscountTime {
            return true
        }
        
        // 2. 倒计时已结束，计算自上次倒计时触发起，是否超过了指定的冷却天数 ( defaultDays * 86400 秒 )
        let coolingPeriodInSeconds = defaultDays * 24 * 60 * 60
        if elapsedTime >= coolingPeriodInSeconds {
            // 超过冷却期，可以开启新的折扣循环
            return true
        }
        
        // 3. 倒计时已过，但仍在冷却期内 -> 显示原价
        return false
    }
    
    /// 获取当前倒计时剩余秒数 (如果不在倒计时内则返回 0)
    public func remainingDiscountTime() -> TimeInterval {
        guard let lastDiscountTime = self.lastDiscountTime, lastDiscountTime > 0 else {
            return 0
        }
        
        let now = Date().timeIntervalSince1970
        let leftTime = maxDiscountTime - (now - lastDiscountTime)
        return max(0, leftTime)
    }
    
    /// 触发/刷新折扣倒计时 (在决定为用户再次开启折扣时调用，比如冷却期后用户看中了折扣)
    public static func markDiscountStarted() {
        var manager = DiscountIAPManager.read()
        manager.lastDiscountTime = Date().timeIntervalSince1970
    }
}

// MARK: - 持久化扩展
extension DiscountIAPManager {
    
    public static func kaka_DiscountIAPkey() -> String {
        return "kaka_DiscountIAPkey"
    }
    
    /// 读取本地配置
    public static func read() -> DiscountIAPManager {
        let key = DiscountIAPManager.kaka_DiscountIAPkey()
        let sharedUD = UserDefaults.standard
        guard let jsonStr = sharedUD.string(forKey: key), !jsonStr.isEmpty else {
            return DiscountIAPManager()
        }
        
        let decryptStr = AESCryptoManager.decryptAES(string: jsonStr, key: UserInfoManager.aesPassKey)
        let model = DiscountIAPManager.deserialize(from: decryptStr) ?? DiscountIAPManager()
        return model
    }
    
    /// 保存当前配置
    public func save() {
        let jsonStr = self.toJSONString() ?? ""
        let encryptStr = AESCryptoManager.encryptAES(string: jsonStr, key: UserInfoManager.aesPassKey)
        
        let sharedUD = UserDefaults.standard
        sharedUD.set(encryptStr, forKey: DiscountIAPManager.kaka_DiscountIAPkey())
        sharedUD.synchronize()
    }
    
    /// 重置数据
    public static func reset() {
        let key = DiscountIAPManager.kaka_DiscountIAPkey()
        let sharedUD = UserDefaults.standard
        sharedUD.removeObject(forKey: key)
        sharedUD.synchronize()
    }
}
