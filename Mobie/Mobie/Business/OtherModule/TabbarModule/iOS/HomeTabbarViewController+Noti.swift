//
//  HomeTabbarViewController+Noti.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/19.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import UniformTypeIdentifiers
import StoreKit

extension HomeTabbarViewController {
    
    func addObserviseNoti() {
        
        // 即将进入前台
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForegroundNoti), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // 外观模式已变更
        NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: Notification.Name(kAppearanceChangedKey), object: nil)
        
        // 主题颜色已经变化
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        
        // 开始倒计时
        NotificationCenter.default.addObserver(self, selector: #selector(setupDiscountTimer), name: Notification.Name(rawValue: kStartDiscountPriceKey), object: nil)
        
        // 前往连接页面
        NotificationCenter.default.addObserver(self, selector: #selector(selectConnectPageNoti(_:)), name: Notification.Name(kJumpConnectPageKey), object: nil)
        
        // 开始倒计时
        if DiscountIAPManager.shared.isShowDiscount() {
            self.perform(#selector(setupDiscountTimer), with: nil, afterDelay: 1)
        }
        
        // 新增了下载文件
        DownloadManager.shared.$taskArray.receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.perform(#selector(self?.updateDownloadCount), with: nil, afterDelay: 1)
            }.store(in: &cancellables)
        
        // 修改了Minibar
        MusicConfigManager.shared.$miniPlayerUI.receive(on: DispatchQueue.main)
            .sink { [weak self] minibarStyle in
                self?.localMusicCountChanged()
            }.store(in: &cancellables)
        
        // 暗黑浅色模式
        self.appearanceChanged()
        
        // 隐藏MINI播放器
        self.localMusicCountChanged()
        
        // 如果是领取了优惠用户，引导好评
        self.perform(#selector(guideFiveStarReview), with: nil, afterDelay: 9)
        
        // 检测支付记录
        AppStoreKitManager.shared.verifyPaymentRecords()
                
    }
    
    // 新增文件下载任务
    @objc func updateDownloadCount() {
        let taskArray = DownloadManager.shared.taskArray
        
        self.tabBar.items?[2].badgeValue = taskArray.isEmpty ? nil : "\(taskArray.count)"
        
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(taskArray.count)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = taskArray.count
        }
    }
    
    // 前往连接页面
    @objc func selectConnectPageNoti(_ noti: Notification) {
        
        guard let index = self.children.firstIndex(where: {
            guard let nav = $0 as? KakaNavigationController else { return false }
            return nav.viewControllers.contains { $0 is ConnectListViewController }
        }) else { return }
        
        self.selectedIndex = index
    }
    
    @objc func appModeStyleChanged(_ noti: Notification) {
        guard let newColor = noti.object as? UIColor else { return }
        self.tabBar.tintColor = newColor
    }
    
    @objc func appearanceChanged() {
        self.overrideUserInterfaceStyle = AppLocalManager.shared.appearanceStyle.userInterfaceStyle()
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    @objc func guideFiveStarReview() {
        
        if UIApplication.shared.applicationState != .active {
            return
        }
        
        if AppLocalManager.shared.isReceiveOffer {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }
    
    // 监听App即将进入前台
    @objc func willEnterForegroundNoti() {
        let playingMusic = KakaMusicPlayer.shared.playingMusic
                
        self.toolbarView.musicModel = playingMusic
        self.floatingView.musicModel = playingMusic
        
        if let playingMusic = playingMusic, !playingMusic.isLocalFile() {
            var sortedArray = ConnectConfigManager.shared.lastPlaylist.sorted(by: { element1, element2 in
                return element1.sortAnotherModel(model2: element2, sortType: MusicConfigManager.shared.sortType)
            })
            
            if !UserInfoManager.shared.isVIP() {
                let demoMusic = MusicItemModel.demoMusicModel()
                self.toolbarView.musicModel = demoMusic
                sortedArray = [demoMusic]
            }
            
            KakaMusicPlayer.shared.musicArray = sortedArray
            KakaMusicPlayer.shared.tempMusicArray = sortedArray
        }
        
    }
    
    // 回到欢迎页面
    func switchAppKeyWindow() {
        let tabbarVC = WelcomeViewController()
        let scene = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate
        scene?.window?.rootViewController = tabbarVC
        scene?.window?.makeKeyAndVisible()
    }
}
