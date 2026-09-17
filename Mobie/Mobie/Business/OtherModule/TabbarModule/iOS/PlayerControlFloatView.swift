//
//  PlayerControlFloatView.swift
//  Mobie
//
//  Created by 张文 on 10/27/24.
//

import KakaFoundation
import AppGroupKit
import KSPlayer
import NVActivityIndicatorView
import Combine
import KakaTaglibKit

class PlayerControlFloatView: UIView {
    /// 屏幕宽度
    private var screenW: CGFloat {
        get {
            return UIScreen.main.bounds.size.width
        }
    }
    /// 屏幕高度
    private var screenH: CGFloat {
        get {
            return UIScreen.main.bounds.size.height
        }
    }
    
    /// 拖动开始时 位置
    private var beginPoint: CGPoint = CGPoint.zero
    
    /// 悬浮view 大小
    private(set) var fullSize = CGSize(width: 120.ckValue(), height: 120.ckValue())
    
    /// 顶部最小 margin
    private var topMinMargin: CGFloat {
        get {
            return kStatusBarHeight
        }
    }
    
    /// 底部最小 margin
    private var bottomMinMargin: CGFloat {
        get {
            return app_tabbarHeight
        }
    }
    
    /// 左边最小 margin
    private let leftMinMargin: CGFloat = 5.ckValue()
    
    /// 右边最小 magin
    private let rightMinMargin: CGFloat = 5.ckValue()
    
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: fullSize.width, height: fullSize.height))
        self.beginPoint = CGPointMake((screenW / fullSize.width) / 2, (screenH / fullSize.height) / 2)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        self.backgroundColor = .clear
        self.addSubview(shadowView)
        shadowView.addSubview(contentView)
        
        contentView.addSubview(coverImgView)
        contentView.addSubview(menuButton)
        contentView.addSubview(lastButton)
        contentView.addSubview(nextButton)
        contentView.addSubview(playButton)
        contentView.addSubview(progressView)
        
        contentView.addSubview(loadingView)
    }
    
    private func preSetupContains() {
        coverImgView.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.size.equalTo(coverImgView.layer.cornerRadius * 2)
        }
        
        progressView.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.size.equalTo(progressView.size)
        }
        
        menuButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.bottom.equalTo(coverImgView.snp.top)
            make.width.equalTo(coverImgView)
        }
        
        playButton.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
            make.top.equalTo(coverImgView.snp.bottom)
            make.width.equalTo(coverImgView)
        }
        
        loadingView.snp.makeConstraints { make in
            make.center.equalTo(playButton)
            make.size.equalTo(loadingView.size)
        }
        
        lastButton.snp.makeConstraints { make in
            make.trailing.equalTo(coverImgView.snp.leading)
            make.centerY.equalToSuperview()
            make.leading.equalTo(contentView)
            make.top.equalToSuperview()
        }
        
        nextButton.snp.makeConstraints { make in
            make.trailing.equalTo(contentView.snp.trailing)
            make.centerY.equalToSuperview()
            make.leading.equalTo(coverImgView.snp.trailing)
            make.top.equalToSuperview()
        }
    }
    
    
    private func preSetupHandleBuness() {
        
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
                self?.updateDuration(curTime: currentTime, endTime: KakaMusicPlayer.shared.totalTime)
            }.store(in: &cancellables)
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.playingMusicChanged()
            }.store(in: &cancellables)
        
        // 主题色变化了
        NotificationCenter.default.addObserver(self, selector: #selector(appModeSwitchChanged), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        
        // 外观模式已变更
        NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: Notification.Name(kAppearanceChangedKey), object: nil)

        let doubleClick = UITapGestureRecognizer(target: self, action: #selector(longDoubleClick))
        doubleClick.numberOfTapsRequired = 2
        doubleClick.numberOfTouchesRequired = 1
        self.addGestureRecognizer(doubleClick)
        
        let longClick = UILongPressGestureRecognizer(target: self, action: #selector(longDoubleClick))
        self.addGestureRecognizer(longClick)
    }
    
    @objc func longDoubleClick() {
        self.toolDelegate?.musicControlViewDidLongDoubleClick(view: self)
    }
        
    @objc func appModeSwitchChanged() {
        if self.isHidden { return }
        self.contentView.backgroundColor = appMainColor
    }
    
    @objc func appearanceChanged() {
        if self.isHidden { return }
        self.shadowView.layer.shadowColor = UIColor.label.cgColor
    }
    
    // 当前播放的音乐变化了，立马刷新页面
    @objc func playingMusicChanged() {
        
        if self.isHidden { return }
        
        if self.musicModel != KakaMusicPlayer.shared.playingMusic {
            self.updateDuration(curTime: 0, endTime: 0)
        }
        
        self.musicModel = KakaMusicPlayer.shared.playingMusic
    }
    
    // MARK:  懒加载
    
    private var cancellables = Set<AnyCancellable>()

    private let playSize = 25.ckValue()
    
    private var playBtnConfig: UIImage.SymbolConfiguration {
        get {
            let config = UIImage.SymbolConfiguration(pointSize: playSize * 0.58, weight: .bold)
            return config
        }
    }
    
    private var btnColor: UIColor {
        get {
            if ColorFontManager.shared.accentTyle == .color0 {
                return UIColor.deAccent
            }else{
                return appMainColor
            }
        }
    }
    
    weak var toolDelegate: PlayingControlViewDelegate?
    
    var playStatus = KSPlayerState.preparing {
        didSet {
                                                
//            debugPrint("播放状态 = \(playStatus)")
            self.playButton.isSelected = playStatus.isPlaying
            
            switch playStatus {
            case .initialized, .buffering, .preparing:
                
                self.playButton.isHidden = true
                if !self.loadingView.isAnimating {
                    self.loadingView.startAnimating()
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
    }
    
    // 更新播放时间
    func updateDuration(curTime: TimeInterval, endTime: TimeInterval) {
        
        if self.isHidden { return }
        
        var progress: CGFloat = curTime / endTime

        progress = min(progress, 1)
        
        self.progressView.progress = progress
    }
    
    var musicModel: MusicItemModel? {
        didSet {
            guard let musicModel = self.musicModel else {
                self.playButton.isSelected = false
                return
            }
                                    
            if !self.playButton.isSelected {
                let lastPlayTime = MusicConfigManager.shared.lastPlayTime
                let lastTotalTime = MusicConfigManager.shared.lastTotalTime
                if lastPlayTime > 0 && lastTotalTime > 0 && MusicConfigManager.shared.isLastCache {
                    self.progressView.progress = lastPlayTime / lastPlayTime
                    self.updateDuration(curTime: lastPlayTime, endTime: lastTotalTime)
                    
                }else{
                    self.progressView.progress = 0
                    self.updateDuration(curTime: 0, endTime: TimeInterval(musicModel.durationSeconds))
                }
            }
            
            let coverImage: UIImage? = (musicModel.musicCoverImage() ?? TaglibMetadataParser.extractCoverArt(from: musicModel.mediaPlayURL)) ?? musicModel.placeImage()
            coverImgView.kf.setImage(with: musicModel.coverThumbnailURL(), placeholder: coverImage)
        }
    }
    
    var curTime: TimeInterval = 0
    
    lazy var shadowView: UIView = {
        let view = UIView(frame: self.bounds)
        view.backgroundColor = .clear // 保持背景透明
        view.layer.shadowColor = UIColor.label.cgColor // 阴影颜色
        view.layer.shadowOpacity = 0.5 // 阴影透明度
        view.layer.shadowOffset = CGSize.zero // 阴影偏移
        view.layer.shadowRadius = 10.ckValue()
        return view
    }()
    
    lazy var contentView: UIView = {
        let view = UIView(frame: self.bounds)
        view.isUserInteractionEnabled = true
        view.backgroundColor = appMainColor
        view.layer.cornerRadius = self.fullSize.width / 2
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var coverImgView: UIImageView = {
        let view = UIImageView(image: MusicGenreType.pop.iconImage())
        view.isUserInteractionEnabled = true
        view.contentMode = .scaleAspectFill
        view.layer.masksToBounds = true
        view.layer.cornerRadius = fullSize.width * 0.45 / 2
        return view
    }()
    
    lazy var progressView: KakaCircleView = {
        let size = coverImgView.layer.cornerRadius * 2 + 2.ckValue()
        let view = KakaCircleView(frame: CGRect(origin: .zero, size: CGSizeMake(size, size)))
        view.isUserInteractionEnabled = true
        view.backgroundColor = .clear
        
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(clickCoverImg))
        view.addGestureRecognizer(clickTap)
        
        return view
    }()
    
    private lazy var playButton: UIButton = {
        let view = UIButton(type: .custom)
        view.isSelected = KakaMusicPlayer.shared.isPlaying
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playButtonClick(_:)), for: .touchUpInside)
        view.setImage(Reasource.systemNamed("play.fill", color: btnColor, config: playBtnConfig), for: .normal)
        view.setImage(Reasource.systemNamed("pause.fill", color: btnColor, config: playBtnConfig), for: .selected)
        view.setImage(view.image(for: .selected), for: [.selected, .highlighted])
        return view
    }()
    
    lazy var lastButton: UIButton = {
        let view = UIButton(type: .custom)
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playLastButtonClick(_:)), for: .touchUpInside)
        view.setImage(Reasource.systemNamed("backward.end", color: btnColor, config: playBtnConfig).flippedImage(), for: .normal)
        view.setImage(Reasource.systemNamed("backward.end.fill", color: btnColor, config: playBtnConfig).flippedImage(), for: .highlighted)
        return view
    }()
    
    lazy var nextButton: UIButton = {
        let view = UIButton(type: .custom)
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playNextButtonClick(_:)), for: .touchUpInside)
        view.setImage(Reasource.systemNamed("forward.end", color: btnColor, config: playBtnConfig).flippedImage(), for: .normal)
        view.setImage(Reasource.systemNamed("forward.end.fill", color: btnColor, config: playBtnConfig).flippedImage(), for: .highlighted)
        return view
    }()
    
    lazy var menuButton: UIButton = {
        let view = UIButton(type: .custom)
        view.accessibilityLabel = "Playlist".localStr()
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(menuButtonClick(_:)), for: .touchUpInside)
        view.setImage(Reasource.systemNamed("list.triangle", color: btnColor, config: playBtnConfig), for: .normal)
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let view = NVActivityIndicatorView(frame: CGRectMake(0, 0, 15.ckValue(), 15.ckValue()), type: .circleStrokeSpin, color: btnColor)
        return view
    }()
    
    @objc func playButtonClick(_ sender: UIButton) {
        
        if KakaMusicPlayer.shared.playingMusic == nil {
            self.toolDelegate?.musicControlViewDidFirstPlay(view: self, model: self.musicModel)
            return
        }
        
        KakaMusicPlayer.shared.togglePlayback()
    }
    
    @objc func playLastButtonClick(_ sender: UIButton) {
        KakaMusicPlayer.shared.playLastItem()
        
        self.musicModel = KakaMusicPlayer.shared.playingMusic
    }
    
    @objc func playNextButtonClick(_ sender: UIButton) {
                
        KakaMusicPlayer.shared.playNextItem()
        
        self.musicModel = KakaMusicPlayer.shared.playingMusic
    }
    
    @objc func menuButtonClick(_ sender: UIButton) {
        self.toolDelegate?.musicControlViewDidPlaylistButton(view: self, playlistButton: sender)
    }
    
    @objc func clickCoverImg() {
        self.toolDelegate?.musicControlViewDidClick(view: self)
    }
    
}

extension PlayerControlFloatView {
    /// 点击开始
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else {return}
        
        let curPoint = touch.location(in: self)
        let prePoint = touch.previousLocation(in: self)
        
        let offsetX = curPoint.x - prePoint.x
        let offsetY = curPoint.y - prePoint.y
        
        let centerX = offsetX + self.center.x
        let centerY = offsetY + self.center.y
        /// 记录开始位置
        beginPoint = CGPoint(x: centerX, y: centerY)
        
    }
    /// 拖动
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else {return}
        
        let curPoint = touch.location(in: self)
        let prePoint = touch.previousLocation(in: self)
        
        let offsetX = curPoint.x - prePoint.x
        let offsetY = curPoint.y - prePoint.y
        
        let centerX = offsetX + self.center.x
        let centerY = offsetY + self.center.y
        /// 拖动
        self.center = CGPoint(x: centerX, y: centerY)
    
    }
    /// 点击结束
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first else {return}
        let curPoint = touch.location(in: self)
        let prePoint = touch.previousLocation(in: self)
        
        let offsetX = curPoint.x - prePoint.x
        let offsetY = curPoint.y - prePoint.y
        
        let centerX = offsetX + self.center.x
        let centerY = offsetY + self.center.y
        
        let endPoint = CGPoint(x: centerX, y: centerY)
        /// 区分点击和拖动
        if endPoint == beginPoint { /// 点击
            // TODO: 处理点击事件
        } else { /// 拖动
            correctLocation()
        }
    }
    /// 修正位置
    func correctLocation() {
    
        if MusicConfigManager.shared.isFloatSide {
            // 1️⃣ 动画吸附在屏幕两侧
            var endCenter = center
            endCenter.x = center.x > screenW * 0.5 ? screenW-(rightMinMargin + fullSize.width * 0.5) : (leftMinMargin + fullSize.width * 0.5)
        
            if center.y < (topMinMargin + fullSize.height * 0.5) {
                endCenter.y = (topMinMargin + fullSize.height * 0.5)
            } else if center.y > screenH - (bottomMinMargin + fullSize.height * 0.5) {
                endCenter.y = screenH - (bottomMinMargin + fullSize.height * 0.5)
            }
            
            UIView.animate(withDuration: 0.25) { [weak self] () in
                self?.center = endCenter
            }
        }else{
            // 2️⃣ 纠正极端值
            var endCenter = center
            let point = self.frame.origin
            
            if point.x < leftMinMargin {
                endCenter.x = leftMinMargin + fullSize.width / 2
            }
            
            if point.x + fullSize.width > screenW {
                endCenter.x = screenW - fullSize.width / 2 - rightMinMargin
            }
            
            if point.y < topMinMargin {
                endCenter.y = topMinMargin + fullSize.height / 2
            }
            
            if point.y + fullSize.height > screenH - bottomMinMargin {
                endCenter.y = screenH - fullSize.width / 2 - bottomMinMargin
            }
            
            UIView.animate(withDuration: 0.25) { [weak self] () in
                self?.center = endCenter
            }
        }
        
    }
}


class KakaCircleView: UIView {

    var progressBackgroundColor: UIColor = .clear
    var progressColor: UIColor {
        if ColorFontManager.shared.accentTyle == .color0 {
            return UIColor.deAccent
        }else{
            return UIColor.white
        }
    }
    var progressWidth: CGFloat = 2.ckValue()
    
    var progress: CGFloat = 0 {
        didSet {
            self.setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let _ = UIGraphicsGetCurrentContext() else { return }
        
        // 背景圆弧
        let radius = (min(rect.width, rect.height) - progressWidth) * 0.5
        let center = CGPoint(x: rect.width * 0.5, y: rect.height * 0.5)
        
        let backgroundPath = UIBezierPath()
        backgroundPath.lineWidth = progressWidth
        backgroundPath.lineCapStyle = .round
        backgroundPath.lineJoinStyle = .round
        progressBackgroundColor.set()
        backgroundPath.addArc(withCenter: center, radius: radius, startAngle: .pi * 1.5, endAngle: .pi * 1.5 + .pi * 2, clockwise: true)
        backgroundPath.stroke()
        
        // 进度圆弧
        let progressPath = UIBezierPath()
        progressPath.lineWidth = progressWidth
        progressPath.lineCapStyle = .round
        progressPath.lineJoinStyle = .round
        progressColor.set()
        progressPath.addArc(withCenter: center, radius: radius, startAngle: .pi * 1.5, endAngle: .pi * 1.5 + .pi * 2 * progress, clockwise: true)
        progressPath.stroke()
    }
    
}
