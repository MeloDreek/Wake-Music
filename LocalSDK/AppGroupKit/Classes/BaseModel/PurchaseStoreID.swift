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
    
    case weekly = "com.OfflineMusic.www.Weekly"
    case yearly = "com.OfflineMusic.www.Annual"              // 年度VIP
    case lifetime198 = "com.OfflineMusic.www.lifetime198"    // 买断制折扣价
    case lifetime298 = "com.OfflineMusic.www.lifetime298"    // 买断制原价
}

public enum PurchargeStatus: String, SmartCaseDefaultable {
    case normal = "normal"            // 默认，未支付
    case subscribing = "subscribing"  // 订阅中
    case lifetime = "lifetime"        // 终身买断
    case expired = "expired"          // 已过期
    case refunded = "refunded"        // 已退款
}


