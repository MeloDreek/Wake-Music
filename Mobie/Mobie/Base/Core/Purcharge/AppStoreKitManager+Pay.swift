//
//  AppStoreKitManager+Pay.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2023/12/12.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import RevenueCat

extension AppStoreKitManager {
    
    /// 启动后验证支付状态
    public func verifyPaymentRecords() {
#if !Target_Mobie_Pro
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            guard let customerInfo = customerInfo else {
                return
            }
            
            if let activePremium = customerInfo.entitlements.all[PremiumEntitlID] {
                self.handlePayBigModel(activePremium: activePremium)
            }else{
                UserInfoManager.shared.payStatus = .normal
                UserInfoManager.shared.payGoodsId = nil
                UserInfoManager.shared.expireDate = nil
                UserInfoManager.shared.isFreeTrail = false
            }
        }
#endif
    }
    
    /// 统一处理支付记录大模型
    /// - Parameter allModel: 支付大模型
    public func handlePayBigModel(activePremium: EntitlementInfo) {
        
#if !Target_Mobie_Pro
        // 更新用户信息
        UserInfoManager.shared.isFreeTrail = activePremium.periodType == .trial
        UserInfoManager.shared.payGoodsId = activePremium.productIdentifier
        UserInfoManager.shared.expireDate = activePremium.expirationDate?.timeIntervalSince1970
        UserInfoManager.shared.payStatus = activePremium.payStatus()
        
#endif
    }
    
}
