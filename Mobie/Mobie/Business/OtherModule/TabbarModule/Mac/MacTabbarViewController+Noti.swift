//
//  MacTabbarViewController+Noti.swift
//  Mobie
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import AdSupport
import UniformTypeIdentifiers

extension MacTabbarViewController {
    
    func addObserviseNoti() {
        
        // 即将进入前台
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForegroundNoti), name: UIApplication.willEnterForegroundNotification, object: nil)
                                
        // 限时折扣礼包(仅限macOS)
        NotificationCenter.default.addObserver(self, selector: #selector(macOSshowReceiveGiftbox), name: Notification.Name(kLifetimeDiscountKey), object: nil)
                
        // 检测支付记录
        self.appstoreManager.verifyPaymentRecords()
                        
    }
    
    // 监听App即将进入前台
    @objc func willEnterForegroundNoti() {
        
        let playingMusic = KakaMusicPlayer.shared.playingMusic
                
        self.toolbarView.musicModel = playingMusic
        self.toolbarView.playStatus = KakaMusicPlayer.shared.playbackStatus
        
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
    
    // 显示限时折扣大礼包
    @objc func showReceiveGiftbox() {
        
        if UserInfoManager.shared.isVIP() || AppLocalManager.shared.isFirstLaunch {
            return
        }
        
        self.macOSshowReceiveGiftbox()
    }
    
    @objc func macOSshowReceiveGiftbox() {
//        if !DiscountIAPManager.shared.isShowDiscount() {
//            DiscountIAPManager.reset()
//        }
        
        AppStoreKitManager.presentPurcharseVC(self)
    }
    
    // 回到欢迎页面
    func switchAppKeyWindow() {
        let tabbarVC = WelcomeViewController()
        let scene = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate
        scene?.window?.rootViewController = tabbarVC
        scene?.window?.makeKeyAndVisible()
    }
}



