//
//  HomeTabbarViewController.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/18.
//

import KakaFoundation
import AppGroupKit
import CoreMotion
import StoreKit
import Kingfisher
import Combine

class HomeTabbarViewController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.systemBackground
        if #available(iOS 17.0, *) {
            self.traitOverrides.horizontalSizeClass = .unspecified
        }
        
        self.preSetupSubViews()
        self.viewDidLayoutSubviews()
        self.preSetupHandleBuness()
    }
    
    private func preSetupSubViews() {
        self.handleAppSwitchedMode(UITraitCollection.current.userInterfaceStyle)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
       
    }
    
    private func preSetupHandleBuness() {
        
        self.configMusicPlsyer()
        self.configChildController()
        self.addObserviseNoti()
        
        self.fileWatcher.startWatching()
        
        self.view.addSubview(toolbarView)
        toolbarView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            if kaka_IsiPhone() {
                if #available(iOS 26.0, *) {
                    make.bottom.equalTo(self.tabBar.snp.top).offset(-5.ckValue())
                }else{
                    make.bottom.equalTo(self.tabBar.snp.top)
                }
            }else{
                make.bottom.equalToSuperview().offset(-app_tabbarHeight)
            }
            make.height.equalTo(toolbarView.bounds.height)
        }
        
        self.view.addSubview(floatingView)
        floatingView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20.ckValue())
            if kaka_IsiPhone() {
                make.bottom.equalTo(self.tabBar.snp.top).offset(-10.ckValue())
            }else{
                make.bottom.equalToSuperview().offset(-app_tabbarHeight-10.ckValue())
            }
            make.size.equalTo(floatingView.fullSize)
        }
                
    }
    
    @objc func setupDiscountTimer() {
        if !DiscountIAPManager.shared.isShowDiscount() {
            return
        }
        
        if UserInfoManager.shared.isVIP() {
            return
        }
        
        self.timer.startTimer(seconds: 0.01, repeats: true, callSoon: true) { [weak self] vTime in
            guard let wSelf = self else { return }
            guard let lastDiscountTime = DiscountIAPManager.shared.lastDiscountTime else {
                DiscountIAPManager.shared.lastDiscountTime = Date().timeIntervalSince1970
                return
            }
            
            let nowDate = Date()
            
            var leftTime = nowDate.timeIntervalSince1970 - lastDiscountTime
            leftTime = wSelf.maxDiscountTime - leftTime
            
            if leftTime < 0 {
                vTime.stopTimer()
            }
            
            NotificationCenter.default.post(name: Notification.Name(kDiscountLeftTimeKey), object: nil, userInfo: ["leftTime": leftTime])
            
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { context in
            
        } completion: { [weak self] context in
            self?.floatingView.correctLocation()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard let userInterfaceStyle = previousTraitCollection?.userInterfaceStyle else { return }
        self.handleAppSwitchedMode(userInterfaceStyle == .dark ? .light : .dark)
    }
    
    // 切换黑白模式的通知
    func handleAppSwitchedMode(_ style: UIUserInterfaceStyle) {
                
        let scrollEdgeAppearance = UITabBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        scrollEdgeAppearance.configureWithTransparentBackground() // 底层透明，但内容穿透
        self.tabBar.scrollEdgeAppearance = scrollEdgeAppearance
        
        let standardAppearance = UITabBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        standardAppearance.configureWithDefaultBackground()  // 默认透明色
        self.tabBar.standardAppearance = standardAppearance
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        ImageCache.default.clearMemoryCache()
    }
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()

    
    // 默认倒计时3小时
    let maxDiscountTime: Double = DiscountIAPManager.shared.maxDiscountTime
    
    // MARK:  懒加载
    
    lazy var timer: KakaTimer = {
        let timer = KakaTimer()
        return timer
    }()
    
    lazy var fileWatcher: DocumentFolderWatcher = {
        let baseFileURL = SandboxFileManager.shared.basePublicFileURL()
        let watcher = DocumentFolderWatcher(baseFileURL)
        watcher.delegate = self
        return watcher
    }()
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // 确保 viewControllers 不为空，且 selectedIndex 在有效范围内
        if let viewControllers = self.viewControllers,
           viewControllers.count > 0,
           selectedIndex < viewControllers.count {
            return viewControllers[selectedIndex].supportedInterfaceOrientations
        }
        
        return .all
    }
    
    lazy var toolbarView: PlayerControlToolBarView = {
        let view = PlayerControlToolBarView(frame: CGRectMake(0, 0, self.view.bounds.width, playingHeight))
        view.backgroundColor = self.tabBar.backgroundColor
        view.toolDelegate = self
        return view
    }()
    
    lazy var floatingView: PlayerControlFloatView = {
        let view = PlayerControlFloatView(frame: .zero)
        view.toolDelegate = self
        return view
    }()
        
}
