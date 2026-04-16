//
//  VideoImporterViewCell.swift
//  Wake Music
//
//  Created by Melo on 9/10/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import NVActivityIndicatorView
import AVFoundation

class VideoImporterViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        contentView.addSubview(selectLabel)
        contentView.addSubview(coverImgView)
        contentView.addSubview(playButton)
        contentView.addSubview(loadingView)
        contentView.addSubview(prograssLabel)
        
        contentView.addSubview(videoMaskView)
        videoMaskView.addSubview(sizeLabel)
        videoMaskView.addSubview(timeLabel)
    }
    
    private func preSetupContains() {
        coverImgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        playButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(48.ckValue())
        }
        
        selectLabel.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
        }
        
        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(loadingView.size)
        }
        
        prograssLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(loadingView.snp.bottom).offset(2.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        videoMaskView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(40.ckValue())
        }
        
        sizeLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(8.ckValue())
            make.leading.equalTo(20.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        timeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20.ckValue())
            make.centerY.equalTo(sizeLabel)
            make.size.greaterThanOrEqualTo(0)
        }
        
    }
    
    
    private func preSetupHandleBuness() {
        self.selectionStyle = .default
        self.accessoryType = .none
    }
    
    func startLoading() {
        selectLabel.isHidden = true
        coverImgView.isHidden = true
        playButton.isHidden = true
        prograssLabel.isHidden = false
        loadingView.startAnimating()
    }
    
    var progress: Double = 0 {
        didSet {
            if progress >= 0.99  {
                prograssLabel.text = "Please wait".localStr()
            }else{
                let text = String(format: "%.2f", progress * 100) + "%"
                prograssLabel.text = text
            }
        }
    }
    
    
    func stopLoading() {
        selectLabel.isHidden = false
        prograssLabel.isHidden = true
        loadingView.stopAnimating()
    }
    
    // MARK:  GET && SET
    var fileURL: URL? {
        didSet {
            guard let fileURL = fileURL else {
                selectLabel.isHidden = false
                playButton.isHidden = true
                coverImgView.isHidden = true
                videoMaskView.isHidden = true
                return
            }
                        
            selectLabel.isHidden = true
            playButton.isHidden = false
            coverImgView.isHidden = false
            videoMaskView.isHidden = false
            
            sizeLabel.text = fileURL.fileSizeString
            
            let asset = AVAsset(url: fileURL)
            let totalSeconds = CMTimeGetSeconds(asset.duration)
            let minutes = Int(totalSeconds) / 60
            let seconds = Int(totalSeconds) % 60
            
            timeLabel.text = String(format: "%02d:%02d", minutes, seconds)
            coverImgView.image = fileURL.getVideoThumbnail() ?? Reasource.named("sound_place")
            
#warning("模拟mock数据")
//        #if DEBUG
//            coverImgView.image = BroadcastsType.fm1.coverImage()
//        #endif
        }
    }
    
    // MARK:  懒加载
    lazy var coverImgView: UIImageView = {
        let view = UIImageView(image: Reasource.named("sound_place"))
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.isHidden = true
        return view
    }()
    
    lazy var playButton: UIImageView = {
        let view = UIImageView()
        view.isHidden = true
        view.image = UIImage(named: "video_play")
        return view
    }()
    
    lazy var selectLabel: UILabel = {
        let view = UILabel()
        view.text = VideoAudioInfoType.selectVideo.titleStr()
        view.font = UIFontBold(16.ckValue())
        view.textColor = appMainColor
        view.textAlignment = .center
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 40.ckValue(), 40.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: .pacman, color: appMainColor)
        return view
    }()
    
    lazy var videoMaskView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "video_bottom_shadow"))
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    lazy var sizeLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = UIFontBold(13.ckValue())
        return view
    }()
    
    lazy var timeLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = UIFontBold(13.ckValue())
        return view
    }()
    
    lazy var prograssLabel: UILabel = {
        let view = UILabel()
        view.isHidden = true
        view.textColor = .label
        view.font = UIFontBold(13.ckValue())
        view.textAlignment = .center
        return view
    }()
}
