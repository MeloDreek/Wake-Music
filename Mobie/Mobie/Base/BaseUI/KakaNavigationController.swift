//
//  KakaNavigationController.swift
//   PassLock
//
//  Created by Melo Dreek on 2023/2/2.
//

import KakaUIKit
import AppGroupKit
import KakaFoundation

class KakaNavigationController: UINavigationController, UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.preSetupSubViews()
        self.preInitSubFrames()
        self.preHanleBuness()
        
    }
    
    private func preSetupSubViews() {
        self.delegate = self

        let barAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
//        barAppearance.configureWithDefaultBackground()  // 默认透明色
//        barAppearance.configureWithOpaqueBackground() // 不透明，纯色
        barAppearance.configureWithTransparentBackground() // 底层透明，但内容穿透
        self.navigationBar.scrollEdgeAppearance = barAppearance
    }
    
    private func preInitSubFrames() {
        
    }
    
    private func preHanleBuness() {
        // 主题色
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        
        // 监听外观模式
        NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: Notification.Name(kAppearanceChangedKey), object: nil)
        
        self.appearanceChanged()
    }
    
    // 监听 tintColor 的变化
    @objc func appModeStyleChanged(_ noti: Notification) {
        guard let newColor = noti.object as? UIColor else { return }
        self.navigationBar.tintColor = newColor
    }
    
    @objc func appearanceChanged() {
        let userInterfaceStyle = AppLocalManager.shared.appearanceStyle.userInterfaceStyle()
        self.overrideUserInterfaceStyle = userInterfaceStyle
        self.setNeedsStatusBarAppearanceUpdate()
    }
}


extension KakaNavigationController {
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if self.viewControllers.count > 0 {
            viewController.hidesBottomBarWhenPushed = false
        }
        
        super.pushViewController(viewController, animated: true)
    }
    
    @objc func backAction() {
        self.popViewController(animated: true)
    }
    
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if viewController == self.viewControllers.first {
            self.interactivePopGestureRecognizer?.delegate = self.delegate! as? UIGestureRecognizerDelegate
        } else {
            self.interactivePopGestureRecognizer?.delegate = nil
        }
    }
    
    // MARK:  导航栏和旋转相关 
    override var shouldAutorotate: Bool {
        return self.topViewController?.shouldAutorotate ?? false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return self.topViewController?.supportedInterfaceOrientations ?? .allButUpsideDown
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return self.topViewController?.preferredInterfaceOrientationForPresentation ?? .portrait
    }
    
    override var prefersStatusBarHidden: Bool {
        return self.topViewController?.prefersStatusBarHidden ?? false
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return self.topViewController?.preferredStatusBarUpdateAnimation ?? .none
    }

}


