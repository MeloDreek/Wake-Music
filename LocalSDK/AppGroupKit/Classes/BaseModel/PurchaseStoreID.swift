//
//  PurchaseStoreID.swift
//  AppGroupKit
//
//  Created by Kaka Inc. on 2023/12/1.
//

import KakaFoundation
import SmartCodable
import StoreKit

public enum PurchaseStoreID: String, SmartCaseDefaultable {
    
//    case option1 = "com.OfflineMusic.www.6"   // 捐赠选项1
//    case option2 = "com.OfflineMusic.www.12"  // 捐赠选项2
//    case option3 = "com.OfflineMusic.www.18"  // 捐赠选项3
    
    case weekly = "com.OfflineMusic.www.Weekly"              // 周会员
    case monthly = "com.OfflineMusic.www.Monthly"            // 月度会员
    case yearly = "com.OfflineMusic.www.Annual"              // 年度VIP
    case lifetime198 = "com.OfflineMusic.www.lifetime198"    // 个人终身会员（保留原商品 ID）
    case lifetime298 = "com.OfflineMusic.www.lifetime298"    // 家庭共享终身会员（保留原商品 ID）

    /// 展示顺序与价格无关；Weekly 仅保留已有购买的识别与恢复。
    public static let paywallProducts: [PurchaseStoreID] = [.monthly, .yearly, .lifetime198, .lifetime298]

    public var isSubscription: Bool {
        switch self {
        case .weekly, .monthly, .yearly: return true
        case .lifetime198, .lifetime298: return false
        }
    }
}

public enum PurchargeStatus: String, SmartCaseDefaultable {
    case normal = "normal"            // 默认，未支付
    case subscribing = "subscribing"  // 订阅中
    case lifetime = "lifetime"        // 终身买断
    case expired = "expired"          // 已过期
    case refunded = "refunded"        // 已退款
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
