//
//  WelcomeTapeCollectCell.swift
//  Mobie
//
//  Created by 张文 on 6/12/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import Combine
import KSPlayer
import KakaTaglibKit
import DominantColors

class WelcomeTapeCollectCell: UICollectionViewCell {
    
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
        contentView.addSubview(backImgView)
        
        contentView.addSubview(soundIconView)
        contentView.addSubview(tapeView)
        contentView.addSubview(miniLyricView)
        
        contentView.addSubview(buttonView)
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
                
        backImgView.frame = contentView.bounds
        backImgView.frame = contentView.bounds
        
        soundIconView.frame = CGRectMake((self.bounds.width - soundIconSize) / 2, topSpace, soundIconSize, soundIconSize)
        
        let tapeValue = tapeImage.size.height / tapeImage.size.width
        let tapeTop = soundIconView.frame.maxY + tapeTopSpace - 10.ckValue()
        tapeView.frame = CGRectMake((self.bounds.width - tapeImgWidth) / 2, tapeTop, tapeImgWidth, tapeImgWidth * tapeValue)
        
        var lyricHeight = self.bounds.height - self.buttonView.height - self.tapeView.frame.maxY
        lyricHeight = max(lyricHeight, miniLyricView.aniLyricLabel.font.lineHeight * 1.5)
        miniLyricView.frame = CGRectMake(0, tapeView.frame.maxY, self.bounds.width, lyricHeight)
        
        self.buttonView.width = contentView.width
    }
    
    private func setupCusBuness() {
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.playingMusicChanged()
            }.store(in: &cancellables)
        
        // 屏幕旋转了
        OrientationManager.shared.$isLandscape.receive(on: DispatchQueue.main)
            .sink { [weak self] isLandscape in
                guard let wSelf = self else { return }
                wSelf.buttonView.frame = CGRectMake(
                    0,
                    (wSelf.isStarPlay || isLandscape) ? wSelf.bounds.height : wSelf.bounds.height - wSelf.buttonView.height,
                    wSelf.bounds.width,
                    wSelf.buttonView.height)
            }.store(in: &cancellables)

        self.playingMusicChanged()

    }
    
    // MARK:  GET && SET
    var cancellables = Set<AnyCancellable>()
    
    var topSpace: CGFloat {
        get {
            return kStatusBarHeight + 40.ckValue()
        }
    }
    
    let tapeImage: UIImage = UIImage(named: "tape_back")!
    
    let bottomColor = UIColor.rgb(33, 33, 55)
    
    var onPlayBlock: (()->Void)?
    
    
    var tapeImgWidth: CGFloat {
        get {
            switch kaka_osType() {
            case .macOS:
                let screenWidth = self.bounds.size.width * 0.75
                let maxSize = 500.ckValue()
                return min(screenWidth, maxSize)
            case .iPadOS:
                let contentWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
                return contentWidth * 0.75
            case .iOS:
                let isLandscape = OrientationManager.shared.isLandscape
                let contentWidth = self.bounds.width
                return isLandscape ? contentWidth * 0.65 : contentWidth - 30
            }
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
                return 60.ckValue()
            case .iOS:
                let isLandscape = OrientationManager.shared.isLandscape || UIDevice.current.isSmalliPhone()
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
    
    
    // 已经在播放了
    var isStarPlay: Bool = false
    
    // MARK:  懒加载
    lazy var backImgView: UIImageView = {
        let iconPath = Reasource.fullFilePath(PlayBackgroundSystem.style1.systemImageName())
        let view = UIImageView(image: nil)
        view.kf.setImage(with: URL(fileURLWithPath: iconPath))
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()
    
    lazy var soundIconView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "tape_sound"))
        view.frame = CGRectMake((self.bounds.width - soundIconSize) / 2, topSpace, soundIconSize, soundIconSize)
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var tapeView: TapePlayerView = {
        let tapeValue = tapeImage.size.height / tapeImage.size.width
        
        let view = TapePlayerView(frame: CGRectMake((self.bounds.width - tapeImgWidth) / 2, soundIconView.frame.maxY + tapeTopSpace, tapeImgWidth, tapeImgWidth * tapeValue))
        view.playerStyle = .tape3
        return view
    }()
    
    lazy var miniLyricView: MiniPlayerLyricView = {
        let lyricHeight = self.bounds.height - self.buttonView.height - self.tapeView.frame.maxY
        let view = MiniPlayerLyricView(frame: CGRectMake(0, self.tapeView.frame.maxY, self.bounds.width, lyricHeight))
        return view
    }()
    
    lazy var buttonView: WelcomeTapeBtnView = {
        let isLandScape = UIScreen.main.bounds.width > UIScreen.main.bounds.height && !kaka_IsMacOS()
        let bottomHeight = kaka_safeAreaInsets().bottom / 2 + 200.ckValue()
        
        let view = WelcomeTapeBtnView(frame: CGRectMake(0, isLandScape ? self.bounds.height : self.bounds.height - bottomHeight, self.bounds.width, bottomHeight))
        view.onPlayBlock = { [weak self] () in
            self?.startPlayAnimation()
        }
        view.backgroundColor = .clear
        return view
    }()
    
   
}

extension WelcomeTapeCollectCell {
    func playingMusicChanged() {
                
        self.tapeView.playingMusicChanged()
        
    }
    
    @objc func startPlayAnimation() {
        UIView.animate(withDuration: 0.35) { [weak self] () in
            guard let wSelf = self else { return }
            wSelf.buttonView.top = wSelf.bounds.height
        } completion: { [weak self] finish in
            self?.isStarPlay = true
            self?.onPlayBlock?()
        }
    }
    
}
