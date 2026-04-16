//
//  PlayerControlToolBarView.swift
//  Wake Music
//
//  Created by Melo on 7/29/24.
//

import KakaFoundation
import AppGroupKit
import KSPlayer
import MarqueeLabel
import NVActivityIndicatorView
import Combine
import KakaTaglibKit


var playingHeight: CGFloat {
    get {
        return kaka_IsMacOS() ? 68 : 60.ckValue()
    }
}


protocol PlayingControlViewDelegate: AnyObject {
    
    // 首次点击播放上一次的歌曲
    func musicControlViewDidFirstPlay(view: UIView, model: MusicItemModel?)
    
    // 点击播放列表
    func musicControlViewDidPlaylistButton(view: UIView, playlistButton: UIButton)
    
    // 点击进入播放页面
    func musicControlViewDidClick(view: UIView)
    
    // 长按或双击定位播放中的cell
    func musicControlViewDidLongDoubleClick(view: UIView)
}

class PlayerControlToolBarView: UIToolbar {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        
        self.addSubview(playingControl)
        
        playingControl.addSubview(coverBackView)
        coverBackView.addSubview(coverImgView)
        playingControl.addSubview(nameLabel)
        playingControl.addSubview(timeLabel)
        
        playingControl.addSubview(playButton)
        playingControl.addSubview(loadingView)
        playingControl.addSubview(nextButton)
        playingControl.addSubview(lastButton)
        playingControl.addSubview(playlistButton)
        playingControl.addSubview(progressView)
    }
    
    private func preSetupContains() {
        
        if #available(iOS 26.0, *) {
            playingControl.snp.makeConstraints { make in
                make.leading.equalTo(20.ckValue())
                make.centerX.equalToSuperview()
                make.bottom.equalToSuperview()
                make.height.equalToSuperview()
            }
        }else{
            playingControl.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        coverBackView.snp.makeConstraints { make in
            make.leading.equalTo(20.ckValue())
            make.centerY.equalToSuperview()
            make.size.equalTo(coverBackView.layer.cornerRadius * 2)
        }
        
        coverImgView.snp.makeConstraints { make in
            make.center.equalTo(coverBackView)
            make.size.equalTo(coverImgView.layer.cornerRadius * 2)
        }
        
        
#if targetEnvironment(macCatalyst)
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverBackView.snp.trailing).offset(15.ckValue())
            make.height.greaterThanOrEqualTo(0)
            make.centerY.equalToSuperview().offset(-timeLabel.font.lineHeight / 2)
            make.trailing.equalTo(lastButton.snp.leading).offset(-10.ckValue())
        }
        
        timeLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom)
            make.size.greaterThanOrEqualTo(0)
        }
        
        playButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(playSize)
        }
        
        nextButton.snp.makeConstraints { make in
            make.leading.equalTo(playButton.snp.trailing).offset(20.ckValue())
            make.centerY.equalTo(playButton)
            make.size.equalTo(otherSize)
        }
        
        lastButton.snp.makeConstraints { make in
            make.trailing.equalTo(playButton.snp.leading).offset(-20.ckValue())
            make.centerY.equalTo(playButton)
            make.size.equalTo(nextButton)
        }
        
        playlistButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20.ckValue())
            make.centerY.equalToSuperview()
            make.size.equalTo(otherSize)
        }
        
#else
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverBackView.snp.trailing).offset(15.ckValue())
            make.height.greaterThanOrEqualTo(0)
            make.centerY.equalToSuperview().offset(-timeLabel.font.lineHeight / 2)
            if kaka_IsiPhone() {
                make.trailing.equalTo(playButton.snp.leading).offset(-10.ckValue())
            }else{
                make.trailing.equalTo(lastButton.snp.leading).offset(-10.ckValue())
            }
        }
        
        timeLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom)
            make.size.greaterThanOrEqualTo(0)
        }
        
        if kaka_IsiPhone() {
            playlistButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().inset(20.ckValue())
                make.centerY.equalToSuperview()
                make.size.equalTo(otherSize)
            }
        }else{
            playlistButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().inset(20.ckValue())
                make.centerY.equalToSuperview()
                make.size.equalTo(otherSize)
            }
            
            nextButton.snp.makeConstraints { make in
                make.trailing.equalTo(playlistButton.snp.leading).offset(-30.ckValue())
                make.centerY.equalToSuperview()
                make.size.equalTo(otherSize)
            }
        }
        
        playButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            if kaka_IsiPhone() {
                make.trailing.equalTo(playlistButton.snp.leading).offset(-10.ckValue())
            }else{
                make.trailing.equalTo(nextButton.snp.leading).offset(-10.ckValue())
            }
            make.size.equalTo(playSize)
        }
        
        lastButton.snp.makeConstraints { make in
            make.trailing.equalTo(playButton.snp.leading).offset(-20.ckValue())
            make.centerY.equalToSuperview()
            make.size.equalTo(kaka_IsiPhone() ? playlistButton : nextButton)
        }
        
#endif
        
        progressView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(progressView.height)
        }
                
        loadingView.snp.makeConstraints { make in
            make.center.equalTo(playButton)
            make.size.equalTo(loadingView.size)
        }
        
    }
    
    private func preSetupHandleBuness() {
        
        self.backgroundColor = .clear
        self.setupAppearance()
        
        //  播放状态
        KakaMusicPlayer.shared.$playbackStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.playStatus = status
            }.store(in: &cancellables)
        
        // 当前时间
        KakaMusicPlayer.shared.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentTime in
                guard let wSelf = self else { return }
                if wSelf.loadingView.isAnimating {
                    self?.stopAnimating()
                }
                self?.updateDuration(curTime: currentTime, endTime: KakaMusicPlayer.shared.totalTime)
            }.store(in: &cancellables)
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.playingMusicChanged()
            }.store(in: &cancellables)
        
        // 当前音乐模型
        MusicConfigManager.shared.$isShowExtension
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.playingMusicChanged()
            }.store(in: &cancellables)
        
        // 主题色变化了
        NotificationCenter.default.addObserver(self, selector: #selector(appModeSwitchChanged), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        
        self.appModeSwitchChanged()
        
        let doubleClick = UITapGestureRecognizer(target: self, action: #selector(longDoubleClick))
        doubleClick.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleClick)
        
        let longClick = UILongPressGestureRecognizer(target: self, action: #selector(longDoubleClick))
        self.addGestureRecognizer(longClick)
    }
    
    @objc func longDoubleClick() {
        self.toolDelegate?.musicControlViewDidLongDoubleClick(view: self)
    }
    
    @objc func appModeSwitchChanged() {
        
        if self.isHidden { return }
        
        playButton.setBackgroundImage(Reasource.systemNamed("play.circle.fill", color: appMainColor, config: playBtnConfig), for: .normal)
        playButton.setBackgroundImage(Reasource.systemNamed("pause.circle.fill", color: appMainColor, config: playBtnConfig), for: .selected)
        
        lastButton.setImage(Reasource.systemNamed("backward.end", color: appMainColor, config: otherBtnConfig).flippedImage(), for: .normal)
        nextButton.setImage(Reasource.systemNamed("forward.end", color: appMainColor, config: otherBtnConfig).flippedImage(), for: .normal)
        playlistButton.setImage(Reasource.systemNamed("list.triangle", color: appMainColor, config: otherBtnConfig), for: .normal)
    }
    
    // 当前播放的音乐变化了，立马刷新页面
    @objc func playingMusicChanged() {
        
        if self.isHidden { return }
        
        if self.musicModel != KakaMusicPlayer.shared.playingMusic {
            self.updateDuration(curTime: 0, endTime: 0)
        }
        
        self.musicModel = KakaMusicPlayer.shared.playingMusic
    }
    
    @objc func clickMusicView() {
        self.toolDelegate?.musicControlViewDidClick(view: self)
    }
    
    // 点击播放
    @objc func playButtonClick(_ sender: UIButton) {
        
        if KakaMusicPlayer.shared.playingMusic == nil {
            self.toolDelegate?.musicControlViewDidFirstPlay(view: self, model: self.musicModel)
            return
        }
        
        if KakaMusicPlayer.shared.isPlaying {
            KakaMusicPlayer.shared.pause()
        }else{
            KakaMusicPlayer.shared.play()
        }
        
    }
    
    @objc func lastButtonClick(_ sender: UIButton) {
        KakaMusicPlayer.shared.playLastItem()
        
        self.musicModel = KakaMusicPlayer.shared.playingMusic
    }
    
    @objc func nextButtonClick(_ sender: UIButton) {
        
        KakaMusicPlayer.shared.playNextItem()
        
        self.musicModel = KakaMusicPlayer.shared.playingMusic
    }
    
    @objc func playlistButtonClick(_ sender: UIButton) {
        self.toolDelegate?.musicControlViewDidPlaylistButton(view: self, playlistButton: sender)
    }
    
    func setupAppearance() {
#if !compiler(>=6.0)
        if #available(iOS 15.0, *) {
            let scrollEdgeAppearance = UIToolbarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
            scrollEdgeAppearance.configureWithTransparentBackground() // 底层透明，但内容穿透
            self.scrollEdgeAppearance = scrollEdgeAppearance
        }
        
        let compactAppearance = UIToolbarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        compactAppearance.configureWithTransparentBackground() // 不透明，纯色
        self.compactAppearance = compactAppearance
        
        let standardAppearance = UIToolbarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        standardAppearance.configureWithDefaultBackground()  // 默认透明色
        self.standardAppearance = standardAppearance
#endif
    }
    
    // MARK:  GET && SET
    
    private var cancellables = Set<AnyCancellable>()
    
    
    weak var toolDelegate: PlayingControlViewDelegate?
    
    var playSize: CGFloat {
        get {
            let vaule = kaka_IsiPhone() ? 0.60 : 0.8
            return playingHeight * vaule
        }
    }
    
    var otherSize: CGFloat {
        get {
            let vaule = kaka_IsiPhone() ? 1 : 0.72
            return playSize * vaule
        }
    }
    
    var playBtnConfig: UIImage.SymbolConfiguration {
        get {
            let vaule = kaka_IsiPhone() ? 0.5 : 0.55
            let config = UIImage.SymbolConfiguration(pointSize: playSize * vaule, weight: .bold)
            return config
        }
    }
    
    var otherBtnConfig: UIImage.SymbolConfiguration {
        get {
            let vaule = kaka_IsiPhone() ? 0.48 : 0.55
            let config = UIImage.SymbolConfiguration(pointSize: otherSize * vaule, weight: .light)
            return config
        }
    }
    
    var playStatus = KSPlayerState.preparing {
        didSet {
            
            if self.isHidden { return }
                                    
            self.playButton.isSelected = KakaMusicPlayer.shared.isPlaying
                        
            switch playStatus {
            case .initialized, .buffering, .preparing:
                
                self.playButton.isHidden = true
                if !self.loadingView.isAnimating {
                    self.loadingView.startAnimating()
                }
                
                self.coverBackView.pauseRotating()  // 暂停旋转
                
                break
            case .bufferFinished:
                self.perform(#selector(stopAnimating), with: nil, afterDelay: 0.2)

                self.coverBackView.resumeRotating()
                
                break
            case .readyToPlay:
                self.coverBackView.startRotating() // 即将解码
                break
            case .paused:
                self.perform(#selector(stopAnimating), with: nil, afterDelay: 0.2)

                self.coverBackView.pauseRotating()  // 暂停旋转
                
                break
            case .playedToTheEnd, .error:
                self.perform(#selector(stopAnimating), with: nil, afterDelay: 0.2)
                
                self.coverBackView.pauseRotating()   // 停止并重置旋转
                
                break
            }
        }
    }
    
    @objc func stopAnimating() {
        self.playButton.isHidden = false
        self.loadingView.stopAnimating()
    }
    
    var musicModel: MusicItemModel? {
        didSet {
            
            if self.isHidden { return }
            
            guard let musicModel = self.musicModel else {
                self.playButton.isSelected = false
                return
            }
            
            self.appModeSwitchChanged()
                        
            let addStr = MusicConfigManager.shared.isShowExtension ? musicModel.addPathExtension() : ""
            nameLabel.text = musicModel.showTitleName() + addStr + "  "
            let coverImage: UIImage? = (musicModel.musicCoverImage() ?? TaglibMetadataParser.extractCoverArt(from: musicModel.mediaPlayURL)) ?? musicModel.placeImage()

            coverImgView.kf.setImage(with: musicModel.coverThumbnailURL(), placeholder: coverImage)

            if !self.playButton.isSelected {
                let lastPlayTime = MusicConfigManager.shared.lastPlayTime
                let lastTotalTime = MusicConfigManager.shared.lastTotalTime
                if lastPlayTime > 0 && lastTotalTime > 0 && MusicConfigManager.shared.isLastCache {
                    self.progressView.progress = lastPlayTime / lastTotalTime
                    self.updateDuration(curTime: lastPlayTime, endTime: lastTotalTime)
                                                            
                }else{
                    self.progressView.progress = 0
                    self.updateDuration(curTime: 0, endTime: TimeInterval(musicModel.durationSeconds))
                }
            }
                        
            self.layoutIfNeeded()
            
        }
    }
    
    // 更新播放时间
    func updateDuration(curTime: TimeInterval, endTime: TimeInterval) {
        
//        debugPrint("curTime = \(curTime), endTime = \(endTime)")
        
        if self.isHidden { return }
        
        self.curTime = curTime

        guard let model = self.musicModel else {
            self.timeLabel.text = "00:00 - 00:00"
            self.progressView.progress = 0
            return
        }
        
        var progress = curTime / endTime
        progress = min(progress, 1)
        
        var timeStr = "\(curTime.stringValue) - \(endTime.stringValue)"
        if curTime <= 0 && endTime <= 0 {
            let durationStr = model.durationTimeStr().isEmpty ? "00:00" : model.durationTimeStr()
            timeStr = model.durationSeconds == 0 ? "00:00 - 00:00" : "00:00 - \(durationStr)"
        }
        
        self.timeLabel.text = timeStr
        self.progressView.progress =  progress
    }
    
    
    // MARK:  懒加载
    var curTime: TimeInterval = 0
    
    lazy var playingControl: UIToolbar = {
        let view = UIToolbar()
        if #available(iOS 26.0, *) {
            view.layer.masksToBounds = true
            view.layer.cornerRadius = playingHeight / 2
            view.backgroundColor = UIColor.systemBackground
        }else{
            view.backgroundColor = .clear
        }
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(clickMusicView))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    lazy var coverBackView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "music_heijiao"))
        view.contentMode = .scaleAspectFill
        view.layer.masksToBounds = true
        view.layer.cornerRadius = playingHeight / 2 * (kaka_IsMacOS() ? 0.68 : 0.8)
        return view
    }()
    
    lazy var coverImgView: UIImageView = {
        let musicModel = KakaMusicPlayer.shared.playingMusic
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.masksToBounds = true
        view.layer.cornerRadius = coverBackView.layer.cornerRadius - 8.ckValue()
        view.kf.setImage(with: musicModel?.coverThumbnailURL(), placeholder: musicModel?.placeImage())
        return view
    }()
    
    lazy var nameLabel: MarqueeLabel = {
        let view = MarqueeLabel()
        view.text = KakaMusicPlayer.shared.playingMusic?.showTitleName()
        view.textColor = .label
        view.font = UIFontLight(15.ckValue())
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        return view
    }()
    
    lazy var timeLabel: UILabel = {
        let view = UILabel()
        view.text = "00:00 - 00:00"
        view.textColor = .secondaryLabel
        view.font = UIFontLight(12.ckValue())
        view.textAlignment = nameLabel.textAlignment
        return view
    }()
    
    lazy var progressView: LineProgressView = {
        let view = LineProgressView(frame: CGRect(origin: .zero, size: CGSize(width: self.width, height: 1.5.ckValue())))
        view.backgroundColor = .clear
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(progressViewTapped(_:)))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    @objc func progressViewTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: progressView)
        let width = progressView.bounds.width
        let progress = TimeInterval(location.x / width) // 计算点击位置对应的进度
                        
        if !KakaMusicPlayer.shared.isPlaying {
            KakaMusicPlayer.shared.play()
        }
        
        let playTime = KakaMusicPlayer.shared.playerView.totalTime * progress
        if KakaMusicPlayer.shared.isPlaying {
            KakaMusicPlayer.shared.seek(time: playTime)
        }else{
            KakaMusicPlayer.shared.play()
        }
    }
    
    private(set) lazy var playButton: UIButton = {
        let view = UIButton(type: .custom)
        view.isSelected = KakaMusicPlayer.shared.isPlaying
        view.imageView?.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playButtonClick(_:)), for: .touchUpInside)
        return view
    }()
    
    lazy var lastButton: UIButton = {
        let view = UIButton(type: .custom)
        view.isHidden = kaka_IsiPhone()
        view.imageView?.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(lastButtonClick(_:)), for: .touchUpInside)
        return view
    }()
    
    lazy var nextButton: UIButton = {
        let view = UIButton(type: .custom)
        view.imageView?.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(nextButtonClick(_:)), for: .touchUpInside)
        return view
    }()
    
    lazy var playlistButton: UIButton = {
        let view = UIButton(type: .custom)
        view.imageView?.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playlistButtonClick(_:)), for: .touchUpInside)
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let view = NVActivityIndicatorView(frame: CGRectMake(0, 0, 25.ckValue(), 25.ckValue()), type: .circleStrokeSpin, color: appMainColor)
        return view
    }()
    
}

/// 直线进度条
class LineProgressView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.lineHeight = self.bounds.height
        
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func appModeStyleChanged(_ noti: Notification) {
        guard let newColor = noti.object as? UIColor else { return }
        self.progressColor = newColor
    }
    
    var progress: TimeInterval = 0 {
        didSet {
            setNeedsDisplay() // 更新视图
        }
    }
    
    var progressColor: UIColor = appMainColor
    var lineHeight: CGFloat = 1
    
    override func draw(_ rect: CGRect) {
        // 绘制背景
        let backgroundPath = UIBezierPath(rect: CGRect(x: 0, y: (rect.height - lineHeight) / 2, width: rect.width, height: lineHeight))
        UIColor.clear.setFill()
        backgroundPath.fill()
        
        // 绘制进度
        let progressWidth = rect.width * progress
        let progressPath = UIBezierPath(rect: CGRect(x: 0, y: (rect.height - lineHeight) / 2, width: progressWidth, height: lineHeight))
        progressColor.setFill()
        progressPath.fill()
    }
}
