//
//  PlayerTapeCollectCell.swift
//  Mobie
//
//  Created by 张文 on 5/26/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import Combine
import MarqueeLabel
import WaketagLibKit
import KSPlayer

/// 播放器-磁带样式
class PlayerTapeCollectCell: UICollectionViewCell {
    
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
        contentView.addSubview(soundIconView)
        contentView.addSubview(tapeView)
        
        contentView.addSubview(miniLyricView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let controlHeight = OrientationManager.shared.playerControlHeight
        let isPhoneLandscape = OrientationManager.shared.isCompactLandscape

        toptagView.frame = CGRectMake(0, topSpace, self.bounds.width, 33.ckValue())

        soundIconView.frame = CGRectMake((self.bounds.width - soundIconSize) / 2, toptagView.top, soundIconSize, soundIconSize)
        
        let tapeValue = tapeImage.size.height / tapeImage.size.width
        let tapeTop = isPhoneLandscape ? 20 : soundIconView.frame.maxY + tapeTopSpace + (kaka_IsMacOS() ? -10 : 0)
        tapeView.frame = CGRectMake((self.bounds.width - tapeImgWidth) / 2, tapeTop, tapeImgWidth, tapeImgWidth * tapeValue)
        
        miniLyricView.frame = CGRectMake(0, CGRectGetMaxY(tapeView.frame) + (isPhoneLandscape ? -20 : 0), self.bounds.width, max(0, self.bounds.height - tapeView.frame.maxY - controlHeight))
        toptagView.isHidden = !AppLocalManager.shared.isShowAudioTag || isPhoneLandscape
        soundIconView.isHidden = AppLocalManager.shared.isShowAudioTag || isPhoneLandscape
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
        // 显示音乐标签
        AppLocalManager.shared.$isShowAudioTag
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isShowAudioTag in
                let isPhoneLandscape = OrientationManager.shared.isCompactLandscape

                self?.toptagView.isHidden = !isShowAudioTag || isPhoneLandscape
                self?.soundIconView.isHidden = isShowAudioTag || isPhoneLandscape
            }.store(in: &cancellables)
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.toptagView.model = model
                self?.tapeView.playingMusicChanged()
            }.store(in: &cancellables)
        
        // 播放器样式
        MusicConfigManager.shared.$playerStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                self?.tapeView.playerStyle = style
            }.store(in: &cancellables)
    }
    
    // MARK:  GET && SET
    var cancellables = Set<AnyCancellable>()
    
    weak var delegate: PlayerSubViewDelegate?
    
    var tapeImgWidth: CGFloat {
        get {
            let preferredWidth: CGFloat
            switch kaka_osType() {
            case .macOS:
                let screenWidth = self.bounds.size.width * 0.75
                let maxSize = 500.ckValue()
                preferredWidth = min(screenWidth, maxSize)
            case .iPadOS:
                let contentWidth = self.bounds.width
                preferredWidth = contentWidth * 0.75
            case .iOS:
                let isLandscape = OrientationManager.shared.isCompactLandscape
                let contentWidth = self.bounds.width
                preferredWidth = isLandscape ? contentWidth * 0.65 : contentWidth - 30
            }
            let top = OrientationManager.shared.isCompactLandscape ? 20 :
                topSpace + soundIconSize + tapeTopSpace + (kaka_IsMacOS() ? -10 : 0)
            let availableHeight = max(0, bounds.height - top - OrientationManager.shared.playerControlHeight - 70.ckValue())
            return max(0, min(preferredWidth, availableHeight * tapeImage.size.width / tapeImage.size.height))
        }
    }
    
    var soundIconSize: CGFloat {
        get {
            switch kaka_osType() {
            case .macOS:
                let screenWidth = self.bounds.size.width * 0.15
                let maxSize = 80.ckValue()
                return screenWidth > maxSize ? maxSize : screenWidth
            case .iPadOS:
                return OrientationManager.shared.isLandscape ? 80.ckValue() : 130.ckValue()
            case .iOS:
                let isLandscape = OrientationManager.shared.isCompactLandscape
                return isLandscape ? 0 : 80.ckValue()
            }
        }
    }
    
    var tapeTopSpace: CGFloat {
        get {
            switch kaka_osType() {
            case .macOS:
                return -20.ckValue()
            case .iPadOS:
                return -20.ckValue()
            case .iOS:
                return 0
            }
        }
    }
    
    
    var topSpace: CGFloat { OrientationManager.shared.safeAreaInsets.top + 55.ckValue() }
    
    let tapeImage: UIImage = UIImage(named: "tape_back")!
    
    // MARK:  懒加载
    // 顶部Tag
    lazy var toptagView: AudioTagListView = {
        let view = AudioTagListView(frame: CGRectMake(0, topSpace, self.bounds.width, 33.ckValue()))
        view.isHidden = AppLocalManager.shared.isShowAudioTag
        view.onClickBlock = { [weak self] (tagStr) in
            self?.setupAudioChannel()
        }
        return view
    }()
    
    lazy var soundIconView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "tape_sound"))
        view.frame = CGRectMake((self.bounds.width - soundIconSize) / 2, toptagView.top, soundIconSize, soundIconSize)
        view.isHidden = !toptagView.isHidden
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var tapeView: TapePlayerView = {
        let tapeValue = tapeImage.size.height / tapeImage.size.width
        
        let view = TapePlayerView(frame: CGRectMake((self.bounds.width - tapeImgWidth) / 2, CGRectGetMaxY(soundIconView.frame) + tapeTopSpace, tapeImgWidth, tapeImgWidth * tapeValue))
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(playStyleViewClick))
        singleTap.numberOfTapsRequired = 1
        view.addGestureRecognizer(singleTap)
        
        return view
    }()
    
    lazy var miniLyricView: MiniPlayerLyricView = {
        let view = MiniPlayerLyricView(frame: CGRectMake(0, 0, self.bounds.width, 200.ckValue()))
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapClick))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapClick))
        singleTap.numberOfTapsRequired = 1
        view.addGestureRecognizer(singleTap)
        
        singleTap.require(toFail: doubleTap)
        
        return view
    }()
    
    // 声道支持页面
    @objc func setupAudioChannel() {
        self.delegate?.playerBasicCellDidChannel(backView: self)
    }
    
    // 播放样式
    @objc func playStyleViewClick() {
        self.delegate?.playerBasicCellDidPlayerStyle(basicView: self)
    }
    
    @objc func doubleTapClick() {
        if !kaka_IsiPhone() {
            return
        }
        
        self.delegate?.playerViewDidClickLyricBtn(playerView: self)
    }
    
    @objc func singleTapClick() {
        self.delegate?.controlViewDidBottomControl(controlView: self)
    }
}
