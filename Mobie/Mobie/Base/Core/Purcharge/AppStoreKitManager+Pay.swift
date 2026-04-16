//
//  AppStoreKitManager+Pay.swift
// Wake Music
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
        Purchases.shared.restorePurchases { (customerInfo, error) in
            guard let customerInfo = customerInfo else {
                return
            }
            
            guard customerInfo.entitlements.all.count > 0 else { return }
            
            if let activePremium = customerInfo.entitlements.all[PremiumEntitlID], activePremium.isActive {
                self.handlePayBigModel(activePremium: activePremium)
            }else{
                UserInfoManager.shared.payStatus = .normal
            }
        }
#endif
    }
    
    /// 统一处理支付记录大模型
    /// - Parameter allModel: 支付大模型
    public func handlePayBigModel(activePremium: EntitlementInfo) {
        
#if !Target_Mobie_Pro
        // 更新用户信息        
        UserInfoManager.shared.payGoodsId = activePremium.productIdentifier
        UserInfoManager.shared.expireDate = activePremium.expirationDate?.timeIntervalSince1970
        UserInfoManager.shared.payStatus = activePremium.payStatus()
        
#endif
    }
    
}
