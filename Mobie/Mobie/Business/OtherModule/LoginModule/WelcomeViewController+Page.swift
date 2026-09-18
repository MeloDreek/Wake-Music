//
//  WelcomeViewController+Login.swift
//  AppLock
//
//  Created by Kaka Inc. on 2024/1/2.
//

import KakaFoundation
import KakaUIKit
import KakaObjcKit
import AppGroupKit
import RevenueCat
import ProgressHUD


extension WelcomeViewController {
    
    // 引导支付
    @objc func continePurchase() {
        guard !isProcessingPurchase, let vModel = self.selectModel else { return }
        
        isProcessingPurchase = true
        ProgressHUD.animate("Processing...".localStr())
        self.purchaseManager.startPurcharge(product: vModel) { [weak self] (enInfo) in
            guard let wSelf = self else { return }
                        
            wSelf.verfityPurchageRecord()
            
        } failBlock: { [weak self] errorMsg in
            ProgressHUD.dismiss()
            guard let wSelf = self else { return }
            wSelf.isProcessingPurchase = false
            if errorMsg == KakaError.youhaveCanceled.errorDescription {
                wSelf.view.makeToast(errorMsg)
            }else{
                wSelf.showOneAlert(message: errorMsg)
            }
        }
                
    }
    
    // 设置播放器样式
    func setupPlayerStyle(_ isFreeEnd: Bool) {
#if Target_Mobie_Pro
        MusicConfigManager.shared.playerStyle = .tape1
        var defaultModel = MusicConfigManager.shared.playbackModel
        defaultModel.backgroundType = .defaultType
        defaultModel.backgroundConfig = .coverAssetColor
        MusicConfigManager.shared.playbackModel = defaultModel
#else
        MusicConfigManager.shared.playerStyle = isFreeEnd ? .defaultCircle : .tape1
        var defaultModel = MusicConfigManager.shared.playbackModel
        defaultModel.backgroundType = .defaultType
        defaultModel.backgroundConfig = isFreeEnd ? .gaussianBlur : .coverAssetColor
        MusicConfigManager.shared.playbackModel = defaultModel
#endif
        
    }
    
    // 跳转
    @objc func finishAllPage() {
        
        self.view.isUserInteractionEnabled = false
        AppLocalManager.shared.isFirstLaunch = false

        let ani: CATransition = CATransition()
        ani.type = CATransitionType(rawValue: "cube")
        ani.subtype = CATransitionSubtype.fromRight
        ani.duration = 0.35
        ani.isRemovedOnCompletion = true
        appKeyWindow?.layer.add(ani, forKey: nil)
        
        self.perform(#selector(dismissAnimation), with: nil, afterDelay: ani.duration - 0.1)
    }
    
    @objc func dismissAnimation() {
        
        self.setupPlayerStyle(true)
        
        let scene = view.window?.windowScene?.delegate as? SceneDelegate
        scene?.window?.rootViewController = scene?.modeCoordinator?.restoredRootController()
        scene?.window?.makeKeyAndVisible()
        
    }
    
    
    
}
