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
    
    // MARK: - Goods Logic
    func handlePriceGoods(_ models: [StoreProduct]) {
        
        // 1. VIP 状态判断
        if UserInfoManager.shared.isVIP() {
            self.priceArray = models.filter { $0.productIdentifier != PurchaseStoreID.lifetime198.rawValue }
            self.selectModel = models.first { $0.productIdentifier == PurchaseStoreID.lifetime298.rawValue }
            self.tableView.reloadData()
            return
        }
        
        // 2. 直接获取单例指针，不用再多次 read()
        let manager = DiscountIAPManager.shared
        
        // 首次进入 或 超过冷却期后进入：重新开启 24 小时倒计时
        if manager.lastDiscountTime == nil || (manager.remainingDiscountTime() <= 0 && manager.isShowDiscount()) {
            DiscountIAPManager.markDiscountStarted()
            NotificationCenter.default.post(name: Notification.Name(kStartDiscountPriceKey), object: nil)
        }
        
        let isShowDiscount = manager.isShowDiscount() && manager.remainingDiscountTime() > 0

        // 3. 根据状态过滤商品
        if isShowDiscount {
            // 展示 198 终身折扣价
            self.priceArray = models.filter { $0.productIdentifier != PurchaseStoreID.lifetime298.rawValue }
            self.selectModel = self.priceArray.first { $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }
            self.tableView.reloadData()
            
            // 开启倒计时（直接从单例拿最新的 startTime）
            if let startTime = manager.lastDiscountTime {
                self.timeSpaceRepeat(lastDiscountTime: startTime, maxDiscountTime: manager.maxDiscountTime)
            }
        } else {
            // 展示 298 终身原价
            self.priceArray = models.filter { $0.productIdentifier != PurchaseStoreID.lifetime198.rawValue }
            self.selectModel = self.priceArray.first { $0.productIdentifier == PurchaseStoreID.lifetime298.rawValue }
            self.tableView.reloadData()
            
            // 停止倒计时
            self.timer.stopTimer()
        }
    }
    
    // MARK: - Countdown Timer
    func timeSpaceRepeat(lastDiscountTime: TimeInterval, maxDiscountTime: TimeInterval) {
        // 1. 先停掉旧定时器，防止重入叠加
        self.timer.stopTimer()
        
        self.timer.startTimer(seconds: 0.01, repeats: true, callSoon: true) { [weak self] vTime in
            guard let wSelf = self else { return }
            
            // 3. 纯内存计算！绝不在 Timer 内部做 AES 解密和磁盘 I/O
            let now = Date().timeIntervalSince1970
            let passTime = now - lastDiscountTime
            let leftTime = max(0, maxDiscountTime - passTime)
            
//            debugPrint("leftTime = \(leftTime)")
            
            // 4. 倒计时到期处理
            if leftTime <= 0 {
                vTime.stopTimer()
                // 注意：必须传入全量商品 self.allProducts，不能传过滤后的 priceArray！
                wSelf.handlePriceGoods(wSelf.allProducts)
                return
            }
            
            // 5. 刷新界面 Cell
            let index = wSelf.priceArray.firstIndex { $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }
            if let index = index {
                let indexPath = IndexPath(row: index, section: 1)
                if let discountCell = wSelf.tableView.cellForRow(at: indexPath) as? PurchasePriceCell {
                    discountCell.leftDiscountTime = leftTime
                }
            }
        }
    }
    
    @objc func showLifetimeOfferGift() {
        if self.timer.isTiming || DiscountIAPManager.shared.isShowDiscount() {
            let title = "🎉" + "Congratulations!".localStr()
            let message = "You’ve received a one-time lifetime offer!".localStr()
            
            let giftView = UIImageView(image: Reasource.named("gift_box"))
            giftView.contentMode = .scaleAspectFit
            giftView.size = CGSizeMake(120.ckValue(), 120.ckValue())
                    
            let alertView = KakaAlertView.popupAlertView(title: title, message: message, customView: giftView, confirmTitle: "OK".localStr(), action: { [weak self] style in
                guard let wSelf = self else { return }
                let index = wSelf.priceArray.firstIndex { $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }
                if let index = index {
                    let indexPath = IndexPath(row: index, section: 1)
                    if let discountCell = wSelf.tableView.cellForRow(at: indexPath) as? PurchasePriceCell {
                        discountCell.kaka_playShakeAnim(4)
                    }
                }
            }, inView: appKeyWindow ?? self.view)
            alertView.tag = 1286
            alertView.isShowCloseButton = false
        }
    }
}

#endif
