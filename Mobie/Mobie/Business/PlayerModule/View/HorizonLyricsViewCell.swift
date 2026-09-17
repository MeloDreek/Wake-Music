//
//  HorizonLyricsViewCell.swift
//  Mobie
//
//  Created by 张文 on 6/9/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import Combine
import MorphingLabel
import KakaTaglibKit


/// 横向大歌词
class HorizonLyricsViewCell: UICollectionViewCell {
    private var paletteRequest = UUID()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        
        contentView.addSubview(rippleView1)
        contentView.addSubview(rippleView2)
        
        contentView.addSubview(aniLyricLabel)
        contentView.addSubview(expiredLabel)
        
        contentView.addSubview(leftControl)
        contentView.addSubview(rightControl)
        
        contentView.addSubview(rotateButton)
        contentView.addSubview(lyricSetButton)
        
        contentView.addSubview(nameLabel)
    }
    
    private func setupAutoLayout() {
        
        let btnSize = 44.ckValue()
        let leftSpace = kaka_safeAreaInsets().left
        let rightSpace = kaka_safeAreaInsets().right
        let isPhoneLandscape = kaka_IsiPhone() && OrientationManager.shared.isLandscape
        
        rippleView1.snp.remakeConstraints { make in
            make.centerX.equalTo(self.snp.left)
            make.centerY.equalToSuperview()
            make.size.equalTo(rippleView1.size)
        }
        
        rippleView2.snp.remakeConstraints { make in
            make.centerX.equalTo(self.snp.right)
            make.centerY.equalToSuperview()
            make.size.equalTo(rippleView1.size)
        }
        
        leftControl.frame = CGRectMake(0, 0, contentView.width / 2, contentView.height)
        rightControl.frame = CGRectMake(CGRectGetMaxX(leftControl.frame), 0, contentView.width / 2, contentView.height)
        
        aniLyricLabel.frame = CGRectMake(leftSpace, kaka_safeAreaInsets().bottom, contentView.bounds.width - leftSpace - rightSpace, contentView.bounds.height - kaka_safeAreaInsets().bottom)

        let expireHeight = expiredLabel.font.lineHeight * 2
        expiredLabel.frame = CGRectMake(leftSpace, (contentView.bounds.height - expireHeight) / 2, contentView.bounds.width - leftSpace - rightSpace, expireHeight)
        
        lyricSetButton.frame = CGRectMake(contentView.bounds.width - btnSize - 20.ckValue(), isPhoneLandscape ? 26 : kStatusBarHeight + 10.ckValue(), btnSize, btnSize)
        rotateButton.frame = CGRectMake(20.ckValue(), lyricSetButton.top, btnSize, btnSize)
        
        nameLabel.frame = CGRectMake((contentView.width - nameLabel.size.width) / 2, kaka_IsiPhone() ? aniLyricLabel.top : self.bounds.height - nameLabel.height - kaka_safeAreaInsets().bottom - 5, nameLabel.size.width, nameLabel.height)
    }
    
    private func setupCusBuness() {
        contentView.backgroundColor = .clear
        rippleView1.startAnimation()
        rippleView2.startAnimation()
        
//        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(rotateButtonClick))
//        doubleTap.numberOfTapsRequired = 2
//        self.contentView.addGestureRecognizer(doubleTap)
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                guard let wSelf = self else { return }
                guard let model = model else { return }
                if wSelf.model != model {
                    let textFont = wSelf.calculateMaxFontSize(content: model.showTitleName(), maxWidth: wSelf.bounds.width - 10.ckValue(), maxFont: wSelf.maxFontSize)

                    self?.playingIndex = nil
                    self?.aniLyricLabel.font = textFont
                    self?.aniLyricLabel.text = model.showTitleName()
                }
                self?.model = model
            }.store(in: &cancellables)
        
        // 播放时间
        KakaMusicPlayer.shared.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentTime in
                guard let wSelf = self else { return }
                if !KakaMusicPlayer.shared.isPlaying { return }
                if !wSelf.rippleView1.isAnimating || !wSelf.rippleView2.isAnimating {
                    wSelf.rippleView1.startAnimation()
                    wSelf.rippleView2.startAnimation()
                }
                
                let timeOffset: Double = Double(KakaMusicPlayer.shared.playingMusic?.lyricModel?.offset ?? 0)
                self?.updatePlayTime(currentTime * 1000 + timeOffset)
            }.store(in: &cancellables)
        
        // 歌词字体设置
        MusicConfigManager.shared.$lyricConfig
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lyricConfig in
                self?.updateLyricConfig()
            }.store(in: &cancellables)
        
        self.updateLyricConfig()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        rippleView1.stopAnimation() // 在重用单元格时停止动画
        rippleView2.stopAnimation() // 在重用单元格时停止动画
    }
    
    // 无歌词、动画歌词、歌词体验过期
    func updateLyricConfig() {
        
        let lyricConfig = MusicConfigManager.shared.lyricConfig
        self.aniLyricLabel.textColor = UIColor.hexColor(lyricConfig.selFontColor)
        
        guard let lyrics = self.model?.lyricModel?.lyrics, lyrics.count > 0 else {
            self.aniLyricLabel.isHidden = true
            self.expiredLabel.text = KakaMusicPlayer.shared.playingMusic?.showTitleName()
            self.expiredLabel.isHidden = false
            return
        }
                
        if isShowLyric {
            self.aniLyricLabel.isHidden = false
            self.expiredLabel.isHidden = true
        }else{
            // 歌词体验已过期
            self.expiredLabel.text = KakaMusicPlayer.shared.playingMusic?.showTitleName()
            self.aniLyricLabel.isHidden = true
            self.expiredLabel.isHidden = false
        }
    }
    
    // MARK:  GET && SET
    var cancellables = Set<AnyCancellable>()
    
    weak var delegate: PlayerSubViewDelegate?
    
    /// 上一次的播放时间
    var lastTime: TimeInterval?
    
    /// 播放中的索引
    var playingIndex: Int?
    
    var maxFontSize: CGFloat {
        get {
            switch kaka_osType() {
            case .iOS: return 40
            case .iPadOS: return 60
            case .macOS: return 50
            }
        }
    }
    
    
    /// 音乐模型
    private(set) var model: MusicItemModel? {
        didSet {
            self.updateLyricConfig()
            self.playingMusicChanged()
        }
    }
    
    var isShowLyric: Bool {
        get {
            guard let model = KakaMusicPlayer.shared.playingMusic else { return false }
            
            if model.fileSourceType == .demoFile {
                return true
            }else{
                return model.isHaveLyric()
            }
        }
    }
    
    // MARK:  懒加载
    lazy var aniLyricLabel: LTMorphingLabel = {
        let view = LTMorphingLabel(frame: CGRectMake(5.ckValue(), 0, self.bounds.width - 10.ckValue(), self.bounds.height))
        view.bounds = self.bounds
        view.morphingEffect = .scale
        view.textAlignment = .center
        view.font = UIFontBold(maxFontSize)
        view.numberOfLines = 0
        view.textColor = UIColor.hexColor(MusicConfigManager.shared.lyricConfig.selFontColor)
        if let playingMusic = KakaMusicPlayer.shared.playingMusic {
            view.text = playingMusic.showTitleName()
        }
        return view
    }()
    
    lazy var expiredLabel: UILabel = {
        let textFont = UIFontBold(maxFontSize)
        
        let view = UILabel(frame: CGRectMake(0, 0, self.bounds.width * 0.9, textFont.lineHeight * 2))
        view.isHidden = true
        view.textAlignment = .center
        view.font = textFont
        view.numberOfLines = 0
        view.textColor = UIColor.hexColor(MusicConfigManager.shared.lyricConfig.selFontColor)
        if let playingMusic = KakaMusicPlayer.shared.playingMusic {
            view.text = playingMusic.showTitleName()
        }
        return view
    }()
    
    // 退出旋转
    lazy var rotateButton: UIButton = {
        let view = UIButton(type: .custom)
        let symbol: String
        if #available(iOS 17.0, *) {
            symbol = "rectangle.landscape.rotate"
        } else {
            symbol = "rotate.left"
        }
        view.setImage(Reasource.systemNamed(symbol, color: .white), for: .normal)
        view.addTarget(self, action: #selector(rotateButtonClick), for: .touchUpInside)
        return view
    }()
    
    lazy var lyricSetButton: UIButton = {
        let image: UIImage = Reasource.systemNamed("slider.vertical.3", color: .white)
        let view = UIButton(type: .custom)
        view.addTarget(self, action: #selector(lyricSetButtonClick(_:)), for: .touchUpInside)
        view.setImage(image, for: .normal)
        return view
    }()
    
    lazy var rippleView1: RippleAnimationView = {
        let width = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let view = RippleAnimationView(frame: CGRectMake(0, 0, width, width))
        return view
    }()
    
    lazy var rippleView2: RippleAnimationView = {
        let width = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let view = RippleAnimationView(frame: CGRectMake(0, 0, width, width))
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let text = "Wakemusic".localStr()
        let font = UIFontLight(14.ckValue())
        
        let view = UILabel(frame: CGRectMake(0, 0, text.width(font) + 5, 44.ckValue()))
        view.isHidden = kaka_IsMacOS() || UserInfoManager.shared.isVIP()
        view.text = text
        view.font = font
        view.textAlignment = .center
        view.textColor = .white
        return view
    }()
    
    lazy var leftControl: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        let tapClick = UITapGestureRecognizer(target: self, action: #selector(leftControlClick))
        tapClick.numberOfTapsRequired = 2
        view.addGestureRecognizer(tapClick)
        return view
    }()
    
    lazy var rightControl: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        let tapClick = UITapGestureRecognizer(target: self, action: #selector(rightControlClick))
        tapClick.numberOfTapsRequired = 2
        view.addGestureRecognizer(tapClick)
        return view
    }()
}

// MARK:  歌词
extension HorizonLyricsViewCell {
    
    @objc func leftControlClick() {
        KakaMusicPlayer.shared.playLastItem()
    }
    
    @objc func rightControlClick() {
        KakaMusicPlayer.shared.playNextItem()
    }
    
    func playingMusicChanged() {
        guard let model = KakaMusicPlayer.shared.playingMusic else { return }
        
        let playbackModel = MusicConfigManager.shared.playbackModel
        let backType = playbackModel.backgroundType
        
        switch backType {
        case .defaultType:
            let coverImage: UIImage = model.musicCoverImage() ?? model.placeImage()
            
            self.updateCoverGradientColor(coverImage)
            break
        case .systemType:
            let backImage = playbackModel.backgroundImage() ?? model.placeImage()
            
            let coverImage: UIImage = backImage
            self.updateCoverGradientColor(coverImage)
            break
        case .customType:
            let coverImage: UIImage = playbackModel.backgroundImage() ?? model.placeImage()
            
            self.updateCoverGradientColor(coverImage)
            break
        }
        
    }
    
    // 提取背景图的主色调
    func updateCoverGradientColor(_ backImage: UIImage) {
        let request = UUID()
        paletteRequest = request
        ArtworkPaletteProvider.shared.palette(for: backImage) { [weak self] palette in
            guard let self, self.paletteRequest == request else { return }
            self.rippleView1.rippleColor = palette.primary
            self.rippleView2.rippleColor = palette.secondary
        }
    }

    
    // 更新播放时间
    public func updatePlayTime(_ millisecond: TimeInterval) {
        
        guard let isNoneTime = self.model?.lyricModel?.isNoneTime, isNoneTime == false else {
            self.playingIndex = nil
            self.aniLyricLabel.text = KakaMusicPlayer.shared.playingMusic?.showTitleName()
            return
        }
                        
        if let lyrics = self.model?.lyricModel?.lyrics, lyrics.count > 0 {
            if let tempIndex = self.getCurrentLyricIndex(playbackTime: millisecond, lyrics: lyrics) {
                if tempIndex == self.playingIndex {
                    return
                }
                
                self.playingIndex = tempIndex
            }
        }
                        
        guard let playingIndex = self.playingIndex else { return }
        
        if let lyrics = self.model?.lyricModel?.lyrics, lyrics.count > 0 {
            
            let fullLyric = lyrics[playingIndex].fullLyric ?? ""
            let textFont = self.calculateMaxFontSize(content: fullLyric, maxWidth: self.expiredLabel.width, maxFont: maxFontSize)
            
            let animation = MusicConfigManager.shared.lyricConfig.miniLyricAnimation.animationType() ?? .anvil
            self.aniLyricLabel.morphingEffect = animation
            self.aniLyricLabel.font = textFont
            self.aniLyricLabel.text = fullLyric
        }
        
    }
    
    private func getCurrentLyricIndex(playbackTime: TimeInterval, lyrics: [LyricModel]) -> Int? {
        for (index, lyric) in lyrics.enumerated() {
            if let startTimestamp = lyric.startTimestamp, let endTimestamp = lyric.endTimestamp {
                if playbackTime >= startTimestamp && playbackTime < endTimestamp {
                    return index
                }
            }
        }
        
        return nil
    }
    
    func calculateMaxFontSize(content: String, maxWidth: CGFloat, maxFont: CGFloat) -> UIFont {
        var fontSize: CGFloat = maxFontSize
        
        while true {
            let estimatedWidth = content.width(UIFontBold(fontSize))
            
            if estimatedWidth <= maxWidth {
                break
            }
            
            fontSize -= 1
        }
        
        return UIFontBold(fontSize > maxFont ? maxFont : fontSize)
    }
    
    // 点击查看歌词设置
    @objc func lyricSetButtonClick(_ sender: UIButton) {
        self.delegate?.controlViewDidLyricSetBtn(controlView: self, lyricSetBtn: sender)
    }
    
    // 退出全屏
    @objc func rotateButtonClick() {
        self.delegate?.playerViewDidClickLyricBtn(playerView: self)
    }
}
