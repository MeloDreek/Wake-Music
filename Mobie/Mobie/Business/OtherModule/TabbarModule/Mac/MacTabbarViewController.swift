//
//  MacTabbarViewController.swift
//  Mobie
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import Kingfisher
import Combine
import StoreKit

var macTabbarHeight: CGFloat {
    get {
        return 60.ckValue()
    }
}

class MacTabbarViewController: UISplitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preSetupSubViews()
        self.viewDidLayoutSubviews()
        self.preSetupHandleBuness()
    }
    
    private func preSetupSubViews() {
        
        self.primaryEdge = .leading
        self.primaryBackgroundStyle = .sidebar
        self.preferredSplitBehavior = .tile
        self.preferredDisplayMode = .twoBesideSecondary
        
        self.preferredPrimaryColumnWidth = 230
        self.minimumPrimaryColumnWidth = 230
        self.maximumPrimaryColumnWidth = 300
        
        self.view.addSubview(toolbarView)
        toolbarView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(toolbarView.bounds.height)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    private func preSetupHandleBuness() {
        // 设置视图控制器数组，顺序是 primary, supplementary, secondary
        self.setViewController(primaryVC, for: .primary)
                                        
        self.configMusicPlsyer()
        self.registerDragDrop()
        self.addObserviseNoti()
        
        self.fileWatcher.startWatching()
                
#if !Target_Mobie_Pro
        self.perform(#selector(guideShowShareAction), with: nil, afterDelay: 3)
#endif

#if targetEnvironment(macCatalyst)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if let titleBar = windowScene.titlebar {
            titleBar.titleVisibility = .visible
            titleBar.toolbar = nil
        }
#endif
        
    }
    
    @objc func guideShowShareAction() {
        
//        debugPrint("用户信息 = \(UserInfoManager.shared.toJSONString() ?? "")")
        
//        if UserInfoManager.shared.payGoodsId != nil { return }
        
//        if AppLocalManager.shared.isFreeMacos { return }
        
//        self.showOneAlert(title: "Reminder".localStr(), message: "The macOS version has temporarily enabled all premium features. Please share this news with your friends.".localStr()) {
//            let storeURL = Application.wakeMusic.appstoreURL()
//
//            let shareVC = UIActivityViewController(activityItems: [storeURL], applicationActivities: nil)
//            shareVC.popoverPresentationController?.sourceView = self.toolbarView
//            shareVC.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
//                AppLocalManager.shared.isFreeMacos = true
//                if completed {
//                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
//                        SKStoreReviewController.requestReview(in: windowScene)
//                    }
//                }
//                UIPasteboard.general.string = storeURL.absoluteString
//                self.view.makeToast("Copied".localStr())
//            }
//            self.present(shareVC, animated: true, completion: nil)
//        }
    }
    
    var cancellables = Set<AnyCancellable>()
    
    // 上次按的时间
    var lastPressTime: Date?
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var didHandleEvent = false
        
        for press in presses {
            guard let key = press.key else { continue }
            debugPrint("敲了 = \(key)")
            if key.keyCode == .keyboardSpacebar || key.keyCode == .keyboardReturnOrEnter {
                didHandleEvent = true
                
                if let lastPressTime = lastPressTime, Date().timeIntervalSince(lastPressTime) < 0.2 {
                    // 如果上次按下时间与当前时间间隔不到2秒，则不处理
                    return
                }
                
                self.lastPressTime = Date()
                
                let playButton = self.toolbarView.playButton
                self.toolbarView.playButtonClick(playButton)
                
            } else if key.keyCode == .keyboardUpArrow {
                didHandleEvent = false
            } else if key.keyCode == .keyboardDownArrow {
                didHandleEvent = false
            } else if key.keyCode == .keyboardLeftArrow {
                didHandleEvent = true
                
                let lastButton = self.toolbarView.lastButton
                self.toolbarView.lastButtonClick(lastButton)
                
            } else if key.keyCode == .keyboardRightArrow {
                didHandleEvent = true
                
                let nextButton = self.toolbarView.nextButton
                self.toolbarView.nextButtonClick(nextButton)
            }
        }

        if didHandleEvent == false {
            super.pressesBegan(presses, with: event)
        }
    }
    
    var selectItemType: PrimaryCellItemType = .allMusics
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        ImageCache.default.clearMemoryCache()
    }
    
    lazy var primaryVC: PrimaryToolViewController = {
        let view = PrimaryToolViewController()
        view.delegate = self
        return view
    }()
    
    lazy var contentDict: [String: KakaNavigationController] = {
        return [String: KakaNavigationController]()
    }()
    
    lazy var viewModel: MusicViewModel = {
        let baseFileURL = SandboxFileManager.shared.basePublicFileURL()
        let vm = MusicViewModel(baseFileURL)
        return vm
    }()
    
    lazy var appstoreManager: AppStoreKitManager = {
        return AppStoreKitManager()
    }()
    
    lazy var toolbarView: PlayerControlToolBarView = {
        let view = PlayerControlToolBarView(frame: CGRectMake(0, 0, self.view.bounds.width, playingHeight))
        view.toolDelegate = self
        return view
    }()
    
    lazy var fileWatcher: DocumentFolderWatcher = {
        let baseFileURL = SandboxFileManager.shared.basePublicFileURL()
        let watcher = DocumentFolderWatcher(baseFileURL)
        watcher.delegate = self
        return watcher
    }()
    
    var musicVC: MusicsViewController? {
        get {
            // 获取导航控制器
            guard let navVC = self.contentDict[PrimaryCellItemType.allMusics.rawValue] else {
                return nil
            }
            
            // 过滤出符合条件的 MusicsViewController
            let musicVCs = navVC.viewControllers.compactMap { $0 as? MusicsViewController }.filter { $0.viewModel.isBaseDoc }
            
            // 返回第一个符合条件的 MusicsViewController
            return musicVCs.first
        }
    }

    
}

extension MacTabbarViewController: PrimaryToolViewControllerDelegate {
    
    func primaryControllerDidCellItem(controller: PrimaryToolViewController, itemType: PrimaryCellItemType) {
        
        self.selectItemType = itemType
        
        switch itemType {
            
        case .allMusics:
            let baseURL = SandboxFileManager.shared.basePublicFileURL()
            let musicVC = self.contentDict[itemType.rawValue] ?? KakaNavigationController(rootViewController: MusicsViewController(baseURL))
            self.contentDict[itemType.rawValue] = musicVC
            self.setViewController(musicVC, for: .secondary)
            break
        case .artist:
            let artistVC = self.contentDict[itemType.rawValue] ?? KakaNavigationController(rootViewController: ArtistListViewController())
            self.contentDict[itemType.rawValue] = artistVC
            self.setViewController(artistVC, for: .secondary)
            break
        case .album:
            let albumVC = self.contentDict[itemType.rawValue] ?? KakaNavigationController(rootViewController: AlbumListViewController())
            self.contentDict[itemType.rawValue] = albumVC
            self.setViewController(albumVC, for: .secondary)
            break
        case .genre:
            let genreVC = self.contentDict[itemType.rawValue] ?? KakaNavigationController(rootViewController: GenreListViewController())
            self.contentDict[itemType.rawValue] = genreVC
            self.setViewController(genreVC, for: .secondary)
            break
        
        case .download:
            let downloadVC = self.contentDict[itemType.rawValue] ?? KakaNavigationController(rootViewController: DownloadViewController())
            self.contentDict[itemType.rawValue] = downloadVC
            self.setViewController(downloadVC, for: .secondary)
            break
        case .connect:
            let connectVC = self.contentDict[itemType.rawValue] ?? KakaNavigationController(rootViewController: ConnectListViewController())
            self.contentDict[itemType.rawValue] = connectVC
            self.setViewController(connectVC, for: .secondary)
            break
            
        case .selectEngine:
            let faqsVC = self.contentDict[itemType.rawValue] ?? KakaNavigationController(rootViewController: PlayerEngineViewController())
            self.contentDict[itemType.rawValue] = faqsVC
            self.setViewController(faqsVC, for: .secondary)
            break
        case .guideiOS:
            let guideVC = self.contentDict[itemType.rawValue] ?? KakaNavigationController(rootViewController: LargeImageViewController(.WakeMusic))
            self.contentDict[itemType.rawValue] = guideVC
            self.setViewController(guideVC, for: .secondary)
            break
        case .settings:
            let settingVC = self.contentDict[itemType.rawValue] ?? KakaNavigationController(rootViewController: ProfileViewController())
            self.contentDict[itemType.rawValue] = settingVC
            self.setViewController(settingVC, for: .secondary)
            break
        
        }
    }
    
}
