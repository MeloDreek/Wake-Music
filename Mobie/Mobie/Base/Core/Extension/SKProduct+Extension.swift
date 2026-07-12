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

extension Product {
    /// 获取该订阅产品折算到每月的本地化费用字符串 (例如: "¥15.00", "$4.99")
    /// 如果不是订阅产品，则返回原本的本地化总价
    public var localMonthlyPriceStr: String {
        // 1. 检查是否为订阅产品，并直接获取其 subscriptionPeriod
        guard let subscription = self.subscription else {
            // 如果不是订阅产品（例如一次性消耗品），退回到默认的本地化总价
            return self.displayPrice
        }
        
        let period = subscription.subscriptionPeriod
        
        // 2. 计算该周期总共包含多少个月
        let totalMonths: Int
        switch period.unit {
        case .day:
            // 按 30 天折算一个月
            totalMonths = period.value / 30
        case .week:
            // 按 4 周折算一个月
            totalMonths = period.value / 4
        case .month:
            totalMonths = period.value
        case .year:
            totalMonths = period.value * 12
        @unknown default:
            totalMonths = 0
        }
        
        // 防御性编程：如果算出来月数为 0，直接返回原展示价格
        guard totalMonths > 0 else {
            return self.displayPrice
        }
        
        // 3. 计算月均价格 (总价 / 总月数)
        let monthlyPrice = self.price / Decimal(totalMonths)
        
        // 4. 使用产品自带的 priceFormatStyle 进行本地化货币格式化
        return monthlyPrice.formatted(self.priceFormatStyle)
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
