//
//  SKProduct+Extension.swift
// Photo Vault
//
//  Created by Kaka Inc. on 2023/12/15.
//

import KakaFoundation
import RevenueCat
import SmartCodable
import AppGroupKit
import StoreKit


extension StoreProduct {
    
    /// 构造内购对象
    public static func defaultProducts() -> [StoreProduct] {
        let tempArray = [StoreProduct]()
        
//        let model1 = SKProduct()
//        let model2 = SKProduct()
//        let model3 = SKProduct()
        
        return tempArray
    }
    
    /// 获取免费试用的总天数。如果没有免费试用，则返回 nil。
    var freeTrialDays: Int? {
        // 1. 确保是一个订阅产品，并且存在初始优惠（Introductory Offer）
        guard let introOffer = self.sk2Product?.subscription?.introductoryOffer,
              introOffer.paymentMode == .freeTrial else {
            return nil
        }
        
        // 2. 获取优惠周期
        let period = introOffer.period
        
        // 3. 根据周期单位计算天数
        switch period.unit {
        case .day:
            return period.value
        case .week:
            return period.value * 7
        case .month:
            // 按照行业标准，通常按 30 天计算，或者直接根据业务需求返回
            return period.value * 30
        case .year:
            return period.value * 365
        @unknown default:
            return nil
        }
    }
    
    /// 是否包含免费试用
    var hasFreeTrial: Bool {
        return freeTrialDays != nil
    }
    
}

extension EntitlementInfo {
    /// 转换支付状态
    func payStatus() -> PurchargeStatus {
        guard let goodsID = PurchaseStoreID(rawValue: self.productIdentifier) else {
            return .normal
        }
        
        let isSubscription = (/*goodsID == .weekly || */goodsID == .yearly)
        
        if isSubscription {
            // 判断订阅状态
            if self.isActive {
                // 检查到期日期
                if let expirationDate = self.expirationDate {
                    // 如果到期日期在未来，则用户处于有效订阅状态
                    return expirationDate > Date() ? .subscribing : .expired
                } else {
                    // 如果没有到期日期，表示是永久订阅
                    return .subscribing
                }
            } else {
                // 如果订阅不活跃，可能是退款或未支付
                if self.billingIssueDetectedAt != nil || self.unsubscribeDetectedAt != nil {
                    return .refunded
                }
                
                return .normal
            }
        } else {
            // 处理非订阅情况
            return self.isActive ? .lifetime : .refunded
        }
    }
    
}
