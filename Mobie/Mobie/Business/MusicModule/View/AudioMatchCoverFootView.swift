//
//  AudioMatchCoverFootView.swift
//  Mobie
//
//  Created by kaka on 2026/8/13.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaPhotoBrowser


class AudioMatchCoverFootView: UITableViewHeaderFooterView {
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.setupSubViews()
        self.setupContains()
        self.handleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubViews() {
        contentView.addSubview(coverImgView)
        contentView.addSubview(statusLabel)
        contentView.addSubview(loadingView)
        
#warning("模拟mock数据")
//        coverImgView.addSubview(blurEffectView)
    }
    
    func setupContains() {
        
        coverImgView.snp.makeConstraints { make in
            make.trailing.equalTo(statusLabel.snp.leading).offset(-15.ckValue())
            if kaka_IsMacOS() {
                make.top.equalToSuperview().offset(6.ckValue())
            }else{
                make.centerY.equalToSuperview()
            }
            make.size.equalTo(60.ckValue())
        }
        
#warning("模拟mock数据")
//        blurEffectView.snp.makeConstraints { make in
//            make.edges.equalToSuperview()
//        }
        
        statusLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-18.ckValue())
            make.centerY.equalTo(coverImgView)
            make.size.greaterThanOrEqualTo(0)
        }
        
        
        loadingView.snp.makeConstraints { make in
            make.trailing.equalTo(statusLabel)
            make.top.equalToSuperview().offset(15.ckValue())
            make.size.equalTo(20.ckValue())
        }
    }
    
    func handleBuness() {
        
    }
    
    @objc func clickViewAction() {
        guard let loadedArtworkURL, loadedArtworkURL == model?.coverArt,
              let image = self.coverImgView.image, let attributedText = self.statusLabel.attributedText else {
            return
        }
        
        if attributedText.string == editManuaStr {
            return
        }
        
        self.delegate?.audioMatchArtworkClickCover(coverView: self, artwork: image)
    }
    
    // MARK: GET && SET
    weak var delegate: AudioMatchTagDelete?
    
    var model: AudioFingerprintModel?
    var cellType: MeteDataCellItemType?
    private var loadedArtworkURL: String?
    private var artworkRequestID = UUID()
    
    let textFont = kaka_IsMacOS() ? UIListContentConfiguration.cell().textProperties.font : UIFontLight(16.ckValue())
    
    let editManuaStr = "Please edit manually".localStr()
    
    func update(cellType: MeteDataCellItemType, model: AudioFingerprintModel?) {
        let requestID = UUID()
        artworkRequestID = requestID
        coverImgView.kf.cancelDownloadTask()
        loadedArtworkURL = nil
        coverImgView.image = nil
        coverImgView.isHidden = true
        statusLabel.attributedText = nil
        self.cellType = cellType
        self.model = model
        
        guard let model = model else {
            self.loadingView.startAnimating()
            return
        }
        
        self.loadingView.stopAnimating()
        
        if let coverURL = URL(string: model.coverArt ?? "") {
            self.coverImgView.isHidden = false
            self.loadingView.startAnimating()
            self.coverImgView.kf.setImage(with: coverURL) { [weak self] result in
                guard let self, self.artworkRequestID == requestID,
                      self.model?.coverArt == coverURL.absoluteString else { return }
                self.loadingView.stopAnimating()
                switch result {
                case .success:
                    self.loadedArtworkURL = coverURL.absoluteString
                    self.statusLabel.attributedText = NSAttributedString(string: "Embed".localStr(), attributes: [.font: self.textFont, .foregroundColor: UIColor.systemBlue, .underlineStyle: 1])
                case .failure:
                    self.loadedArtworkURL = nil
                    self.coverImgView.image = nil
                    self.statusLabel.attributedText = NSAttributedString(string: self.editManuaStr, attributes: [.font: self.textFont, .foregroundColor: UIColor.secondaryLabel])
                }
            }
            statusLabel.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().offset(-18.ckValue())
                make.centerY.equalTo(coverImgView)
                make.size.greaterThanOrEqualTo(0)
            }
        }else{
            self.coverImgView.isHidden = true
            self.statusLabel.attributedText = NSAttributedString(string: editManuaStr, attributes: [.font: UIFontLight(12.ckValue()), .foregroundColor: UIColor.secondaryLabel])
            statusLabel.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().offset(-18.ckValue())
                make.top.equalToSuperview().offset(13.ckValue())
                make.size.greaterThanOrEqualTo(0)
            }
        }
    }
    
    func setupFailedStatus() {
        artworkRequestID = UUID()
        coverImgView.kf.cancelDownloadTask()
        loadedArtworkURL = nil
        coverImgView.image = nil
        coverImgView.isHidden = true
        self.model = nil
        self.statusLabel.attributedText = NSAttributedString(string: editManuaStr, attributes: [.font: UIFontLight(12.ckValue()), .foregroundColor: UIColor.secondaryLabel])
        self.loadingView.stopAnimating()
        
        statusLabel.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().offset(-18.ckValue())
            make.top.equalToSuperview().offset(13.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
    }
    
    @objc func coverImgViewClick(_ sender: UITapGestureRecognizer) {
        
        if !UserInfoManager.shared.isVIP() {
            (self.currentViewController() as? SuperViewController)?.vipCenterClick()
            return
        }
        
        guard let coverImgView = sender.view as? UIImageView, let image = coverImgView.image else { return }
        
        guard let curVC = self.currentViewController() else { return }
        let photoItem = KakaPhotoItem(sourceView: coverImgView, image: image)
        let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
        photoBrowser.backgroundStyle = .blurPhoto
        photoBrowser.show(from: curVC)
    }
    
    // MARK: 懒加载
    
    lazy var coverImgView: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = true
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 4.ckValue()
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(coverImgViewClick))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    lazy var statusLabel: UILabel = {
        let view = UILabel()
        view.isUserInteractionEnabled = true
        view.numberOfLines = 2
        view.textColor = UIColor.systemBlue
        view.font = textFont
        view.textAlignment = PhoneSetManager.isArabicCountry() ? .left : .right
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(clickViewAction))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    lazy var loadingView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.color = .label
        return view
    }()
    
#warning("模拟mock数据")
//#if DEBUG
//    lazy var blurEffectView: UIVisualEffectView = {
//        let blurEffect = UIBlurEffect(style: .extraLight)
//        let view = UIVisualEffectView(effect: blurEffect)
//        view.frame = self.coverImgView.bounds
//        view.alpha = 0.5
//        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        return view
//    }()
//#endif
    
}
