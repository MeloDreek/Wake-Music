//
//  AppStoreKitManager+Discount.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/4/18.
//

import KakaFoundation
import AppGroupKit
import SmartCodable

public struct DiscountIAPManager: SmartCodableX {
    public init() {}
    
    static public var shared = DiscountIAPManager.read() ?? DiscountIAPManager()
    
    /// 上次显示终身折扣的时间
    public var lastDiscountTime: TimeInterval? {
        didSet {
            save()
        }
    }
    
    // 默认倒计时3小时
#if DEBUG
    var maxDiscountTime: Double = 1 * 60 * 60
#else
    var maxDiscountTime: Double = 1 * 60 * 60
#endif
    
    // 默认隔几天出现
#if DEBUG
    var defaultDays = 1
#else
    var defaultDays = 3
#endif
    
    
    /// 是否要显示限时折扣。第一次，倒计时期间。超过3天后
    public mutating func isShowDiscount() -> Bool {
        guard let lastDiscountTime = self.lastDiscountTime, lastDiscountTime > 0 else {
            return false  // 首次进来
        }
                
        let nowDate = Date()
        
        var leftTime = nowDate.timeIntervalSince1970 - lastDiscountTime
        leftTime = self.maxDiscountTime - leftTime
                
        if leftTime <= 0 {
            // 折扣倒计时结束啦
            let firstDate = lastDiscountTime.rounded().formatDate()
            let calendar = Calendar(identifier: Calendar.current.identifier)
            let dayCount = calendar.dateComponents([Calendar.Component.day], from: firstDate, to: nowDate).day ?? 0
            
            let isOffer = dayCount >= defaultDays
            return isOffer
            
        }else{
            // 正在倒计时
            return true
        }
        
    }
    
    /// 距离上次展示折扣优惠是否超过3天
    public func isBeyoned3Days() -> Bool {
        guard let lastDiscountTime = self.lastDiscountTime, lastDiscountTime > 0 else { return false }
        
        let nowDate = Date()
        let firstDate = lastDiscountTime.rounded().formatDate()
        
        let calendar = Calendar(identifier: Calendar.current.identifier)
        let dayCount = calendar.dateComponents([Calendar.Component.day], from: firstDate, to: nowDate).day ?? 0
        
        return dayCount >= defaultDays
    }
    
}

extension DiscountIAPManager {
    public static func kaka_DiscountIAPkey() -> String {
        return "kaka_DiscountIAPkey"
    }
    
    public static func read() -> DiscountIAPManager? {
        let key = DiscountIAPManager.kaka_DiscountIAPkey()
        let sharedUD = UserDefaults.standard
        guard let jsonStr = sharedUD.string(forKey: key) else { return nil }
        let decryptStr = AESCryptoManager.decryptAES(string: jsonStr, key: UserInfoManager.aesPassKey)
          
        let model = DiscountIAPManager.deserialize(from: decryptStr)
        return model
    }
    
    public func save() {
        let jsonStr = self.toJSONString() ?? ""
        let encryptStr = AESCryptoManager.encryptAES(string: jsonStr, key: UserInfoManager.aesPassKey)
        
        let sharedUD = UserDefaults.standard
        sharedUD.set(encryptStr, forKey: DiscountIAPManager.kaka_DiscountIAPkey())
        sharedUD.synchronize()
    }
    
    public static func reset() {
        let key = DiscountIAPManager.kaka_DiscountIAPkey()
        let sharedUD = UserDefaults.standard
        sharedUD.set(nil, forKey: key)
        sharedUD.synchronize()
        
        DiscountIAPManager.shared = DiscountIAPManager()
    }
    
}
