//
//  VideoPlayerController.swift
//  Mobie
//
//  Created by 张文 on 3/26/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KSPlayer

class VideoPlayerController: SuperViewController {
    
//    init(_ videoURL: URL) {
//        super.init(nibName: nil, bundle: nil)
//        self.videoURL = videoURL
//    }
//    
//    @MainActor public required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    override func preSetupSubViews() {
//        self.overrideUserInterfaceStyle = .dark
//
//        super.preSetupSubViews()
//        contentView.addSubview(playerView)
//    }
//    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        
//        playerView.frame = contentView.bounds
//    }
//    
//    override func preSetupHandleBuness() {
//        super.preSetupHandleBuness()
//        
//        KSOptions.supportedInterfaceOrientations = .allButUpsideDown
//        self.view.backgroundColor = UIColor.black
//        KSOptions.secondPlayerType = KSMEPlayer.self
//        KSOptions.topBarShowInCase = .always
//        KSOptions.isAutoPlay = true
//        KSOptions.topBarShowInCase = .always
//        
//        let option = KSOptions()
//        self.playerView.set(url: self.videoURL, options: option)
//        let coverURL = URL(fileURLWithPath: Reasource.fullFilePath("loading_bgView@3x.png"))
//        let resource = KSPlayerResource(url: self.videoURL, options: option, name: self.videoURL.lastPathComponent, cover: coverURL)
//        self.playerView.set(resource: resource)
//        
//        self.playerView.nameLabel.text = resource.name
//        
//        self.playerView.tintColor = UIColor.systemBlue
//        
//        self.playerView.cusBackButton.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
//    }
//    
//    
//    var videoURL: URL!
//    
//    private var isFullScreen: Bool = false
//    private var statusHiden = false
//    
//    lazy var playerView: KakaVideoPlayerView = {
//        let view = KakaVideoPlayerView(frame: self.contentView.bounds)
//        view.translatesAutoresizingMaskIntoConstraints = false
//        view.tintColor = UIColor.systemBlue
//        return view
//    }()
//    
//    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        navigationController?.navigationBar.isHidden = true
//        UIApplication.shared.isIdleTimerDisabled = true
//    }
//    
//    @objc func backButtonClick() {
//        
//        self.changeDeviceOrientation()
//    }
//
//    // 设置横竖屏
//    func changeDeviceOrientation() {
//        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
//        
//        if #available(iOS 16.0, *) {
//            
//            self.setNeedsUpdateOfSupportedInterfaceOrientations()
//            self.navigationController?.setNeedsUpdateOfSupportedInterfaceOrientations()
//            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: isFullScreen ? .portrait : .landscapeRight)) { error in
//                debugPrint("切换失败 = \(error.localizedDescription)")
//                self.playerView.updateUI(isLandscape: !self.isFullScreen)
//                
//                self.isFullScreen = !self.isFullScreen
//            }
//            
//        } else {
//            UIDevice.current.setValue(isFullScreen ? UIInterfaceOrientation.portrait.rawValue : UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
//            UINavigationController.attemptRotationToDeviceOrientation()
//            self.playerView.updateUI(isLandscape: self.isFullScreen)
//            
//            isFullScreen = !isFullScreen
//        }
//        
//    }
//    
//    
//    
//    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//        super.viewWillTransition(to: size, with: coordinator)
//        debugPrint("新的尺寸 = \(size)")
//        
//        self.isFullScreen = size.width > size.height
//    }
//    
//    override var prefersStatusBarHidden: Bool {
//        return isFullScreen ? true : false
//    }
//    
//    override var preferredStatusBarStyle: UIStatusBarStyle {
//        return .lightContent
//    }
//    
//    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
//        return .all
//    }
//    
//    override var shouldAutorotate: Bool {
//        return false
//    }
//        
//   
//    
//    
//}
//
//class KakaVideoPlayerView: IOSVideoPlayerView {
//    
//    override func customizeUIComponents() {
//        super.customizeUIComponents()
//                
//        self.navigationBar.backgroundColor = .random()
//        self.backButton.setImage(Reasource.systemNamed("chevron.left", color: .white), for: .normal)
//        self.replayButton.setImage(UIImage(named: "video_play"), for: .normal)
//        
//#if !targetEnvironment(macCatalyst)
//        let config1 = UIImage.SymbolConfiguration(pointSize: 10.ckValue(), weight: .light)
//        let image1 = Reasource.systemNamed("circle.fill", color: .white, config: config1)
//
//        let config2 = UIImage.SymbolConfiguration(pointSize: 20.ckValue(), weight: .light)
//        let image2 = Reasource.systemNamed("circle.fill", color: .white, config: config2)
//
//        self.toolBar.timeSlider.setThumbImage(image1, for: .normal)
//        self.toolBar.timeSlider.setThumbImage(image2, for: .highlighted)
//#endif
//        
//        (self.seekToView as? SeekView)?.seekToViewImage.image = Reasource.systemNamed("forward.fill", color: .white)
//        self.navigationBar.isHidden = true
//        
//        self.lockButton.setImage(Reasource.systemNamed("lock.open", color: .white), for: .normal)
//        self.lockButton.setImage(Reasource.systemNamed("lock", color: .white), for: .selected)
//
//        
//        self.toolBar.pipButton.setImage(Reasource.systemNamed("pip.enter", color: .white), for: .normal)
//        self.toolBar.pipButton.setImage(Reasource.systemNamed("pip.exit", color: .white), for: .selected)
//        self.toolBar.playButton.setImage(Reasource.systemNamed("play.fill", color: .white), for: .normal)
//        self.toolBar.playButton.setImage(Reasource.systemNamed("pause.fill", color: .white), for: .selected)
//        self.toolBar.srtButton.setImage(Reasource.systemNamed("captions.bubble", color: .white), for: .normal)
//        self.toolBar.definitionButton.setImage(Reasource.systemNamed("arrow.up.right.video", color: .white), for: .normal)
//        self.toolBar.audioSwitchButton.setImage(Reasource.systemNamed("waveform", color: .white), for: .normal)
//        self.toolBar.videoSwitchButton.setImage(Reasource.systemNamed("video.badge.ellipsis", color: .white), for: .normal)
//        self.toolBar.playbackRateButton.setImage(Reasource.systemNamed("speedometer", color: .white), for: .normal)
//        
//    }
//    
//    lazy var cusBackButton: UIButton = {
//        let view = UIButton(type: .custom)
//        view.setImage(Reasource.systemNamed("chevron.left", color: .white), for: .normal)
//        return view
//    }()
//    
//    
//    lazy var nameLabel: UILabel = {
//        let view = UILabel()
//        view.font = UIFontLight(16.ckValue())
//        view.textColor = .white
//        return view
//    }()
    
}
