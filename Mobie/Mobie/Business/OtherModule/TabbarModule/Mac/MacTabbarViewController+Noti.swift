//
//  MacTabbarViewController+Noti.swift
//  Mobie
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import UniformTypeIdentifiers

extension MacTabbarViewController {
    
    func addObserviseNoti() {
        
        // 即将进入前台
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForegroundNoti), name: UIApplication.willEnterForegroundNotification, object: nil)
                                
        // 检测支付记录
        self.appstoreManager.verifyPaymentRecords()
                        
    }
    
    // 监听App即将进入前台
    @objc func willEnterForegroundNoti() {
        
        let playingMusic = KakaMusicPlayer.shared.playingMusic
                
        self.toolbarView.musicModel = playingMusic
        self.toolbarView.playStatus = KakaMusicPlayer.shared.playbackStatus
        
        KakaMusicPlayer.shared.restoreRemoteQueueIfNeeded()
        
    }
    
    // 回到欢迎页面
    func switchAppKeyWindow() {
        let tabbarVC = WelcomeViewController()
        let scene = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate
        scene?.window?.rootViewController = tabbarVC
        scene?.window?.makeKeyAndVisible()
    }
}

