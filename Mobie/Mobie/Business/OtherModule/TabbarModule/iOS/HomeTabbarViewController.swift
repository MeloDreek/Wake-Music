//
//  HomeTabbarViewController.swift
//  Wakemusic
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
        
        /*
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
        */
        
        self.perform(#selector(setupPlayerMinibar), with: nil, afterDelay: 0.5)
    }
    
    @objc func setupPlayerMinibar() {
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
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-app_tabbarHeight)
            }
            make.height.equalTo(toolbarView.bounds.height)
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

    // MARK:  懒加载
    
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
    
}
