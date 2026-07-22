//
//  WelcomeTapeBtnView.swift
//  Mobie
//
//  Created by 张文 on 6/14/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KSPlayer
import Combine
import WakeMusicPlayer


class WelcomeTapeBtnView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubViews()
        self.layoutSubviews()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        self.addSubview(backBtnView)
        self.addSubview(playButton)
        self.addSubview(lastButton)
        self.addSubview(nextButton)
        self.addSubview(moreButton)
        self.addSubview(playlistButton)
        self.addSubview(pauseIconView)
//#if !targetEnvironment(macCatalyst)
        self.addSubview(tipsLabel)
//#endif
                
        self.addSubview(playIconView)
        self.addSubview(nextIconView)
        self.addSubview(lastIconView)
        self.addSubview(listIconView)
        self.addSubview(moreIconView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
//#if !targetEnvironment(macCatalyst)
        tipsLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-kaka_safeAreaInsets().bottom / 2 - 10.ckValue())
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
        }
//#endif
        
        pauseIconView.snp.remakeConstraints { make in
            make.centerX.equalTo(playButton)
//#if !targetEnvironment(macCatalyst)
            make.bottom.equalTo(tipsLabel.snp.top).offset(-10.ckValue())
//#else
//            make.bottom.equalToSuperview().offset(-13.ckValue())
//#endif
            make.size.equalTo(pauseIconView.layer.cornerRadius * 2)
        }
        
        playButton.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(pauseIconView.snp.top).offset(-8.ckValue())
            make.size.equalTo(playBtnSize)
        }
        
        lastButton.snp.remakeConstraints { make in
            make.right.equalTo(playButton.snp.left)
            make.centerY.equalTo(playButton)
            make.size.equalTo(playBtnSize)
        }
        
        nextButton.snp.remakeConstraints { make in
            make.left.equalTo(playButton.snp.right)
            make.centerY.equalTo(playButton)
            make.size.equalTo(playBtnSize)
        }
        
        playlistButton.snp.remakeConstraints { make in
            make.right.equalTo(lastButton.snp.left)
            make.centerY.equalTo(playButton)
            make.size.equalTo(playButton)
        }
        
        moreButton.snp.remakeConstraints { make in
            make.left.equalTo(nextButton.snp.right)
            make.centerY.equalTo(playButton)
            make.size.equalTo(playButton)
        }
        
        backBtnView.snp.remakeConstraints { make in
            make.left.equalTo(playlistButton).offset(-2.ckValue())
            make.top.equalTo(playButton).offset(-3.ckValue())
            make.right.equalTo(moreButton).offset(2.ckValue())
            make.bottom.equalTo(playButton).offset(-3.ckValue())
        }
        
        
        playIconView.snp.remakeConstraints { make in
            make.centerX.equalTo(playButton)
            make.bottom.equalTo(backBtnView.snp.top).offset(-5.ckValue())
            make.size.equalTo(playIconView)
        }
        
        nextIconView.snp.remakeConstraints { make in
            make.centerX.equalTo(nextButton)
            make.centerY.equalTo(playIconView)
            make.size.equalTo(nextIconView)
        }
        
        lastIconView.snp.remakeConstraints { make in
            make.centerX.equalTo(lastButton)
            make.centerY.equalTo(playIconView)
            make.size.equalTo(lastIconView)
        }
        
        listIconView.snp.remakeConstraints { make in
            make.centerX.equalTo(playlistButton)
            make.centerY.equalTo(playIconView)
            make.size.equalTo(listIconView)
        }
        
        moreIconView.snp.remakeConstraints { make in
            make.centerX.equalTo(moreButton)
            make.centerY.equalTo(playIconView)
            make.size.equalTo(moreIconView)
        }
        
    }
    
    private func setupCusBuness() {
        
//#if !targetEnvironment(macCatalyst)
        self.startBlinkingAnimation()
//#endif
        
        //  播放状态
        KakaMusicPlayer.shared.$playbackStatus.receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updatePlayStatus(status)
            }.store(in: &cancellables)
    }
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()
    
    var playBtnSize: CGFloat {
        get {
            switch kaka_osType() {
            case .macOS:
                let contentWidth = self.bounds.size.width * 0.85
                let btnWidth = (contentWidth * 0.8) / 5.0
                
                let maxSize = 90.ckValue()
                return min(maxSize, btnWidth)
            case .iPadOS:
                let contentWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
                return (contentWidth * 0.68) / 5.0
            case .iOS:
                let isLandscape = OrientationManager.shared.isLandscape
                let screenWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
                return isLandscape ? screenWidth * 0.8 / 5.0 : (screenWidth - 50) / 5.0
            }
        }
    }
    
    var playIconSize: CGFloat {
        get {
            return playBtnSize * 16.0 / 75.0
        }
    }
    
    var onPlayBlock: (()->Void)?
    
    
    lazy var wakePlayer: WakeMusicPlayer = {
        return WakeMusicPlayer()
    }()
    
    // MARK:  懒加载
    lazy var backBtnView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        return view
    }()
    
    lazy var playButton: UIButton = {
        let view = UIButton(type: .custom)
        view.isSelected = KakaMusicPlayer.shared.isPlaying
        view.frame.size = CGSizeMake(playBtnSize, playBtnSize)
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playButtonClick(_:)), for: .touchUpInside)
        view.setBackgroundImage(UIImage(named: "tape_red_normal"), for: .normal)
        view.setBackgroundImage(UIImage(named: "tape_red_highted"), for: .highlighted)
        return view
    }()
    lazy var playIconView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "player_tape_play"))
        view.frame = CGRectMake(0, 0, playIconSize, playIconSize)
        view.contentMode = .scaleAspectFit
        return view
    }()
    lazy var pauseIconView: UIButton = {
        let size = CGSizeMake(10.ckValue(), 10.ckValue())
        let view = UIButton()
        view.isSelected = KakaMusicPlayer.shared.isPlaying
        view.setBackgroundImage(UIImage.createImage(color: .systemRed, size: size), for: .normal)
        view.setBackgroundImage(UIImage.createImage(color: .systemGreen, size: size), for: .selected)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = size.width / 2
        return view
    }()
    
    lazy var lastButton: UIButton = {
        let view = UIButton(type: .custom)
        view.frame.size = playButton.frame.size
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playLastButtonClick(_:)), for: .touchUpInside)
        view.setBackgroundImage(UIImage(named: "tape_black_normal"), for: .normal)
        view.setBackgroundImage(UIImage(named: "tape_black_highted"), for: .highlighted)
        return view
    }()
    lazy var lastIconView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "player_tape_last"))
        view.frame = playIconView.bounds
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var nextButton: UIButton = {
        let view = UIButton(type: .custom)
        view.frame.size = playButton.frame.size
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playNextButtonClick(_:)), for: .touchUpInside)
        view.setBackgroundImage(UIImage(named: "tape_black_normal"), for: .normal)
        view.setBackgroundImage(UIImage(named: "tape_black_highted"), for: .highlighted)
        return view
    }()
    lazy var nextIconView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "player_tape_next"))
        view.frame = playIconView.bounds
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var moreButton: UIButton = {
        let view = UIButton(type: .custom)
        view.frame.size = playButton.frame.size
        view.setBackgroundImage(UIImage(named: "tape_black_normal"), for: .normal)
        view.setBackgroundImage(UIImage(named: "tape_black_highted"), for: .highlighted)
        view.showsMenuAsPrimaryAction = true
        view.addTarget(self, action: #selector(moreButtonClick(_:)), for: .touchDown)
        return view
    }()
    lazy var moreIconView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "player_tape_more"))
        view.frame = playIconView.bounds
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var playlistButton: UIButton = {
        let view = UIButton(type: .custom)
        view.frame.size = playButton.frame.size
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playlistButtonClick(_:)), for: .touchUpInside)
        view.setBackgroundImage(UIImage(named: "tape_black_normal"), for: .normal)
        view.setBackgroundImage(UIImage(named: "tape_black_highted"), for: .highlighted)
        return view
    }()
    lazy var listIconView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "player_tape_list"))
        view.frame = playIconView.bounds
        view.contentMode = .scaleAspectFit
        return view
    }()
    
//#if !targetEnvironment(macCatalyst)
    lazy var tipsLabel: UILabel = {
        let view = UILabel()
        view.text = "Please tap the red button".localStr()
        view.numberOfLines = 0
        view.textAlignment = .center
        view.textColor = .white
        view.font = UIFontBold(13.ckValue())
        return view
    }()
    
    func startBlinkingAnimation() {
        // 设置初始透明度
        self.tipsLabel.alpha = 1.0
        
        // 创建闪烁动画
        UIView.animate(withDuration: 1.0, animations: {
            self.tipsLabel.alpha = 0.1
        }) { _ in
            UIView.animate(withDuration: 1.0, animations: {
                self.tipsLabel.alpha = 1.0
            }) { _ in
                // 递归调用以实现循环
                self.startBlinkingAnimation()
            }
        }
    }
//#endif
    
}

extension WelcomeTapeBtnView {
    
    // 播放状态
    func updatePlayStatus(_ playStatus: KSPlayerState) {
        let isPlaying = KakaMusicPlayer.shared.isPlaying
        self.playButton.isSelected = isPlaying
        self.pauseIconView.isSelected = isPlaying
    }
    
    
    // 播放暂停
    @objc func playButtonClick(_ sender: UIButton) {
        let clickURL = URL(fileURLWithPath: Reasource.fullFilePath("tape_click.wav"))
        self.wakePlayer.play(url: clickURL) { [weak self] () in
            self?.playDemoMusic()
        }
    }
    
    // 更多按钮
    @objc func moreButtonClick(_ sender: UIButton) {
        let clickURL = URL(fileURLWithPath: Reasource.fullFilePath("tape_click.wav"))
        self.wakePlayer.play(url: clickURL)
        self.playButton.kaka_playShakeAnim()
    }
    
    // 上一首
    @objc func playLastButtonClick(_ sender: UIButton) {
        let clickURL = URL(fileURLWithPath: Reasource.fullFilePath("tape_click.wav"))
        self.wakePlayer.play(url: clickURL)
        self.playButton.kaka_playShakeAnim()
    }
    
    // 下一首
    @objc func playNextButtonClick(_ sender: UIButton) {
        let clickURL = URL(fileURLWithPath: Reasource.fullFilePath("tape_click.wav"))
        self.wakePlayer.play(url: clickURL)
        self.playButton.kaka_playShakeAnim()
    }

    // 播放列表
    @objc func playlistButtonClick(_ sender: UIButton) {
        let clickURL = URL(fileURLWithPath: Reasource.fullFilePath("tape_click.wav"))
        self.wakePlayer.play(url: clickURL)
        self.playButton.kaka_playShakeAnim()
    }
    
    func playDemoMusic() {
//#if !targetEnvironment(macCatalyst)
        self.tipsLabel.isHidden = !KakaMusicPlayer.shared.isPlaying
//#endif
        
        if KakaMusicPlayer.shared.isPlaying {
            KakaMusicPlayer.shared.pause()
        }else{
            KakaMusicPlayer.shared.play()
            self.perform(#selector(self.startPlayAnimation), with: nil, afterDelay: 5)
        }
        
    }
    
    @objc func startPlayAnimation() {
        self.onPlayBlock?()
    }
}
