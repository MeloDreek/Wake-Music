//
//  PurchaseViewController+Pay.swift
//  Wakemusic
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
        guard !isPurchasing, buyoutButton.isEnabled else { return }
        
        guard let vModel = self.selectModel else {
            guard let payCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 1)) else {
                self.tableView.kaka_playShakeAnim()
                return
            }
            
            payCell.kaka_playShakeAnim()
            return
        }
                        
        isPurchasing = true
        ProgressHUD.animate("Processing...".localStr())
        AppStoreKitManager.shared.startPurcharge(product: vModel ) { [weak self] (enInfo) in
            guard let wSelf = self else { return }
            wSelf.isPurchasing = false
            
            ProgressHUD.succeed()
            
            wSelf.onPaySuccess?()
            wSelf.dismissAnimation(false)
            NotificationCenter.default.post(name: Notification.Name(kPurchageSuccessKey), object: nil)
                        
        } failBlock: { [weak self] errorMsg in
            self?.isPurchasing = false
            ProgressHUD.dismiss()
            if errorMsg.contains(KakaError.youhaveCanceled.errorDescription) {
                self?.view.makeToast(errorMsg)
            }else{
                self?.showOneAlert(message: errorMsg)
            }
            
        }
    }
    
}
#endif
