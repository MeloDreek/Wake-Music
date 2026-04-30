//
//  PurchaseViewController+Discount.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/3/27.
//

#if !Target_Mobie_Pro
import KakaFoundation
import KakaUIKit
import AppGroupKit
import StoreKit
import RevenueCat

extension PurchaseViewController {
    
    // 计算是否需要展示终身折扣内购
    func handlePriceGoods(_ models: [StoreProduct]) {
        
        if UserInfoManager.shared.isVIP() {
            self.priceArray = models.filter({ $0.productIdentifier != PurchaseStoreID.lifetime198.rawValue })
            self.selectModel = models.filter({ $0.productIdentifier == PurchaseStoreID.lifetime298.rawValue }).first
            self.tableView.reloadData()
            return
        }
                
        self.selectModel = self.priceArray.filter({ $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }).first
        self.tableView.reloadData()
        
        let nowDate = Date()
        
        if DiscountIAPManager.shared.lastDiscountTime == nil || DiscountIAPManager.shared.isBeyoned3Days() {
            // 设置首次进入支付页的时间
            DiscountIAPManager.shared.lastDiscountTime = nowDate.timeIntervalSince1970
            NotificationCenter.default.post(name: Notification.Name(kStartDiscountPriceKey), object: nil, userInfo: nil)
            
            self.showDiscountBox()
        }
        
        let isShowDiscount = DiscountIAPManager.shared.isShowDiscount()

        if !isShowDiscount {
            // 需要过滤的商品ID
            self.priceArray = models.filter({ $0.productIdentifier != PurchaseStoreID.lifetime198.rawValue })
            self.selectModel = self.priceArray.filter({ $0.productIdentifier == PurchaseStoreID.lifetime298.rawValue }).first
            self.tableView.reloadData()
            return
        }
                
        // 需要过滤的商品ID
        self.priceArray = models.filter({ $0.productIdentifier != PurchaseStoreID.lifetime298.rawValue })
        self.selectModel = self.priceArray.filter({ $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }).first
        self.tableView.reloadData()
        
        // 开始计算倒计时
        self.timeSpaceRepeat()
        
    }
    
    @objc func timeSpaceRepeat() {
        
        self.timer.startTimer(seconds: 0.01, repeats: true, callSoon: true) { [weak self] vTime in
            guard let wSelf = self else { return }
            guard let lastDiscountTime = DiscountIAPManager.shared.lastDiscountTime else {
                return
            }
            
            let index: Int? = wSelf.priceArray.firstIndex { $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }
            guard let index = index else { return }
            guard let discountCell = wSelf.tableView.cellForRow(at: IndexPath(row: index, section: 1)) as? PurchasePriceCell else { return }
            
            let nowDate = Date()
            
            var leftTime = nowDate.timeIntervalSince1970 - lastDiscountTime
            leftTime = wSelf.maxDiscountTime - leftTime
            
            if leftTime <= 0 {
                // 折扣倒计时结束啦
                vTime.stopTimer()
                wSelf.tableView.reloadData()
                return
            }
                        
            discountCell.leftDiscountTime = leftTime
        }
        
    }
    
    @objc func showPremiumOffer() {
        if UserInfoManager.shared.isVIP() { return }
        
        if !DiscountIAPManager.shared.isShowDiscount() {
            DiscountIAPManager.reset()
            
            AppStoreKitManager.shared.refresRemoteProductsPrice(productIds: [.yearly, .lifetime198, .lifetime298]) { [weak self] models in
                self?.handlePriceGoods(models)
            }
            
        }
        
        if self.view.viewWithTag(1688) != nil {
            return
        }
        
        self.showZeroPriceGiftBoxTips()
    }
    
    func showDiscountBox() {
        
        guard let offerModel = self.priceArray.filter({ $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }).first else {
            return
        }
        let message = "Limited Time Offer".localStr() + "\r" +  "You got a chance to get a lifetime limited time offer".localStr()
        
        let giftView = UIImageView(image: Reasource.named("gift_box"))
        giftView.contentMode = .scaleAspectFit
        giftView.size = CGSizeMake(120.ckValue(), 120.ckValue())
                
        let alertView = KakaAlertView.popupAlertView(title: "Congratulations!".localStr(), message: message, customView: giftView, confirmTitle: "OK".localStr(), action: { [weak self] style in
            guard let wSelf = self else { return }
            
            wSelf.selectModel = offerModel
            wSelf.tableView.reloadData()
            wSelf.buyoutButton.kaka_playShakeAnim()
            
        }, inView: self.view)
        alertView.tag = 1288
        alertView.isShowCloseButton = false
    }
    
    func showZeroPriceGiftBoxTips() {
        guard let offerModel = self.priceArray.filter({ $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }).first else {
            return
        }
        
        let giftView = UIImageView(image: Reasource.named("gift_box"))
        giftView.contentMode = .scaleAspectFit
        giftView.size = CGSizeMake(120.ckValue(), 120.ckValue())
                
        let alertView = KakaAlertView.popupAlertView(title: "Limited Time Offer".localStr(), message: "Dear friends, this is the first time we are coming to your country. To celebrate this occasion, all downloaders can upgrade to Lifetime Premium for free!".localStr(), customView: giftView, confirmTitle: "OK".localStr(), action: { [weak self] style in
            guard let wSelf = self else { return }
            
            wSelf.selectModel = offerModel
            wSelf.tableView.reloadData()
            
            wSelf.buyoutButton.kaka_playShakeAnim()
            
        }, inView: appKeyWindow ?? self.view)
        alertView.tag = 1688
        alertView.isShowCloseButton = false
    }
    
    func showScoreAndShare(_ completion: (()->Void)? = nil) {
        
        AnalyticsManager.shared.logEvent("First_Beta_Offer", parameters: nil)

        let alertController = UIAlertController(title: "Congratulations!".localStr(), message: "You have been upgraded to Lifetime Premium for free. Don’t forget to tell your friends about this special event!".localStr(), preferredStyle: .alert)
        let action1 = UIAlertAction(title: "Five Star Rating".localStr(), style: .default) { (sender) in
            AppLocalManager.shared.isReceiveOffer = true
            completion?()
        }
                
        alertController.addAction(action1)
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")

        self.present(alertController, animated: true, completion: nil)
    }
    
}

#endif
