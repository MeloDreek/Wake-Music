//
//  PlayControlDefaultView.swift
//  Mobie
//
//  Created by 张文 on 5/27/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import NVActivityIndicatorView
import AVKit
import Combine
import KSPlayer

/// 底部控制层
class PlayControlDefaultView: UIView, UIGestureRecognizerDelegate {
    
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
        
        self.addSubview(sliderView)
        self.addSubview(currentTimeLabel)
        self.addSubview(totalTimeLabel)
        self.addSubview(sleepTimerLabel)
        
        self.addSubview(playButton)
        self.addSubview(nextButton)
        self.addSubview(lastButton)
        self.addSubview(loadingView)
        
        self.addSubview(airplayButton)
        self.addSubview(moreButton)
        self.addSubview(playlistButton)
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let isPhoneLandscape = kaka_IsiPhone() && OrientationManager.shared.isLandscape
        
        let sliderLeading = kaka_IsMacOS() ? 30 : 10.ckValue()
        let timeLeading = kaka_IsMacOS() ? 36 : 15.ckValue()
        let btnSpace = (self.bounds.width - playSize * 3) / (isPhoneLandscape ? 4 : 6)
        
        let timeLabelWidth = self.bounds.width * 0.2
        
        sliderView.frame = CGRectMake(
            sliderLeading,
            10.ckValue(),
            self.bounds.width - sliderLeading * 2,
            20.ckValue())

        currentTimeLabel.frame = CGRect(
            x: timeLeading,
            y: sliderView.frame.maxY + 5.ckValue(),
            width: timeLabelWidth,
            height: currentTimeLabel.font.lineHeight * 1.2
        )

        totalTimeLabel.frame = CGRect(
            x: self.bounds.width - timeLabelWidth - timeLeading,
            y: sliderView.frame.maxY + 5.ckValue(),
            width: timeLabelWidth,
            height: currentTimeLabel.font.lineHeight * 1.2
        )
        
        sleepTimerLabel.frame = CGRectMake(
            (self.bounds.width - currentTimeLabel.width) / 2,
            currentTimeLabel.top,
            currentTimeLabel.width,
            currentTimeLabel.height)
        
        playButton.frame = CGRectMake(
            (self.bounds.width - playSize) / 2,
            isPhoneLandscape ? 5.ckValue() : sleepTimerLabel.frame.maxY + 8.ckValue(),
            playSize,
            playSize)
        
        let btnOffset = btnSpace * (isPhoneLandscape ? 1 : 2)
        let lastButtonX = playButton.left - btnOffset - playButton.width
        let nextButtonX = playButton.frame.maxX + btnOffset

        lastButton.frame = CGRect(
            x: lastButtonX,
            y: playButton.top,
            width: playButton.width,
            height: playButton.height
        )

        nextButton.frame = CGRect(
            x: nextButtonX,
            y: playButton.top,
            width: playButton.width,
            height: playButton.height
        )

        
        airplayButton.frame = CGRect(
            x: playButton.frame.midX - airplayButton.width / 2,
            y: playButton.frame.maxY + (kaka_IsMacOS() ? 0 : 10.ckValue()),
            width: airplayButton.width,
            height: airplayButton.height
        )
        
        playlistButton.frame = CGRectMake(
            lastButton.center.x - airplayButton.frame.width / 2,
            airplayButton.center.y - airplayButton.frame.height / 2,
            airplayButton.frame.width,
            airplayButton.frame.height
        )

        moreButton.frame = CGRectMake(
            nextButton.center.x - airplayButton.frame.width / 2,
            airplayButton.center.y - airplayButton.frame.height / 2,
            airplayButton.frame.width,
            airplayButton.frame.height
        )
        
        let loadingSize = playSize * 0.6
        loadingView.frame = CGRect(
            x: playButton.frame.midX - loadingSize / 2,
            y: playButton.frame.midY - loadingSize / 2,
            width: loadingSize,
            height: loadingSize
        )
        
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] () in
            let progress = KakaMusicPlayer.shared.playProgress
            self?.sliderView.value = progress
        }
        
        //  播放状态
        KakaMusicPlayer.shared.$playbackStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updatePlayStatus(status)
            }.store(in: &cancellables)
        
        // 当前时间
        KakaMusicPlayer.shared.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentTime in
                self?.updateDuration(curTime: currentTime)
            }.store(in: &cancellables)
        
        // 睡眠时间
        KakaMusicPlayer.shared.$sleepTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sleepTime in
                self?.updateSleepTime(sleepTime)
            }.store(in: &cancellables)
        
        // 设备朝向变化了
        OrientationManager.shared.$isLandscape
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLandscape in
                let isPhoneLandScape = isLandscape && kaka_IsiPhone()
                self?.airplayButton.isHidden = isPhoneLandScape
                self?.playlistButton.isHidden = isPhoneLandScape
                self?.moreButton.isHidden = isPhoneLandScape
                self?.sliderView.isHidden = isPhoneLandScape
                self?.currentTimeLabel.isHidden = isPhoneLandScape
                self?.totalTimeLabel.isHidden = isPhoneLandScape
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.layoutSubviews()
                }
            }.store(in: &cancellables)
        
        // 点击切换歌词
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(clickTapAction))
        clickTap.delegate = self
        self.addGestureRecognizer(clickTap)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var touchedView = touch.view
        while let view = touchedView, view !== self {
            if view is UIControl { return false }
            touchedView = view.superview
        }
        // 如果点击的目标 View 是 sliderView 或其子视图，拦截父视图的手势
        if let touchView = touch.view, touchView.isDescendant(of: sliderView) {
            return false
        }
        
        return true
    }
    
    @objc func clickTapAction() {
        self.delegate?.controlViewDidBottomControl(controlView: self)
    }
    
    // 播放状态
    func updatePlayStatus(_ playStatus: KSPlayerState) {
        
        if self.isHidden { return }
        
        guard let playingModel = KakaMusicPlayer.shared.playingMusic else { return }
        
        self.playButton.isSelected = KakaMusicPlayer.shared.isPlaying
        
        switch playStatus {
        case .initialized:
            self.currentTimeLabel.text = "00:00"
            self.totalTimeLabel.text = "00:00"
            self.sliderView.value = 0
            
            self.playButton.isHidden = true
            if !self.loadingView.isAnimating {
                self.loadingView.startAnimating()
            }
            
            break
        case .buffering, .preparing:
            if !playingModel.isLocalFile() {
                self.playButton.isHidden = true
                if !self.loadingView.isAnimating {
                    self.loadingView.startAnimating()
                }
            }
            break
        case .bufferFinished:
            self.playButton.isHidden = false
            self.loadingView.stopAnimating()
            break
        case .readyToPlay:
            break
        case .paused:
            self.playButton.isHidden = false
            self.loadingView.stopAnimating()
            break
        case .playedToTheEnd, .error:
            self.playButton.isHidden = false
            self.loadingView.stopAnimating()
            break
        }
    }
    
    // 睡眠计时器
    func updateSleepTime(_ sleepTime: TimeInterval) {
        
        if self.isHidden { return }
        
        let minutes = Int(sleepTime) / 60
        let seconds = Int(sleepTime) % 60
        
        let sleepStr = "💤" + String(format: "%02d:%02d", minutes, seconds)
        self.sleepTimerLabel.text = sleepStr
        self.sleepTimerLabel.isHidden = sleepTime <= 0
    }
    
    // MARK:  GET && SET
    
    var curTime: TimeInterval = 0
    
    weak var delegate: PlayerSubViewDelegate?
        
    var playSize: CGFloat {
        get {
            let isPhoneLandscape = kaka_IsiPhone() && OrientationManager.shared.isLandscape
            return isPhoneLandscape ? 45.ckValue() : 75.ckValue()
        }
    }
    
    var playBtnConfig: UIImage.SymbolConfiguration {
        get {
            let config = UIImage.SymbolConfiguration(pointSize: playSize * 0.55, weight: .bold)
            return config
        }
    }
    
    var nextBtnConfig: UIImage.SymbolConfiguration {
        get {
            let config = UIImage.SymbolConfiguration(pointSize: playSize * 0.35, weight: .medium)
            return config
        }
    }
    
    var otherBtnConfig: UIImage.SymbolConfiguration {
        get {
            let config = UIImage.SymbolConfiguration(pointSize: playSize * 0.3, weight: .light)
            return config
        }
    }
    
    var cancellables = Set<AnyCancellable>()
    
    // MARK:  懒加载
    
    lazy var airplayButton: AVRoutePickerView = {
        let view = AVRoutePickerView(frame: CGRect(x: 0, y: 0, width: 40.ckValue(), height: 40.ckValue()))
        view.activeTintColor = .white
        view.tintColor = .white
        return view
    }()
    
    lazy var playlistButton: UIButton = {
        let view = UIButton(type: .custom)
        view.frame.size = airplayButton.frame.size
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playlistButtonClick(_:)), for: .touchUpInside)
        view.tintColor = .white
        view.setImage(Reasource.systemNamed("list.triangle", color: .white, config: otherBtnConfig), for: .normal)
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let view = NVActivityIndicatorView(frame: CGRectMake(0, 0, playSize * 0.6, playSize * 0.6), type: .circleStrokeSpin, color: .white)
        return view
    }()
    
    lazy var playButton: UIButton = {
        let view = UIButton(type: .custom)
        view.backgroundColor = .clear
        view.isSelected = KakaMusicPlayer.shared.isPlaying
        view.frame.size = CGSizeMake(playSize, playSize)
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playButtonClick(_:)), for: .touchUpInside)
        view.setImage(Reasource.systemNamed("play.fill", color: .white, config: playBtnConfig), for: .normal)
        view.setImage(Reasource.systemNamed("pause.fill", color: .white, config: playBtnConfig), for: .selected)
        return view
    }()
    
    lazy var lastButton: UIButton = {
        let view = UIButton(type: .custom)
        view.backgroundColor = .clear
        view.frame.size = playButton.frame.size
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playLastButtonClick(_:)), for: .touchUpInside)
        view.setImage(Reasource.systemNamed("backward.fill", color: .white, config: nextBtnConfig), for: .normal)
        return view
    }()
    
    lazy var nextButton: UIButton = {
        let view = UIButton(type: .custom)
        view.backgroundColor = .clear
        view.frame.size = playButton.frame.size
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playNextButtonClick(_:)), for: .touchUpInside)
        view.setImage(Reasource.systemNamed("forward.fill", color: .white, config: nextBtnConfig), for: .normal)
        return view
    }()
    
    lazy var sliderView: KakSliderControl = {
        let view = KakSliderControl()
        view.semanticContentAttribute = .forceLeftToRight
        view.overrideUserInterfaceStyle = .dark
        view.valueRange = 0...1
        view.value = 0
        view.defaultTrackColor = .secondarySystemFill
        view.enlargedTrackColor = .systemFill
        view.defaultProgressColor = .label
        view.enlargedProgressColor = .label
        
        // 拖动/点击状态监听（仅用于日志或UI辅助状态）
        view.onEditingChanged = { isEditing in
            if isEditing {
                debugPrint("用户按住进度条（点击或拖拽中）")
            } else {
                debugPrint("用户松开手指")
            }
        }
        
        // 点击松手 & 拖动松拽 都会统一且仅在松手时触发一次回调
        view.valuePublisher
            .sink { [weak self] progress in
                guard let self = self else { return }
                let progressRatio = TimeInterval(progress)
                let totalTime = KakaMusicPlayer.shared.totalTime
                let seekTime = totalTime * progressRatio
                
                debugPrint("松手 Seek 目标时间 = \(seekTime)")
                
                if KakaMusicPlayer.shared.isPlaying {
                    KakaMusicPlayer.shared.seek(time: seekTime)
                } else {
                    KakaMusicPlayer.shared.seek(time: seekTime)
                    KakaMusicPlayer.shared.play()
                }
            }
            .store(in: &cancellables)
            
        return view
    }()
    
    // 更新播放时间
    func updateDuration(curTime: TimeInterval) {
        let endTime = KakaMusicPlayer.shared.totalTime

        self.currentTimeLabel.text = curTime.stringValue
        self.totalTimeLabel.text = endTime.stringValue

        self.sliderView.value = Float(curTime / endTime)
    }

    lazy var currentTimeLabel: UILabel = {
        let view = UILabel()
        view.font = UIFontLight(11.ckValue())
        view.textColor = UIColor.white.withAlphaComponent(0.5)
        view.text = "00:00"
        view.textAlignment = .left
        return view
    }()
    
    lazy var sleepTimerLabel: UILabel = {
        let view = UILabel()
        view.font = UIFontLight(11.ckValue())
        view.textColor = currentTimeLabel.textColor
        view.text = nil
        view.textAlignment = .center
        view.isUserInteractionEnabled = true
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(setupSleepTimer))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    lazy var totalTimeLabel: UILabel = {
        let view = UILabel()
        view.font = currentTimeLabel.font
        view.textColor = currentTimeLabel.textColor
        view.text = "00:00"
        view.textAlignment = .right
        return view
    }()
    
    lazy var moreButton: UIButton = {
        let view = UIButton(type: .custom)
        view.size = playlistButton.size
        view.addTarget(self, action: #selector(moreButtonClick(_:)), for: .touchUpInside)
        view.accessibilityLabel = "More".localStr()
        view.tintColor = .white
        view.setImage(Reasource.systemNamed("ellipsis.circle", color: .white, config: otherBtnConfig), for: .normal)
        return view
    }()
    
    func moreMenu() -> UIMenu {
        
        // 1️⃣ 音频指纹识别、音乐标签编辑器、喜欢、添加到歌单
        let audioFingerAction = UIAction(title: MusicActionType.audioFinger.titleStr(), image: UIImage(systemName: "touchid")) { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerBasicCellDidAudioFinger(basicView: wSelf)
        }
        
        let musictagAction = UIAction(title: "Music Tag Editor".localStr(), image: UIImage(systemName: "tag")) { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerBasicCellDidMusicEditor(basicView: wSelf)
        }
//        let playlistAction = UIAction(title: MusicActionType.addPlaylist.titleStr(), image: MusicActionType.addPlaylist.iconImage()) { [weak self] _ in
//            guard let wSelf = self else { return }
//            wSelf.delegate?.playerSubViewDidClickAddPlaylisy(baseView: wSelf)
//        }
        let isLike = KakaMusicPlayer.shared.playingMusic?.isFlagFavorite() ?? false
        let isLocal = KakaMusicPlayer.shared.playingMusic?.isLocalFile() ?? false
        
        let likeType = isLike ? MusicActionType.removeFavirote : MusicActionType.addFavirote
        let likeImage = UIImage(systemName: isLike ? "heart.fill" : "heart")
        
        let likeAction = UIAction(title: likeType.titleStr(), image: likeImage, attributes: isLocal ? [] : [.disabled], state: .off,) { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerSubViewDidClickFavorite(baseView: wSelf)
        }
        
        let musictagMenu = UIMenu(title: "", options: .displayInline, children: [audioFingerAction, musictagAction, likeAction])
        
        // 2️⃣ 播放器内核、播放器样式、播放器背景
        let engineAction = UIAction(title: "Playback Engine".localStr(), image: UIImage(systemName: "play.rectangle"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerBasicCellDidPlayerEngine(basicView: wSelf)
        })
        
        let playerAction = UIAction(title: "Player Style".localStr(), image: UIImage(systemName: "camera.filters"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerBasicCellDidPlayerStyle(basicView: wSelf)
        })
        
        let playbackAction = UIAction(title: "Player Background".localStr(), image: UIImage(systemName: "wand.and.rays"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerBasicCellDidPlayerBackground(basicView: wSelf)
        })
        
//        let lyricsetAction = UIAction(title: "Lyrics Settings".localStr(), image: UIImage(systemName: "slider.vertical.3"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
//            guard let wSelf = self else { return }
//            wSelf.delegate?.playerBasicCellDidLyricSettings(basicView: wSelf)
//        })
        
        let isShowAudioTag = AppLocalManager.shared.isShowAudioTag
        let showTagAction = UIAction(title: "Show Audio Information".localStr(), image: isShowAudioTag ? nil : UIImage(systemName: "tag.slash"), identifier: PlayerMoreActionID.showAudioInformation, discoverabilityTitle: nil, attributes: [], state: isShowAudioTag ? .on : .off, handler: { [weak self] _ in
            AppLocalManager.shared.isShowAudioTag = !AppLocalManager.shared.isShowAudioTag
        })

        let isShowMiniLyric = MusicConfigManager.shared.lyricConfig.isShowMiniLyric
        let showMiniLyric = UIAction(title: "Mini Lyrics".localStr(), image: isShowMiniLyric ? nil : UIImage(systemName: "text.badge.checkmark"), identifier: PlayerMoreActionID.showMiniLyrics, discoverabilityTitle: nil, attributes: [], state: isShowMiniLyric ? .on : .off, handler: { [weak self] _ in
            var lyricConfig = MusicConfigManager.shared.lyricConfig
            lyricConfig.isShowMiniLyric = !lyricConfig.isShowMiniLyric
            
            MusicConfigManager.shared.lyricConfig = lyricConfig
        })
        
        let playStylegMenu = UIMenu(title: "", options: .displayInline, children: [engineAction, playerAction, playbackAction, showTagAction, showMiniLyric])
        
        // 3️⃣ 睡眠计时器，下载，倍数
        let sleepAction = UIAction(title: "Sleep Timer".localStr(), image: UIImage(systemName: "clock.arrow.circlepath"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            self?.setupSleepTimer()
        })
        
        let downloadAction = UIAction(title: "Download".localStr(), image: UIImage(systemName: "square.and.arrow.down"), attributes: isLocal ? [.disabled] : [], state: .off, handler: { [weak self] _ in
            self?.addDownloadQueue()
        })
        
        let otherMenu = UIMenu(title: "", options: .displayInline, children: [sleepAction, downloadAction, self.rateTypeMenu()])
        
        let mainMenu = UIMenu(title: "", children: [musictagMenu, playStylegMenu, otherMenu])
        
        return mainMenu
    }
    
    // 播放倍速
    func rateTypeMenu() -> UIMenu {
        let storageArray: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 4.0, 8.0]
        var actionArray: [UIAction] = [UIAction]()
        
        for subItem in storageArray {
            let subMenu = UIAction(title: "\(subItem)", image: nil, identifier: nil, discoverabilityTitle: nil, attributes: [], state: MusicConfigManager.shared.playRate == subItem ? .on : .off, handler: { [weak self] _ in
                
                if let baiduFile = KakaMusicPlayer.shared.playingMusic?.baiduFileModel, FileManager.default.fileExists(atPath: baiduFile.m3uCacheURL().path) {
                    appKeyWindow?.makeToast("This feature is unavailable due to partner restrictions.".localStr())
                    return
                }
                
                KakaMusicPlayer.shared.pause()
                
                MusicConfigManager.shared.playRate = subItem
                KakaMusicPlayer.shared.playbackRate = subItem
                
                KakaMusicPlayer.shared.play()
                
            })
            
            actionArray.append(subMenu)
        }
                
        var editImage = UIImage(systemName: "goforward.45")
        if #available(iOS 17.0, *) {
            editImage = UIImage(systemName: "gauge.with.dots.needle.67percent")
        }
        
        let sortMenu = UIMenu(title: "Rate".localStr(), image: editImage, options: .singleSelection, children: actionArray)
        return sortMenu
        
    }
    
}

extension PlayControlDefaultView {
    
    // 播放暂停
    @objc func playButtonClick(_ sender: UIButton) {
        
        var isLocal = false
        if let model = KakaMusicPlayer.shared.playingMusic {
            isLocal = model.isLocalFile()
        }
        
        if isLocal {
            sender.isSelected = !sender.isSelected
        }
        
        if KakaMusicPlayer.shared.isPlaying {
            KakaMusicPlayer.shared.pause()
        }else{
            KakaMusicPlayer.shared.play()
        }
    }
    
    // 上一首
    @objc func playLastButtonClick(_ sender: UIButton) {
        KakaMusicPlayer.shared.playLastItem()
    }
    
    // 下一首
    @objc func playNextButtonClick(_ sender: UIButton) {
        KakaMusicPlayer.shared.playNextItem()
    }
    
    // 睡眠计时器
    @objc func setupSleepTimer() {
        self.delegate?.playerBasicCellDidSleepTimer(basicView: self, sleepView: self.sleepTimerLabel)
    }
    
//    // 拖动进度条
//    @objc func sliderViewVauleChanged(_ sender: UISlider) {
//        let progress = sender.value
//        sender.value = progress
//                
//        // 将毫秒转换为秒
//        let totalSeconds = KakaMusicPlayer.shared.playerView.totalTime * Double(progress)
//        
//        // 计算分钟和秒
//        let minutes = Int(totalSeconds) / 60
//        let seconds = Int(totalSeconds) % 60
//        
//        self.currentTimeLabel.text = String(format: "%02d:%02d", minutes, seconds)
//    }
    
//    // 点击进度条
//    @objc func sliderTapped(_ gesture: UITapGestureRecognizer) {
//        
//        if let slider = gesture.view as? UISlider {
//            let point = gesture.location(in: slider)
//
//            // 计算点击的横向位置占 UISlider 宽度的比例
//            let percentage = point.x / slider.bounds.width
//
//            // 计算新的值
//            let newValue = Float(percentage) * (slider.maximumValue - slider.minimumValue) + slider.minimumValue
//
//            // 设置 UISlider 的值
//            slider.setValue(newValue, animated: true)
//
//            // 如果 UISlider 控制播放进度，则在此处更新播放进度
//            self.sliderViewEndTouchup(slider)
//        }
//
//        if let slider = gesture.view as? KakSliderControl {
//            let point = gesture.location(in: slider)
//
//            // 计算点击的横向位置占 UISlider 宽度的比例
//            let percentage = point.x / slider.bounds.width
//
//            // 计算新的值
//            let newValue = Float(percentage) * (slider.maximumValue - slider.minimumValue) + slider.minimumValue
//
//            // 设置 UISlider 的值
//            slider.value = newValue
//
//            // 如果 UISlider 控制播放进度，则在此处更新播放进度
//            self.kaka_sliderViewEndTouchup(slider)
//        }
//    }
    
//    /// UISlider：手指松开
//    @objc func sliderViewEndTouchup(_ sender: UISlider) {
//        let progress = TimeInterval(sender.value)
//        
//        let playTime = KakaMusicPlayer.shared.playerView.totalTime * progress
//
//        debugPrint("进度 = \(progress), 时间 = \(playTime)")
//        
//        if KakaMusicPlayer.shared.isPlaying {
//            KakaMusicPlayer.shared.seek(time: playTime)
//        }else{
//            KakaMusicPlayer.shared.play()
//        }
//    }
    
    

    // 播放列表
    @objc func playlistButtonClick(_ sender: UIButton) {
        self.delegate?.controlViewDidPlaylistBtn(controlView: self, playlistBtn: sender)
    }

    @objc func moreButtonClick(_ sender: UIButton) {
        delegate?.controlViewDidMoreBtn(controlView: self)
    }
    
    // 下载
    func addDownloadQueue() {
        guard let musicModel = KakaMusicPlayer.shared.playingMusic, SandboxFileManager.shared.getDownloadPlayURL(musicModel) == nil else { return }
        
        DownloadManager.shared.addMusicModel([musicModel])
        self.makeToast("Added to Downloads".localStr())
    }
    
    
}
