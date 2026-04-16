//
//  BasicPlayerCollectCell.swift
//  Mobie
//
//  Created by 张文 on 5/26/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import MarqueeLabel
import KakaTaglibKit
import Combine
import KSPlayer

/// 播放器-基础样式
class PlayerBasicCollectCell: UICollectionViewCell {
    
    
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
        contentView.addSubview(toptagView)
        
        contentView.addSubview(coverMiddleView)
        coverMiddleView.addSubview(coverImgView)
        
        contentView.addSubview(miniLyricView)
        
        contentView.addSubview(musicInfoView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let controlHeight = OrientationManager.shared.playerControlHeight
        let isPhoneLandscape = kaka_IsiPhone() && OrientationManager.shared.isLandscape
        
        toptagView.frame = CGRectMake(0, isPhoneLandscape ? 30 : topSpace, self.bounds.width, 33.ckValue())
        
        musicInfoView.frame = CGRectMake(0, self.bounds.height - controlHeight - musicInfoHeight, self.bounds.width, musicInfoHeight)
        
        coverMiddleView.frame = CGRectMake(0, CGRectGetMaxY(toptagView.frame), self.bounds.width, self.bounds.height - CGRectGetMaxY(toptagView.frame) - musicInfoHeight - controlHeight)
        
        coverImgView.frame = CGRect(
            x: (coverMiddleView.bounds.width - coverImgSize) / 2,
            y: (coverMiddleView.bounds.height - coverImgSize) / 2 - coverImgSize * 0.05,
            width: coverImgSize,
            height: coverImgSize
        )
        
        coverImgView.size = CGSize(width: coverImgSize, height: coverImgSize)
        coverImgView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-coverImgSize * 0.05)
            make.size.equalTo(coverImgSize)
        }
        
        miniLyricView.snp.remakeConstraints { make in
            make.top.equalTo(coverImgView.snp.bottom).offset(10.ckValue())
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.bottom.equalToSuperview().offset(-controlHeight)
        }
        
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.playingMusicChanged()
            }.store(in: &cancellables)
        
        // 播放器样式
        MusicConfigManager.shared.$playerStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                self?.playerUIStyleChanged()
            }.store(in: &cancellables)
        
        // 设备朝向变化了
        OrientationManager.shared.$isLandscape
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLandscape in
                self?.layoutSubviews()
                self?.playingMusicChanged()
                self?.updateLyricConfig()
                self?.perform(#selector(self?.playerUIStyleChanged), with: nil, afterDelay: 0.1)
            }.store(in: &cancellables)
        
        // 播放状态
        KakaMusicPlayer.shared.$playbackStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.playerStatusChanged(status)
            }.store(in: &cancellables)
        
        // 歌词字体设置
        MusicConfigManager.shared.$lyricConfig
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lyricConfig in
                self?.updateLyricConfig()
            }.store(in: &cancellables)
        
        // 显示音乐标签
        AppLocalManager.shared.$isShowAudioTag
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isShowAudioTag in
                let isPhoneLandscape = kaka_IsiPhone() && OrientationManager.shared.isLandscape
                self?.toptagView.isHidden = !isShowAudioTag || isPhoneLandscape
            }.store(in: &cancellables)
        
        self.playerUIStyleChanged()
    }
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()
    
    weak var delegate: PlayerSubViewDelegate?
    
    let topSpace = kStatusBarHeight + 15.ckValue() + 40.ckValue()
    
    let musicInfoHeight = 60.ckValue()
    
    
    var coverImgSize: CGFloat {
        get {
            switch kaka_osType() {
            case .macOS:
                return 360.ckValue()
            case .iPadOS:
                let isFullScreen = UIScreen.main.bounds.width > UIScreen.main.bounds.height
                return self.bounds.width * (isFullScreen ? 0.45 : 0.6)
            case .iOS:
                let isPhoneLandscape = kaka_IsiPhone() && OrientationManager.shared.isLandscape
                let screenWidth = self.bounds.width
                return isPhoneLandscape ? screenWidth * 0.4 : screenWidth - 50
            }
        }
    }
    
    var miniLyricHeight: CGFloat {
        get {
            switch kaka_osType() {
            case .macOS:
                return 150.ckValue()
            case .iPadOS:
                return 150.ckValue()
            case .iOS:
                return 150.ckValue()
            }
        }
    }
    
    // MARK:  懒加载
    // 顶部Tag
    lazy var toptagView: AudioTagListView = {
        let view = AudioTagListView(frame: CGRectMake(0, topSpace, self.bounds.width, 33.ckValue()))
        view.isHidden = !AppLocalManager.shared.isShowAudioTag
        view.onClickBlock = { [weak self] (tagStr) in
            self?.setupAudioChannel()
        }
        return view
    }()
    
    lazy var coverMiddleView: UIView = {
        let controlHeight = OrientationManager.shared.playerControlHeight

        let view = UIView(frame: CGRectMake(0, CGRectGetMaxY(toptagView.frame), self.bounds.width, self.bounds.height - CGRectGetMaxY(toptagView.frame) - musicInfoHeight - controlHeight))
        view.isUserInteractionEnabled = true
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var coverImgView: UIImageView = {
        let playingModel = KakaMusicPlayer.shared.playingMusic
        let isPlaying = KakaMusicPlayer.shared.isPlaying
        let targetTransform: CGAffineTransform = isPlaying ? .identity : CGAffineTransform(scaleX: 0.85, y: 0.85)
        
        let view = UIImageView(frame: CGRectMake((coverMiddleView.width - coverImgSize) / 2, (coverMiddleView.height - coverImgSize) / 2, coverImgSize, coverImgSize))
        view.image = playingModel?.musicCoverImage() ?? playingModel?.placeImage()
        view.isUserInteractionEnabled = true
        view.contentMode = .scaleAspectFill
        view.transform = targetTransform
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(playStyleViewClick))
        singleTap.numberOfTapsRequired = 1
        view.addGestureRecognizer(singleTap)
    
        return view
    }()
    
    lazy var miniLyricView: MiniPlayerLyricView = {
        let view = MiniPlayerLyricView(frame: CGRectMake(0, 0, self.bounds.width, miniLyricHeight))
        view.isHidden = !MusicConfigManager.shared.lyricConfig.isShowMiniLyric
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapClick))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapClick))
        singleTap.numberOfTapsRequired = 1
        view.addGestureRecognizer(singleTap)
        
        singleTap.require(toFail: doubleTap)
                
        return view
    }()
    
    lazy var musicInfoView: MusicDescInfoView = {
        let controlHeight = OrientationManager.shared.playerControlHeight

        let view = MusicDescInfoView(frame: CGRectMake(0, self.bounds.height - controlHeight - musicInfoHeight, self.bounds.width, musicInfoHeight))
        view.isHidden = MusicConfigManager.shared.lyricConfig.isShowMiniLyric
        return view
    }()
    
    @objc func singleTapClick() {
        self.delegate?.controlViewDidBottomControl(controlView: self)
    }
    
    @objc func doubleTapClick() {
        if !kaka_IsiPhone() {
            return
        }
        
        self.delegate?.playerViewDidClickLyricBtn(playerView: self)
    }
}


extension PlayerBasicCollectCell {
    
    // 迷你歌词动画变化
    func updateLyricConfig() {
#if targetEnvironment(macCatalyst)
        self.musicInfoView.isHidden = !OrientationManager.shared.isLandscape
        self.miniLyricView.isHidden = OrientationManager.shared.isLandscape
#else
        let isShowMiniLyric = MusicConfigManager.shared.lyricConfig.isShowMiniLyric
        
        self.musicInfoView.isHidden = isShowMiniLyric
        self.miniLyricView.isHidden = !isShowMiniLyric
#endif
    }
    
    // 当前音乐模型变化了
    @objc func playingMusicChanged() {
        guard let model = KakaMusicPlayer.shared.playingMusic else { return }
        
        self.toptagView.model = model

        let coverImage: UIImage? = (model.musicCoverImage() ?? TaglibMetadataParser.extractCoverArt(from: model.mediaPlayURL)) ?? model.placeImage()
        self.coverImgView.kf.setImage(with: model.coverThumbnailURL(), placeholder: coverImage)
    }
    
    // 播放器样式变化了
    @objc func playerUIStyleChanged() {
        
        let style = MusicConfigManager.shared.playerStyle
        
        switch style {
        case .default8Side:
            self.coverImgView.applyShape(.octagon)
            break
        case .defaultRect:
            self.coverImgView.applyShape(.rect(15.ckValue()))
            break
        case .defaultCircle:
            self.coverImgView.applyShape(.circle)
            break
        default: break
        }
    }
    
    func playerStatusChanged(_ status: KSPlayerState) {
        let isPlaying = KakaMusicPlayer.shared.isPlaying
        let targetTransform: CGAffineTransform = isPlaying ? .identity : CGAffineTransform(scaleX: 0.85, y: 0.85)
        
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.8, options: [.curveEaseInOut]) { [weak self] () in
            self?.coverImgView.transform = targetTransform
        }
    }
    
        
    // 声道支持页面
    @objc func setupAudioChannel() {
        self.delegate?.playerBasicCellDidChannel(backView: self)
    }
    
    // 切换播放器样式
    @objc func playStyleViewClick() {
        self.delegate?.playerBasicCellDidPlayerStyle(basicView: self)
    }
    
}
