//
//  AppStoreKitManager+Discount.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2024/4/18.
//

import KakaFoundation
import AppGroupKit
import SmartCodable

/// 终身限免折扣管理器（引用类型单例）
public final class DiscountIAPManager: SmartCodableX {
    
    // 1. 私有化构造函数，防止外部直接 init
    public required init() {}
    
    // 2. 全局唯一内存单例（指针指向唯一内存地址）
    public static var shared: DiscountIAPManager = DiscountIAPManager.read()
    
    /// 上次触发/重置折扣倒计时的时间戳 (Unix 时间戳)
    private(set) var lastDiscountTime: TimeInterval? {
        didSet {
            save()
        }
    }
    
    // 倒计时时长（调试环境 5 小时，正式环境 3 小时）
#if DEBUG
    private(set) var maxDiscountTime: Double = 0.1 * 60 * 60
#else
    private(set) var maxDiscountTime: Double = 24 * 60 * 60
#endif
    
    // 冷却天数（调试环境 1 天，正式环境 2 天）
#if DEBUG
    private(set) var defaultDays: Double = 1
#else
    private(set) var defaultDays: Double = 2
#endif
    
    // MARK: - 核心业务逻辑
    
    /// 是否应该显示终身折扣价
    public func isShowDiscount() -> Bool {
        
        if UserInfoManager.shared.isVIP() {
            return false
        }
        
        guard let lastDiscountTime = self.lastDiscountTime, lastDiscountTime > 0 else {
            return true  // 首次默认激活
        }
        
        let now = Date().timeIntervalSince1970
        let elapsedTime = now - lastDiscountTime
        
        if elapsedTime < maxDiscountTime {
            return true
        }
        
        let coolingPeriodInSeconds = defaultDays * 24 * 60 * 60
        if elapsedTime >= coolingPeriodInSeconds {
            return true
        }
        
        return false
    }
    
    /// 获取当前倒计时剩余秒数
    public func remainingDiscountTime() -> TimeInterval {
        guard let lastDiscountTime = self.lastDiscountTime, lastDiscountTime > 0 else {
            return 0
        }
        
        let now = Date().timeIntervalSince1970
        let leftTime = maxDiscountTime - (now - lastDiscountTime)
        return max(0, leftTime)
    }
    
    /// 触发/刷新折扣倒计时
    public static func markDiscountStarted() {
        // 🌟 核心改变：直接修改全局唯一内存指针上的属性，既会更新内存，又会触发 oldValue/didSet 存盘
        DiscountIAPManager.shared.lastDiscountTime = Date().timeIntervalSince1970
    }
}

// MARK: - 持久化扩展
extension DiscountIAPManager {
    
    private static func kaka_DiscountIAPkey() -> String {
        return "kaka_DiscountIAPkey"
    }
    
    /// 从磁盘读取并解序列化（仅供类内部或单例初始化时使用）
    private static func read() -> DiscountIAPManager {
        let key = Self.kaka_DiscountIAPkey()
        let sharedUD = UserDefaults.standard
        guard let jsonStr = sharedUD.string(forKey: key), !jsonStr.isEmpty else {
            return DiscountIAPManager()
        }
        
        let decryptStr = AESCryptoManager.decryptAES(string: jsonStr, key: UserInfoManager.aesPassKey)
        let model = DiscountIAPManager.deserialize(from: decryptStr) ?? DiscountIAPManager()
        return model
    }
    
    /// 保存当前配置（将引用类型转换为 JSON 并存盘）
    private func save() {
        let jsonStr = self.toJSONString() ?? ""
        let encryptStr = AESCryptoManager.encryptAES(string: jsonStr, key: UserInfoManager.aesPassKey)
        
        let sharedUD = UserDefaults.standard
        sharedUD.set(encryptStr, forKey: Self.kaka_DiscountIAPkey())
        sharedUD.synchronize()
    }
    
    /// 重置数据
    public static func reset() {
        let key = Self.kaka_DiscountIAPkey()
        let sharedUD = UserDefaults.standard
        sharedUD.removeObject(forKey: key)
        sharedUD.synchronize()
        
        // 🌟 同步清理当前内存单例中的属性
        DiscountIAPManager.shared = DiscountIAPManager()
    }
}
