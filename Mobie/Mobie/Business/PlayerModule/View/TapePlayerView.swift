//
//  TapePlayerView.swift
//  Mobie
//
//  Created by 张文 on 6/3/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import Combine
import KSPlayer
import KakaTaglibKit


class TapePlayerView: UIView {
    
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
        self.addSubview(tapeImgView)
        tapeImgView.addSubview(backColorView)
        
        backColorView.addSubview(coverImgView)
        
        backColorView.addSubview(bottomColorView)
        backColorView.addSubview(middleColorView)
        backColorView.addSubview(topColorView)
        backColorView.addSubview(wheelColorView)
        
        wheelColorView.addSubview(blackWheelView)
        wheelColorView.addSubview(leftWheelView)
        wheelColorView.addSubview(rightWheelView)
    }
    
    
    override func layoutSubviews() {

        super.layoutSubviews()
        
        let colorWidth = self.bounds.width * (894.0 / 1030.0)
        let colorHeight = self.bounds.height * (372.0 / 867.0)
        let colorTop = self.bounds.height * (188.0 / 867.0)
        
        let backColorCorner = colorHeight * (6.0 / 124.0)

        backColorView.layer.cornerRadius = backColorCorner
        tapeImgView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        backColorView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(colorTop)
            make.width.equalTo(colorWidth)
            make.height.equalTo(colorHeight)
        }
        
        let coverSize = colorHeight * (54.0 / 124.0)
        let coverSpace = colorHeight * (3.0 / 124.0)
        coverImgView.layer.cornerRadius = coverSpace
        coverImgView.snp.remakeConstraints { make in
            make.left.equalTo(coverSpace)
            make.top.equalTo(coverSpace)
            make.size.equalTo(coverSize)
        }
        
        let bottomHeight = colorHeight * (38.0 / 124.0)
        bottomColorView.snp.remakeConstraints { make in
            make.left.equalToSuperview()
            make.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.equalTo(bottomHeight)
        }
        
        let middleHeight = colorHeight * (14.0 / 124.0)
        middleColorView.snp.remakeConstraints { make in
            make.left.equalToSuperview()
            make.bottom.equalTo(bottomColorView.snp.top)
            make.centerX.equalToSuperview()
            make.height.equalTo(middleHeight)
        }
        
        let topHeight = colorHeight * (8.0 / 124.0)
        topColorView.snp.remakeConstraints { make in
            make.left.equalToSuperview()
            make.bottom.equalTo(middleColorView.snp.top).offset(kaka_IsMacOS() ? 1 : 0)
            make.centerX.equalToSuperview()
            make.height.equalTo(topHeight)
        }
        
        let wheelColorWidth = colorWidth * (189.0 / 300.0)
        let wheelColorHeight = colorHeight * (48.0 / 124.0)
        let wheelColorCorner = colorHeight * (10.0 / 124.0)
        wheelColorView.layer.cornerRadius = wheelColorCorner
        wheelColorView.snp.remakeConstraints { make in
            make.top.equalTo(coverImgView.snp.bottom).offset(-coverSpace)
            make.centerX.equalToSuperview()
            make.width.equalTo(wheelColorWidth)
            make.height.equalTo(wheelColorHeight)
        }
        
        blackWheelView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.5)
            make.height.equalToSuperview().multipliedBy(0.9)
        }
        
        leftWheelView.snp.remakeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(wheelColorWidth * 0.025)
            make.height.equalToSuperview().multipliedBy(0.75)
            make.width.equalTo(leftWheelView.snp.height)
        }
        
        rightWheelView.snp.remakeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-wheelColorWidth * 0.025)
            make.size.equalTo(leftWheelView)
        }
        
        self.checkPlayStatus()
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
        
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
        
        self.checkPlayStatus()
    }
    
    func checkPlayStatus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] () in
            guard let wSelf = self else { return }
            let isPlaying = KakaMusicPlayer.shared.isPlaying
            if isPlaying && !wSelf.leftWheelView.isAnimating {
                self?.playerStatusChanged(.readyToPlay)
            }
        }
    }
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()
    
    weak var delegate: PlayerSubViewDelegate?
    
    var playerStyle: PlayerUIStyle? {
        didSet {
            guard let style = self.playerStyle, let sectionColors = style.sectionColors() else { return }
            
            backColorView.backgroundColor = sectionColors.0
            bottomColorView.backgroundColor = sectionColors.1
            middleColorView.backgroundColor = sectionColors.2
            topColorView.backgroundColor = sectionColors.3
            wheelColorView.backgroundColor = sectionColors.4
            
            self.checkPlayStatus()
        }
    }
    
    
    // MARK:  懒加载
    
    lazy var tapeImgView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "tape_back"))
        view.frame = self.bounds
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var backColorView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 6.ckValue()
        view.backgroundColor = .white
        return view
    }()
    
    lazy var coverImgView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "app_logo"))
        view.isUserInteractionEnabled = true
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        view.contentMode = .scaleAspectFill
        
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(coverImgViewClick(_:)))
        view.addGestureRecognizer(clickTap)
        
        return view
    }()
    
    lazy var bottomColorView: UIView = {
        let view = UIView()
        return view
    }()
    
    lazy var middleColorView: UIView = {
        let view = UIView()
        return view
    }()
    
    lazy var topColorView: UIView = {
        let view = UIView()
        return view
    }()
    
    lazy var wheelColorView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 10.ckValue()
        return view
    }()
    
    lazy var leftWheelView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "tape_wheel"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var rightWheelView: UIImageView = {
        let view = UIImageView(image: leftWheelView.image)
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var blackWheelView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "tape_side"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
}

extension TapePlayerView {
    // 当前音乐模型变化了
    func playingMusicChanged() {
        guard let model = KakaMusicPlayer.shared.playingMusic else { return }
                
        let coverImage: UIImage? = (model.musicCoverImage() ?? TaglibMetadataParser.extractCoverArt(from: model.mediaPlayURL)) ?? model.placeImage()
        self.coverImgView.kf.setImage(with: model.coverThumbnailURL(), placeholder: coverImage)
    }
    
    // 播放状态
    func playerStatusChanged(_ playStatus: KSPlayerState) {
        switch playStatus {
        case .initialized, .buffering, .preparing:
            self.leftWheelView.pauseRotating()  // 暂停旋转
            self.rightWheelView.pauseRotating()
            break
        case .bufferFinished:
            self.leftWheelView.resumeRotating()
            self.rightWheelView.resumeRotating()
            break
        case .readyToPlay:
            self.leftWheelView.startRotating(7) // 即将解码
            self.rightWheelView.startRotating(7)
            break
        case .paused:
            self.leftWheelView.pauseRotating()  // 暂停旋转
            self.rightWheelView.pauseRotating()
            break
        case .playedToTheEnd, .error:
            self.leftWheelView.pauseRotating()   // 停止并重置旋转
            self.rightWheelView.pauseRotating()
            break
        }
        
    }
    
    @objc func coverImgViewClick(_ sender: UITapGestureRecognizer) {
        guard let coverImgView = sender.view as? UIImageView, let image = coverImgView.image else { return }
        
        self.delegate?.playerBasicCellDidCoverImage(backView: coverImgView, coverImage: image)
    }
    
}
