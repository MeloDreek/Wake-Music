//
//  PlayerVinylCollectCell.swift
//  Mobie
//
//  Created by 张文 on 5/26/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import MarqueeLabel
import Combine
import KSPlayer
import KakaTaglibKit
import MorphingLabel

/// 播放器-黑胶样式
class PlayerVinylCollectCell: UICollectionViewCell {
    
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
        contentView.addSubview(vinylImgView)
        vinylImgView.addSubview(coverImgView)
        
//        contentView.addSubview(needleImgView)
        contentView.addSubview(miniLyricView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let controlHeight = OrientationManager.shared.playerControlHeight
        let isPhoneLandscape = kaka_IsiPhone() && OrientationManager.shared.isLandscape
        
        toptagView.frame = CGRectMake(0, topSpace, self.bounds.width, 33.ckValue())

        vinylImgView.layer.cornerRadius = vinylBackSize / 2
        vinylImgView.frame = CGRectMake((self.bounds.size.width - vinylBackSize) / 2, isPhoneLandscape ?  23.ckValue() : toptagView.frame.maxY + 10.ckValue(), vinylBackSize, vinylBackSize)
        
        let coverSize = vinylBackSize * 0.5
        coverImgView.layer.cornerRadius = coverSize / 2
        coverImgView.frame = CGRectMake((vinylImgView.width - coverSize) / 2, (vinylImgView.height - coverSize) / 2, coverSize, coverSize)
        
        let miniLyricTop = isPhoneLandscape ? vinylImgView.frame.maxY + 5.ckValue() : vinylImgView.frame.maxY + 20.ckValue()
        let miniLyricHeight = isPhoneLandscape ? self.bounds.height - miniLyricTop - controlHeight : self.bounds.height - miniLyricTop - controlHeight + 50.ckValue()
        miniLyricView.frame = CGRectMake(0, miniLyricTop, self.bounds.width, miniLyricHeight)
        
        self.checkPlayStatus()
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
        self.configMusicPlayer()
        self.setNeedleRotationCenter()
        
    }
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()
    
    weak var delegate: PlayerSubViewDelegate?
    
    let topSpace = kStatusBarHeight + 15.ckValue() + 40.ckValue()
    
    /// 播放中的索引
    var playingIndex: Int?
    
    /// 黑胶的尺寸
    var vinylBackSize: CGFloat {
        get {
            switch kaka_osType() {
            case .macOS:
                let screenWidth = self.bounds.size.width * 0.65
                let maxSize = 430.ckValue()
                return min(screenWidth, maxSize)
            case .iPadOS:
                let screenWidth = self.bounds.size.width
                return screenWidth * 0.7
            case .iOS:
                let isLandscape = OrientationManager.shared.isLandscape
                let screenWidth = self.bounds.size.width
                return screenWidth * (isLandscape ? 0.5 : 0.9)
            }
        }
    }
    
    var leftSpace: CGFloat {
        get {
            switch kaka_osType() {
            case .macOS:
                return 200.ckValue()
            case .iPadOS:
                return vinylBackSize * 0.4
            case .iOS:
                return vinylBackSize * 0.45
            }
        }
    }
    
    
    // MARK:  懒加载
    
    lazy var toptagView: AudioTagListView = {
        let view = AudioTagListView(frame: CGRectMake(0, topSpace, self.bounds.width, 33.ckValue()))
        view.isHidden = !AppLocalManager.shared.isShowAudioTag
        view.onClickBlock = { [weak self] (tagStr) in
            self?.setupAudioChannel()
        }
        return view
    }()
    
    lazy var vinylImgView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "music_heijiao"))
        view.frame = CGRectMake((self.bounds.size.width - vinylBackSize) / 2, toptagView.frame.maxY + 10.ckValue(), vinylBackSize, vinylBackSize)
        view.isUserInteractionEnabled = true
        view.contentMode = .scaleAspectFit
        view.layer.masksToBounds = true

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(playStyleViewClick))
        singleTap.numberOfTapsRequired = 1
        view.addGestureRecognizer(singleTap)
        
        return view
    }()
    
    lazy var coverImgView: UIImageView = {
        let model = KakaMusicPlayer.shared.playingMusic
        let coverImage: UIImage? = model?.musicCoverImage() ?? model?.placeImage()

        let view = UIImageView(image: coverImage ?? UIImage(named: "music_place"))
        let coverSize = vinylBackSize * 0.5
        view.frame = CGRectMake((vinylImgView.width - coverSize) / 2, (vinylImgView.height - coverSize) / 2, coverSize, coverSize)
        view.contentMode = .scaleAspectFill
        view.layer.masksToBounds = true
        return view
    }()
    
//    lazy var needleImgView: UIImageView = {
//        
//        var image = UIImage(named: "player_needle")!
//        let imgWidth = 94.0
//        let imgHeight = vinylBackSize * 1.6
//        
//        image = image.verticallyStretchableImage(withTopRate: 0.5, bottomRate: 0.6)
//        image = image.kaka_reSize(reSize: CGSizeMake(imgWidth, imgHeight))!
//        
//        let view = UIImageView(image: image)
//        view.frame = CGRectMake(CGRectGetMaxX(vinylImgView.frame) - leftSpace / 3, vinylImgView.top, imgWidth, imgHeight)
//        view.contentMode = .scaleAspectFit
//        view.backgroundColor = .random()
//        return view
//    }()
    
    lazy var miniLyricView: MiniPlayerLyricView = {
        let controlHeight = OrientationManager.shared.playerControlHeight

        let view = MiniPlayerLyricView(frame: CGRectMake(0, CGRectGetMaxY(vinylImgView.frame), self.bounds.width, self.bounds.height - CGRectGetMaxY(vinylImgView.frame) - controlHeight + 50.ckValue()))
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapClick))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapClick))
        singleTap.numberOfTapsRequired = 1
        view.addGestureRecognizer(singleTap)
        
        singleTap.require(toFail: doubleTap)
        
        return view
    }()
    
    
}


extension PlayerVinylCollectCell {
    func configMusicPlayer() {
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
        
        // 播放状态
        KakaMusicPlayer.shared.$playbackStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.playerStatusChanged(status)
            }.store(in: &cancellables)
        
        // 设备朝向变化了
        OrientationManager.shared.$isLandscape
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLandscape in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.layoutSubviews()
                    self?.checkPlayStatus()
                }
            }.store(in: &cancellables)
        
        // 显示音频标签
        AppLocalManager.shared.$isShowAudioTag
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isShowAudioTag in
                let isPhoneLandscape = kaka_IsiPhone() && OrientationManager.shared.isLandscape
                self?.toptagView.isHidden = !isShowAudioTag || isPhoneLandscape
            }.store(in: &cancellables)
        
        // 确保继续旋转
        self.checkPlayStatus()
    }
    
    func checkPlayStatus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] () in
            guard let wSelf = self else { return }
            let isPlaying = KakaMusicPlayer.shared.isPlaying
            if isPlaying && !wSelf.vinylImgView.isAnimating {
                self?.playerStatusChanged(.readyToPlay)
            }
        }
    }
    
    // 当前音乐模型变化了
    func playingMusicChanged() {
        guard let model = KakaMusicPlayer.shared.playingMusic else { return }
        
        let coverImage: UIImage? = (model.musicCoverImage() ?? TaglibMetadataParser.extractCoverArt(from: model.mediaPlayURL)) ?? model.placeImage()

        self.coverImgView.kf.setImage(with: model.coverThumbnailURL(), placeholder: coverImage)
                
        self.toptagView.model = model
    }
    
    // 播放器样式变化了
    @objc func playerUIStyleChanged() {
                
        let style = MusicConfigManager.shared.playerStyle
        
        if !style.isVinylStyle() {
            return
        }
        
        self.vinylImgView.image = style.iconImage()
        
        self.checkPlayStatus()
    }
    
    func playerStatusChanged(_ status: KSPlayerState) {
//        let isPlaying = KakaMusicPlayer.shared.isPlaying
        
//        // 唱针
//        UIView.animate(withDuration: 0.3) {
//            self.needleImgView.transform = isPlaying ? CGAffineTransform(rotationAngle: CGFloat.pi / 10) : .identity
//        }
        
        // 旋转黑胶
        switch status {
        case .initialized, .buffering, .preparing:
            self.vinylImgView.pauseRotating()
            break
        case .bufferFinished:
            self.vinylImgView.resumeRotating()
            break
        case .readyToPlay:
            self.vinylImgView.startRotating(25)
            break
        case .paused, .playedToTheEnd, .error:
            self.vinylImgView.pauseRotating()
            break
        }
        
    }
    
    func setNeedleRotationCenter() {
//        let newAnchor = CGPoint(x: 0.5, y: 153.0 / 1039.0)
//        
//        let oldOrigin = needleImgView.frame.origin
//        needleImgView.layer.anchorPoint = newAnchor
//        let newOrigin = needleImgView.frame.origin
//
//        let offset = CGPoint(x: newOrigin.x - oldOrigin.x, y: newOrigin.y - oldOrigin.y)
//        needleImgView.center = CGPoint(x: needleImgView.center.x - offset.x,
//                                       y: needleImgView.center.y - offset.y)
    }
    
    // 播放器样式
    @objc func playStyleViewClick() {
        self.delegate?.playerBasicCellDidPlayerStyle(basicView: self)
    }
    
    // 声道支持页面
    @objc func setupAudioChannel() {
        self.delegate?.playerBasicCellDidChannel(backView: self)
    }
    
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
