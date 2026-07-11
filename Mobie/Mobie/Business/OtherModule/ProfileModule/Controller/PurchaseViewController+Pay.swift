//
//  PurchaseViewController+Pay.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/28.
//

#if !Target_Mobie_Pro
import KakaFoundation
import KakaUIKit
import AppGroupKit
import ProgressHUD
import StoreKit
import Toast
import KakaObjcKit

extension PurchaseViewController {
    
    // 点击支付按钮
    @objc func payButtonClick() {
        
        if self.netConnect == .unavailable {
            self.showTwoAlert(title: "Reminder".localStr(), message: "No network access permission, please enable it for the best experience.".localStr(), confirm: "Settings".localStr(), cancle: "Cancel".localStr()) {
                guard let vURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(vURL)
            }
            return
        }
        
        guard let vModel = self.selectModel else {
            guard let payCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 1)) else {
                self.tableView.kaka_playShakeAnim()
                return
            }
            payCell.kaka_playShakeAnim()
            return
        }
                        
        ProgressHUD.animate("Processing...".localStr())
        AppStoreKitManager.shared.startPurcharge(product: vModel ) { [weak self] (enInfo) in
            guard let wSelf = self else { return }
            
            ProgressHUD.succeed()
            
            if (enInfo.payStatus() == .subscribing || enInfo.payStatus() == .lifetime) && wSelf.selectModel?.price == 0 {
                wSelf.showScoreAndShare {
                    wSelf.onPaySuccess?()
                    wSelf.dismissAnimation(false)
                    NotificationCenter.default.post(name: Notification.Name(kAppThemeColorChangedKey), object: appMainColor)
                    NotificationCenter.default.post(name: Notification.Name(kPurchageSuccessKey), object: nil)
                }
            }else{
                wSelf.onPaySuccess?()
                wSelf.dismissAnimation(false)
                NotificationCenter.default.post(name: Notification.Name(kAppThemeColorChangedKey), object: appMainColor)
                NotificationCenter.default.post(name: Notification.Name(kPurchageSuccessKey), object: nil)
            }
                        
        } failBlock: { [weak self] errorMsg in
            if errorMsg.contains(KakaError.youhaveCanceled.errorDescription) {
                ProgressHUD.dismiss()
                self?.view.makeToast(errorMsg)
            }else{
                ProgressHUD.failed(errorMsg)
            }
            
            self?.sendPayFaildMessage(errorMsg)
        }
    }
        
    // 上报错误信息
    func sendPayFaildMessage(_ message: String) {
        if message == KakaError.youhaveCanceled.errorDescription {
            return
        }
                
        let params = ["errorMsg": message]
        AnalyticsManager.shared.logEvent("purchage_error", parameters: params)

    }
    
}
#endif

/*
 if firstPay.payStatus() == .subscribing || firstPay.payStatus() == .lifetime {
     
     if wSelf.selectModel?.price == 0 {
         wSelf.showScoreAndShare {
             wSelf.onPaySuccess?()
             NotificationCenter.default.post(name: Notification.Name(kPurchageSuccessKey), object: nil)
         }
     }else{
         wSelf.onPaySuccess?()
         wSelf.dismissAnimation(false)
         NotificationCenter.default.post(name: Notification.Name(kPurchageSuccessKey), object: nil)
     }
                     
 }
 */

