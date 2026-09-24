//
//  PlayBackgroundView.swift
//  Mobie
//
//  Created by 张文 on 5/27/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import Combine
import WaketagLibKit

class PlayBackgroundView: UIView {
    
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
        self.addSubview(backImgView)
        
        backImgView.addSubview(effectView)
        backImgView.addSubview(blackView)
        backImgView.addSubview(gradientView)
    }
    
    private func setupAutoLayout() {
        backImgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        blackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupCusBuness() {
        // 合并两个触发源（playingMusic + playbackModel）
        Publishers.CombineLatest(
            KakaMusicPlayer.shared.$playingMusic,
            MusicConfigManager.shared.$playbackModel
        )
        .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main) // 限制触发频率
        .sink { [weak self] _, _ in
            self?.playingMusicChanged()
        }
        .store(in: &cancellables)
        
        self.playingMusicChanged()
    }
    
    func playingMusicChanged() {
        let request = UUID()
        artworkRequest = request
        backImgView.kf.cancelDownloadTask()
        guard let model = KakaMusicPlayer.shared.playingMusic else {
            backImgView.image = nil
            gradientView.setArtwork(nil)
            return
        }
                
        let playbackModel = MusicConfigManager.shared.playbackModel
        let backType = playbackModel.backgroundType
        let backConfig = playbackModel.backgroundConfig
        
        switch backType {
        case .defaultType:
            let coverImage: UIImage = model.coverArt ?? model.musicCoverImage() ?? model.placeImage()
            let hasArtwork = model.coverArt != nil || FileManager.default.fileExists(atPath: model.coverThumbnailURL().path)
            if backConfig == .coverAssetColor { gradientView.setArtwork(hasArtwork ? coverImage : nil) }
            self.backImgView.kf.setImage(with: model.coverThumbnailURL(), placeholder: coverImage) { [weak self] result in
                guard let self, self.artworkRequest == request, backConfig == .coverAssetColor else { return }
                if case .success(let value) = result { self.gradientView.setArtwork(value.image) }
            }
            break
        case .systemType:
            let backImage = playbackModel.backgroundImage() ?? model.placeImage()
            self.backImgView.image = backImage
            
            let coverImage: UIImage = backImage
            if backConfig == .coverAssetColor { self.updateCoverGradientColor(coverImage) }
            break
        case .customType:
            let backImage = playbackModel.backgroundImage() ?? model.placeImage()
            self.backImgView.image = backImage
            
            if backConfig == .coverAssetColor { self.updateCoverGradientColor(backImage) }
            break
        }
        
        switch backConfig {
        case .gaussianBlur:
            self.effectView.isHidden = false
            self.blackView.isHidden = true
            self.gradientView.isHidden = true
            break
        case .coverAssetColor:
            self.effectView.isHidden = true
            self.blackView.isHidden = true
            self.gradientView.isHidden = false
            break
        case .translucencyMask:
            self.effectView.isHidden = true
            self.blackView.isHidden = !playbackModel.isShowAlphaMask
            self.gradientView.isHidden = true
            break
        default: break
        }
        
    }
    
    // 提取背景图的主色调
    func updateCoverGradientColor(_ backImage: UIImage) {
        gradientView.setArtwork(backImage)
    }
    
    // MARK:  GET && SET
    var cancellables = Set<AnyCancellable>()
    
    private var artworkRequest = UUID()
    
    // MARK:  懒加载
    
    lazy var backImgView: UIImageView = {
        let view = UIImageView(image: nil)
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()
    
    // 高斯模糊
    lazy var effectView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        view.isHidden = MusicConfigManager.shared.playbackModel.backgroundConfig != .gaussianBlur
        view.frame = self.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()
    
    // 半透明遮罩
    lazy var blackView: UIView = {
        let view = UIView()
        view.isHidden = MusicConfigManager.shared.playbackModel.backgroundConfig != .translucencyMask
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        return view
    }()
    
    // 主色调
    lazy var gradientView: ArtworkBackgroundView = {
        let view = ArtworkBackgroundView(frame: self.bounds)
        view.isHidden = MusicConfigManager.shared.playbackModel.backgroundConfig != .coverAssetColor
        return view
    }()
    
}
