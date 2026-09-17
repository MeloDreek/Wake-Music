//
//  MusicPlayerViewController.swift
//  Wakemusic
//
//  Created by Melo on 7/29/24.
//

import KakaFoundation
import KakaUIKit
import KakaObjcKit
import AVKit
import PanModal
import NVActivityIndicatorView
import AppGroupKit
import Kingfisher
import Combine

class MusicPlayerViewController: SuperViewController {
    
    deinit {
        if kaka_IsiPhone() && OrientationManager.shared.isLandscape {
            OrientationManager.shared.forceUpdate(to: false)
        }
        debugPrint("### MusicPlayerViewController ###")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
                
        self.darkAppearanceClick()
                
        contentView.addSubview(backView)
        contentView.addSubview(collectionView)
        
        contentView.addSubview(grayView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(playDefaultControl)
        contentView.addSubview(playTapeControl)
        contentView.addSubview(auxiliaryBottomBar)
//        contentView.addSubview(playVinylControl)
    }
                
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let isRTL = UIView.userInterfaceLayoutDirection(for: self.view.semanticContentAttribute) == .rightToLeft

        let btnSize = 44.ckValue()
#if targetEnvironment(macCatalyst)
        backView.frame = contentView.bounds
        collectionView.frame = contentView.bounds
        
        contentView.addSubview(resizeButton)
        var resizeLeft = OrientationManager.shared.isLandscape ? contentView.width - btnSize * 2 - 30.ckValue() : contentView.width - btnSize - 20.ckValue()
        if isRTL {
            resizeLeft = 50.ckValue()
        }
        resizeButton.frame =  CGRectMake(resizeLeft, 10, btnSize, btnSize)
        
#else
        contentView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height)
        backView.frame = contentView.bounds
        collectionView.frame = contentView.bounds
#endif
        
        let isFullScreen = OrientationManager.shared.isLandscape
        let controlWidth = contentView.width / (isFullScreen ? 2 : 1)
        let controlHeight = OrientationManager.shared.playerControlHeight
                                
        grayView.frame = CGRectMake((contentView.width - grayView.width) / 2, kStatusBarHeight + 10.ckValue(), grayView.width, grayView.height)
        nameLabel.frame = CGRectMake((contentView.width - nameLabel.width) / 2, 18.ckValue(), nameLabel.width, nameLabel.height)
                
        playDefaultControl.frame = CGRectMake(isRTL && isFullScreen ? contentView.width / 2 : 0, contentView.height - controlHeight, controlWidth, controlHeight)
        playTapeControl.frame = CGRectMake(isRTL && isFullScreen ? contentView.width / 2 : 0, contentView.height - controlHeight, controlWidth, controlHeight)
        layoutAuxiliaryControls()
//        playVinylControl.frame = CGRectMake(isRTL && isFullScreen ? contentView.width / 2 : 0, contentView.height - controlHeight, controlWidth, controlHeight)
        if lastPlayerLayoutSize != contentView.bounds.size {
            lastPlayerLayoutSize = contentView.bounds.size
            refreshUIViewAction()
        }
        
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        ImageCache.default.clearMemoryCache()
        
        self.title = "Wakemusic".localStr()
                                
        self.refreshUIViewAction()
        self.configMusicPlayer()
        self.hiddenNavgationUI()
        self.resetPlayerConfig()
        
        self.perform(#selector(showTapePlayerUI), with: nil, afterDelay: 1)
        self.perform(#selector(showAirPlayTips), with: nil, afterDelay: 3)
    }
    
    func resetPlayerConfig() {
        if UserInfoManager.shared.isVIP() { return }
        
        if !MusicConfigManager.shared.playerStyle.isDefaultStyle() {
            MusicConfigManager.shared.playerStyle = .defaultCircle
        }
        var defaultModel = MusicConfigManager.shared.playbackModel
        defaultModel.backgroundType = .defaultType
        defaultModel.backgroundConfig = .gaussianBlur
        MusicConfigManager.shared.playbackModel = defaultModel
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.collectionView.reloadData()
    }
    
    // 引导新用户点击切换磁带卡片
    @objc func showTapePlayerUI() {
        guard !AppLocalManager.shared.isShowTapePlayer else { return }
        
        guard let basicCell = self.collectionView.cellForItem(at: IndexPath(row: 0, section: 0)) as? PlayerBasicCollectCell else { return }
        
        basicCell.miniLyricView.aniLyricLabel.isHidden = true
        let coverFrame = basicCell.coverImgView.convert(basicCell.coverImgView.bounds, to: self.view)
        
        let guideView = PlayerGuideView(frame: self.view.bounds, targetFrame: coverFrame)
        guideView.onClickTap = { [weak self] () in
            AppLocalManager.shared.isShowTapePlayer = true
            basicCell.miniLyricView.aniLyricLabel.isHidden = false
            self?.presentPlayerStyle()
        }
        self.view.addSubview(guideView)
    }
    
    @objc func showAirPlayTips() {
        
        guard let playingMusic = KakaMusicPlayer.shared.playingMusic, playingMusic.fileSourceType != .demoFile else { return }
        
        if self.playDefaultControl.isHidden || self.playDefaultControl.airplayButton.isHidden {
            return
        }
        
        if !MusicConfigManager.shared.playerStyle.isDefaultStyle() {
            return
        }
        
        if AppLocalManager.shared.isShowAirPlay > 2 {
            return
        }
                
        let popView = CMPopTipView(message: "Connect Your Car and TV".localStr())
        popView?.hasShadow = true
        popView?.has3DStyle = false
        popView?.borderColor = UIColor.white
        popView?.dismissTapAnywhere = true
        popView?.backgroundColor = appMainColor
        popView?.textColor = UIColor.deAccent
        popView?.presentPointing(at: self.playDefaultControl.airplayButton, in: self.view, animated: true)
        
        AppLocalManager.shared.isShowAirPlay += 1
    }
    
    @objc func dismissItemAction() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    @objc func darkAppearanceClick() {
        self.overrideUserInterfaceStyle = .dark
        self.navigationController?.overrideUserInterfaceStyle = .dark
        self.setNeedsStatusBarAppearanceUpdate()
        
        self.navigationController?.navigationBar.tintColor = .white
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { context in
#if !targetEnvironment(macCatalyst)
            let isLandscape = size.width > size.height
            if kaka_IsiPhone() {
                OrientationManager.shared.forceUpdate(to: isLandscape)
            }else{
                OrientationManager.shared.forceUpdate(to: isLandscape)
                OrientationManager.shared.isShowBigLyric = isLandscape
            }
            debugPrint("切换完成！当前方向：\(isLandscape ? "横屏" : "竖屏")")
#endif
        } completion: { context in
            
        }
    }
    
#if targetEnvironment(macCatalyst)
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
                
                // Space/Return remain available while the transport is collapsed.
                if !MusicConfigManager.shared.playerStyle.isTapeStyle() {
                    self.playDefaultControl.playButtonClick(self.playDefaultControl.playButton)
                } else {
                    self.playTapeControl.playButtonClick(self.playTapeControl.playButton)
                }
                
                
            } else if key.keyCode == .keyboardUpArrow {
                didHandleEvent = false
            } else if key.keyCode == .keyboardDownArrow {
                didHandleEvent = false
            } else if key.keyCode == .keyboardLeftArrow {
                didHandleEvent = true
                
                KakaMusicPlayer.shared.playLastItem()
                
            } else if key.keyCode == .keyboardRightArrow {
                didHandleEvent = true
                KakaMusicPlayer.shared.playNextItem()
            } else if key.keyCode == .keyboardEscape {
                let playerDelegate = UIApplication.shared.delegate as? AppDelegate
                playerDelegate?.restartMainWindow()
            }
        }

        if didHandleEvent == false {
            super.pressesBegan(presses, with: event)
        }
    }
    
    lazy var resizeButton: UIButton = {
        let view = UIButton(type: .custom)
        view.addTarget(self, action: #selector(resizeButtonClick(_:)), for: .touchUpInside)
        view.setImage(Reasource.systemNamed("arrowtriangle.left.and.line.vertical.and.arrowtriangle.right", color: .white), for: .normal)
        view.setImage(Reasource.systemNamed("arrowtriangle.right.and.line.vertical.and.arrowtriangle.left", color: .white), for: .selected)
        return view
    }()
    
    @objc func resizeButtonClick(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        
        OrientationManager.shared.isLandscape = sender.isSelected
        OrientationManager.shared.isShowBigLyric = !sender.isSelected
        
    }
    
#endif
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()
    
    var serverModel: ServerConfigModel?
    var isShowingPlaylist = false
    var isShowingMoreConfig = false
    var returnToLyricsAfterQueue = false
    private var lastPlayerLayoutSize: CGSize = .zero
        
    lazy var dataArray: [PlayerGroupStyle] = {
        return [PlayerGroupStyle]()
    }()

    // MARK:  懒加载
    
    lazy var grayView: UIView = {
        let view = UIView(frame: CGRectMake(0, 0, 40.ckValue(), 5.ckValue()))
        view.isHidden = kaka_IsMacOS()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 2.5.ckValue()
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let text = "Wakemusic".localStr()
        let font = UIFontLight(13.ckValue())
        
        let view = UILabel(frame: CGRectMake(0, 0, text.width(font), font.lineHeight))
        view.isHidden = !kaka_IsMacOS()
        view.text = text
        view.font = font
        view.textAlignment = .center
        view.textColor = grayView.backgroundColor
        return view
    }()
    
    lazy var backView: PlayBackgroundView = {
        let view = PlayBackgroundView(frame: contentView.bounds)
        return view
    }()
    
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.contentView.bounds, collectionViewLayout: flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.isPagingEnabled = true
        view.bounces = false
        view.isScrollEnabled = false
        view.alwaysBounceVertical = false
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .automatic
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? UISemanticContentAttribute.forceRightToLeft : UISemanticContentAttribute.forceLeftToRight
        view.register(PlayerBasicCollectCell.self, forCellWithReuseIdentifier: "PlayerBasicCollectCell")
        view.register(PlayerTapeCollectCell.self, forCellWithReuseIdentifier: "PlayerTapeCollectCell")
        view.register(PlayerVinylCollectCell.self, forCellWithReuseIdentifier: "PlayerVinylCollectCell")
        view.register(PlayerLyricCollectCell.self, forCellWithReuseIdentifier: "PlayerLyricCollectCell")
        view.register(HorizonLyricsViewCell.self, forCellWithReuseIdentifier: "HorizonLyricsViewCell")
        view.register(PlayerQueueCollectCell.self, forCellWithReuseIdentifier: "PlayerQueueCollectCell")
        view.register(PlayerMoreConfigCollectCell.self, forCellWithReuseIdentifier: "PlayerMoreConfigCollectCell")
        return view
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        
        let isFullScreen = OrientationManager.shared.isLandscape
        let controlWidth = contentView.width / (isFullScreen ? 2 : 1)
        
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSizeMake(controlWidth, self.contentView.height)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        return layout
    }()
    
    var auxiliaryBottomReservedHeight: CGFloat {
        PlayerBottomBar.reservedHeight(safeBottom: view.safeAreaInsets.bottom)
    }

    func layoutAuxiliaryControls() {
        let split = OrientationManager.shared.isLandscape
        let rtl = UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute) == .rightToLeft
        let width = contentView.bounds.width / (split ? 2 : 1)
        auxiliaryBottomBar.frame = CGRect(x: rtl && split ? width : 0,
                                         y: contentView.bounds.height - auxiliaryBottomReservedHeight,
                                         width: width, height: 64)
        for cell in collectionView.visibleCells {
            (cell as? PlayerQueueCollectCell)?.bottomReservedHeight = auxiliaryBottomReservedHeight
            (cell as? PlayerMoreConfigCollectCell)?.bottomReservedHeight = auxiliaryBottomReservedHeight
        }
    }

    lazy var auxiliaryBottomBar: PlayerBottomBar = {
        let bar = PlayerBottomBar()
        bar.isHidden = true
        bar.onPlaylist = { [weak self] in
            guard let self else { return }
            self.setPlaylistVisible(!self.isShowingPlaylist)
        }
        bar.onMore = { [weak self] in
            guard let self else { return }
            self.setMoreConfigVisible(!self.isShowingMoreConfig)
        }
        return bar
    }()

    lazy var playDefaultControl: PlayControlDefaultView = {
        let isFullScreen = OrientationManager.shared.isLandscape
        let controlWidth = contentView.width / (isFullScreen ? 2 : 1)
        let controlHeight = OrientationManager.shared.playerControlHeight
        
        let view = PlayControlDefaultView(frame: CGRectMake(0, 0, controlWidth, controlHeight))
        view.delegate = self
        view.isHidden = !MusicConfigManager.shared.playerStyle.isDefaultStyle()
        return view
    }()
    
    lazy var playTapeControl: PlayControlTapeView = {
        let controlHeight = OrientationManager.shared.playerControlHeight

        let view = PlayControlTapeView(frame: CGRectMake(0, 0, self.playDefaultControl.width, controlHeight))
        view.delegate = self
        view.isHidden = !MusicConfigManager.shared.playerStyle.isTapeStyle()
        return view
    }()
    
//    lazy var playVinylControl: PlayControlVinylView = {
//        let controlHeight = OrientationManager.shared.playerControlHeight
//
//        let view = PlayControlVinylView(frame: CGRectMake(0, 0, self.playDefaultControl.width, controlHeight))
//        view.delegate = self
//        view.isHidden = !MusicConfigManager.shared.playerStyle.isVinylStyle()
//        return view
//    }()
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
}

#if !targetEnvironment(macCatalyst)
extension MusicPlayerViewController: PanModalPresentable {
    
    var panScrollable: UIScrollView? {
        // The queue owns its scrolling/reordering; PanModal must not pin its content offset.
        return (isShowingPlaylist || isShowingMoreConfig) ? nil : collectionView
    }

    // Never infer the player's height from the number of tracks in the queue.
    var shortForm: PanModalHeight { .maxHeight }
    var longForm: PanModalHeight { .maxHeight }

    func shouldRespond(to panModalGestureRecognizer: UIPanGestureRecognizer) -> Bool {
        if isShowingMoreConfig {
            guard let cell = collectionView.visibleCells.first(where: { $0 is PlayerMoreConfigCollectCell }) as? PlayerMoreConfigCollectCell else { return false }
            let point = panModalGestureRecognizer.location(in: cell)
            let translation = panModalGestureRecognizer.translation(in: cell)
            return point.y - translation.y < cell.tableView.frame.minY
        }
        guard isShowingPlaylist else { return true }
        guard let cell = collectionView.visibleCells.first(where: { $0 is PlayerQueueCollectCell }) as? PlayerQueueCollectCell else {
            return false
        }
        let table = cell.tableView
        guard !table.hasActiveDrag, !table.hasActiveDrop else { return false }
        // Reserve the queue and transport for their own gestures. Dismiss from the header.
        // Evaluate the gesture's origin, so crossing the boundary cannot strand the sheet.
        let point = panModalGestureRecognizer.location(in: cell)
        let translation = panModalGestureRecognizer.translation(in: cell)
        return point.y - translation.y < table.frame.minY
    }

    var orientation: PanModalOrientation {
        return .vertical
    }
    
    var verticalOffset: CGFloat {
        return 0
    }
    
    var horizontalOffset: CGFloat {
        return 0
    }

    var allowsExtendedPanScrolling: Bool {
        return !isShowingPlaylist && !isShowingMoreConfig
    }
    
    var shouldRoundTopCorners: Bool {
        return true
    }
    
    var cornerRadius: CGFloat {
        let cornerRadius = (self.view.window?.screen ?? UIScreen.main).cornerRadius()
        return cornerRadius * 0.9
    }

    var anchorModalToLongForm: Bool {
        return true
    }
        
    var transitionAnimationOptions: UIView.AnimationOptions {
        return [.allowUserInteraction, .beginFromCurrentState]
    }
    
    var showDragIndicator: Bool {
        return false
    }
    
}
#endif
