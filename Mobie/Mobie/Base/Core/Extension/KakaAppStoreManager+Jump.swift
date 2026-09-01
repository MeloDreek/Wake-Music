//
//  AppStoreKitManager+Jump.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2023/12/1.
//

import AppGroupKit
import KakaUIKit
import KakaFoundation
import Toast
import SafariServices

extension AppStoreKitManager {
    /// 前往支付页面
    static func presentPurcharseVC(_ fromVC: UIViewController, animated: Bool = true, success:(()->Void)? = nil, cancel: (()->Void)? = nil) {
        
#if !Target_Mobie_Pro
        if fromVC.currentViewController() is PurchaseViewController {
            return
        }
        
        if !DiscountIAPManager.shared.isShowDiscount() {
            DiscountIAPManager.reset()
        }
        
        let vipVC = PurchaseViewController()
        vipVC.onCancelBlock = cancel
        vipVC.onPaySuccess = success
        
        let navVC = KakaNavigationController(rootViewController: vipVC)
        navVC.modalPresentationStyle = kaka_IsMacOS() ? .automatic : .fullScreen
        fromVC.present(navVC, animated: animated, completion: nil)
                
#endif
    }
    
    
}
