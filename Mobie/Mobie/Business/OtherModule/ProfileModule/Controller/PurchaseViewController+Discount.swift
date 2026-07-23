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
        
        // 2. 获取最新的折扣状态
        var discountManager = DiscountIAPManager.read()
        
        // 首次进入 或 超过冷却期后进入：重新开启 24 小时倒计时
        if discountManager.lastDiscountTime == nil || (discountManager.remainingDiscountTime() <= 0 && discountManager.isShowDiscount()) {
            DiscountIAPManager.markDiscountStarted()
            discountManager = DiscountIAPManager.read() // 刷新本地变量
            NotificationCenter.default.post(name: Notification.Name(kStartDiscountPriceKey), object: nil)
        }
        
        let isShowDiscount = discountManager.isShowDiscount() && discountManager.remainingDiscountTime() > 0

        // 3. 根据状态过滤商品
        if isShowDiscount {
            // 展示 198 终身折扣价
            self.priceArray = models.filter { $0.productIdentifier != PurchaseStoreID.lifetime298.rawValue }
            self.selectModel = self.priceArray.first { $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }
            self.tableView.reloadData()
            
            // 开启倒计时（传入开始时间）
            if let startTime = discountManager.lastDiscountTime {
                self.timeSpaceRepeat(lastDiscountTime: startTime, maxDiscountTime: discountManager.maxDiscountTime)
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
        
        // 2. 建议频率 0.1 秒（显示毫秒足够流畅）或 1.0 秒
        self.timer.startTimer(seconds: 0.1, repeats: true, callSoon: true) { [weak self] vTime in
            guard let wSelf = self else { return }
            
            // 3. 纯内存计算！绝不在 Timer 内部做 AES 解密和磁盘 I/O
            let now = Date().timeIntervalSince1970
            let passTime = now - lastDiscountTime
            let leftTime = max(0, maxDiscountTime - passTime)
            
//             debugPrint("leftTime = \(leftTime)")
            
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
}

#endif
