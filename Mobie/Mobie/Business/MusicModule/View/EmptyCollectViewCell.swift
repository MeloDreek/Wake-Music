//
//  EmptyCollectViewCell.swift
//  Wake Music
//
//  Created by 张文 on 9/18/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import NVActivityIndicatorView


class EmptyCollectViewCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        contentView.addSubview(middleView)
        
        middleView.addSubview(emptyImgView)
        middleView.addSubview(titleLabel)
        middleView.addSubview(messaleLabel)
        middleView.addSubview(formatButton)
        middleView.addSubview(importButton)
        contentView.addSubview(loadingView)
    }
    
    private func preSetupContains() {
        var capeWidth = 280.ckValue()
        switch kaka_osType() {
        case .iOS: capeWidth = UIDevice.current.isSmalliPhone() ? 230 : 320
        case .iPadOS: capeWidth = 480.ckValue()
        case .macOS: capeWidth = 400.ckValue()
        }
        
        let value = emptyImgView.image!.size.height / emptyImgView.image!.size.width
        emptyImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
            make.width.equalTo(capeWidth)
            make.height.equalTo(emptyImgView.snp.width).multipliedBy(value)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.82)
            make.top.equalTo(emptyImgView.snp.bottom).offset(30.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        messaleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            if kaka_IsiPhone() {
                make.leading.equalTo(5.ckValue())
            }else{
                make.width.equalTo(emptyImgView)
            }
            make.top.equalTo(titleLabel.snp.bottom).offset(10.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        importButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            if kaka_IsiPad() {
                make.width.equalTo(emptyImgView)
            } else {
                make.width.equalTo(messaleLabel)
            }
            make.top.equalTo(messaleLabel.snp.bottom).offset(30.ckValue())
            make.height.equalTo(50.ckValue())
        }
        
        formatButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            if kaka_IsiPad() {
                make.width.equalTo(importButton)
            } else {
                make.width.equalTo(messaleLabel)
            }
            make.top.equalTo(importButton.snp.bottom).offset(15.ckValue())
            make.height.equalTo(importButton)
            make.bottom.equalToSuperview() // 设置 bottom 约束
        }
                
        middleView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(contentView).multipliedBy(0.9) // 可根据需要调整
        }
        
        loadingView.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.size.equalTo(loadingView.size)
        }
        
    }
    
    
    private func preSetupHandleBuness() {
        
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear

        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: Notification.Name(kAppearanceChangedKey), object: nil)
    }
    
    // MARK:  GET && SET
    
    var delegate: EmptyContentCellDelegate?
    
    // 监听 tintColor 的变化
    @objc func appModeStyleChanged(_ noti: Notification) {
        guard let newColor = noti.object as? UIColor else { return }
        
        let isDark = AppLocalManager.shared.appearanceStyle == .dark || self.overrideUserInterfaceStyle == .dark

        if ColorFontManager.shared.accentTyle == .color0 && isDark {
            self.formatButton.layer.borderColor = UIColor.white.cgColor
        }else{
            self.formatButton.layer.borderColor = newColor.cgColor
        }
        
        self.importButton.backgroundColor = newColor
        self.formatButton.setTitleColor(newColor, for: .normal)
    }
    
    @objc func appearanceChanged() {
        
        let isDark = AppLocalManager.shared.appearanceStyle == .dark || self.overrideUserInterfaceStyle == .dark

        if ColorFontManager.shared.accentTyle == .color0 && isDark {
            self.formatButton.layer.borderColor = UIColor.white.cgColor
        }else{
            self.formatButton.layer.borderColor = appMainColor.cgColor
        }
    }
    
    func showConnectEmpty() {
        self.importButton.isHidden = false
        self.formatButton.isHidden = false
        self.importButton.setTitle("Import Music".localStr(), for: .normal)
        
        self.titleLabel.text = "Connect Your Music".localStr()
        self.messaleLabel.text = "Even if you collect a million songs, it won't take up any disk space on your device. No need for any APIs, and you can perfectly display embedded album art and lyrics in remote files".localStr()
        self.layoutIfNeeded()
    }
    
    func showLoginFailed() {
        self.importButton.isHidden = false
        self.formatButton.isHidden = true
        
        self.importButton.setTitle("Login".localStr(), for: .normal)
        
        self.titleLabel.text = "Not Authenticated".localStr()
        self.messaleLabel.text = "Login failed or token has expired, please reauthorize".localStr()
        self.layoutIfNeeded()
    }
    
    func startLoadingAnimation() {
        self.loadingView.startAnimating()
        
        self.middleView.isHidden = true
    }
    
    func stopLoadingAnimation() {
        self.loadingView.stopAnimating()
        
        self.middleView.isHidden = false
    }
    
    // MARK:  懒加载
    lazy var middleView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var emptyImgView: UIImageView = {
        let image = UIImage(named: "empty_music")
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textAlignment = .center
        view.text = "All Your Music, Anywhere.".localStr()
        view.textColor = UIColor.label
        view.font = UIFontBold(20.ckValue())
        return view
    }()
    
    lazy var messaleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textAlignment = .center
        view.text = "The ultimate player for your local library. Experience flawless support for embedded covers and lyrics. Running out of space? Seamlessly connect your cloud storage.".localStr()
        view.textColor = UIColor.secondaryLabel
        view.font = UIFontLight(16.ckValue())
        return view
    }()
    
    lazy var formatButton: UIButton = {
        let text = "Support All Formats".localStr()
        
        let view = UIButton()
        view.layer.borderColor = appMainColor.cgColor
        view.layer.borderWidth = 2.ckValue()
        view.addTarget(self, action: #selector(formatButtonClick), for: .touchUpInside)
        view.setTitle(text, for: .normal)
        view.backgroundColor = UIColor(named: "DeAccentColor")
        view.setTitleColor(appMainColor, for: .normal)
        view.titleLabel?.font = UIFontBold(15.ckValue())
        view.layer.masksToBounds = true
        view.layer.cornerRadius = importButton.layer.cornerRadius
        return view
    }()
    
    lazy var importButton: UIButton = {
        let view = UIButton(type: .custom)
        view.setTitle("Import Music".localStr(), for: .normal)
        view.titleLabel?.font = UIFontBold(15.ckValue())
        view.backgroundColor = appMainColor
        view.setTitleColor(UIColor(named: "DeAccentColor"), for: .normal)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        view.addTarget(self, action: #selector(importButtonClick), for: .touchUpInside)
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 25.ckValue(), 25.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: .lineScalePulseOutRapid, color: appMainColor)
        return view
    }()
    
    @objc func importButtonClick() {
        self.delegate?.emptyContentViewDidClickFormats(cell: self.importButton)
    }
    
    @objc func formatButtonClick() {
        self.delegate?.emptyContentViewDidClickImport(cell: self.formatButton)
    }
}
