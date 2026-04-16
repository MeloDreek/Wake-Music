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
import KakaTaglibKit
import DominantColors

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
        guard let model = KakaMusicPlayer.shared.playingMusic else { return }
                
        let playbackModel = MusicConfigManager.shared.playbackModel
        let backType = playbackModel.backgroundType
        let backConfig = playbackModel.backgroundConfig
        
        switch backType {
        case .defaultType:
            let coverImage: UIImage = (model.musicCoverImage() ?? TaglibMetadataParser.extractCoverArt(from: model.mediaPlayURL)) ?? model.placeImage()
            self.backImgView.kf.setImage(with: model.coverThumbnailURL(), placeholder: coverImage)
            
            self.updateCoverGradientColor(coverImage)
            break
        case .systemType:
            let backImage = playbackModel.backgroundImage() ?? model.placeImage()
            self.backImgView.image = backImage
            
            let coverImage: UIImage = backImage
            self.updateCoverGradientColor(coverImage)
            break
        case .customType:
            let backImage = playbackModel.backgroundImage() ?? model.placeImage()
            self.backImgView.image = backImage
            
            let coverImage: UIImage = (model.musicCoverImage() ?? TaglibMetadataParser.extractCoverArt(from: model.mediaPlayURL)) ?? model.placeImage()
            self.updateCoverGradientColor(coverImage)
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
        guard let cgImage = backImage.cgImage, let cgColors = try? DominantColors.dominantColors(image: cgImage, quality: .fair, algorithm: .CIE76, maxCount: 2, sorting: .frequency), cgColors.count > 0 else {
            let newColors: [CGColor] = [UIColor.hexColor("#FF00FF").cgColor, bottomColor.cgColor]
            self.gradientView.gradientColors = newColors
            return
        }
        
        let newColors: [CGColor] = [cgColors[0], bottomColor.cgColor]
        self.gradientView.gradientColors = newColors
    }
    
    // MARK:  GET && SET
    var cancellables = Set<AnyCancellable>()
    
    let bottomColor = UIColor.rgb(33, 33, 55)
    
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
    lazy var gradientView: KakaGradientView = {
        let view = KakaGradientView(frame: self.bounds)
        view.isHidden = MusicConfigManager.shared.playbackModel.backgroundConfig != .coverAssetColor
        view.startPoint = CGPoint(x: 0, y: 0)
        view.endPoint = CGPoint(x: 0, y: 1) // 水平渐变
        return view
    }()
    
}
