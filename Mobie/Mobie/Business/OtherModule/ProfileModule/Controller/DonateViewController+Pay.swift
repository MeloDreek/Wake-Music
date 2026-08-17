//
//  DonateViewController+Pay.swift
//  Mobie
//
//  Created by 张文 on 10/10/24.
//

import KakaFoundation
import RevenueCat
import ProgressHUD
import AppGroupKit

extension DonateViewController {
    func startPurchageAction() {
        guard let selectModel = self.selectModel else {
            let payCell1 = self.tableView.cellForRow(at: IndexPath(row: 0, section: 1))
            let payCell2 = self.tableView.cellForRow(at: IndexPath(row: 1, section: 1))
            let payCell3 = self.tableView.cellForRow(at: IndexPath(row: 2, section: 1))
            payCell1?.kaka_playShakeAnim()
            payCell2?.kaka_playShakeAnim()
            payCell3?.kaka_playShakeAnim()
            return
        }
        
        if self.netConnect == .unavailable {
            self.showTwoAlert(title: "Reminder".localStr(), message: "Network access is disabled. Enable it for the best experience.".localStr(), confirm: "Settings".localStr(), cancle: "Cancel".localStr()) {
                guard let vURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(vURL)
            }
            return
        }
        
        ProgressHUD.animate("Processing...".localStr())
        
        Purchases.shared.purchase(product: selectModel) { [weak self] (transaction, info, error, cancelled) in
            if cancelled {
                ProgressHUD.dismiss()
                self?.view.makeToast(KakaError.youhaveCanceled.errorDescription)
                return
            }
            
            // Optionally handle specific purchase errors
            if let err = error as NSError? {
                ProgressHUD.failed(err.localizedDescription)
            } else {
                ProgressHUD.dismiss()
                self?.showOneAlert(title: "Reminder".localStr(), message: "Thank you for your support!".localStr(), complete: {
                    self?.navigationController?.popViewController(animated: true)
                })
            }

        }
        
    }
    
}
