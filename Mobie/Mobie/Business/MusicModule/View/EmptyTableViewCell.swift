//
//  EmptyTableViewCell.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/30.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import NVActivityIndicatorView

protocol EmptyContentCellDelegate: AnyObject {
    // 导入音乐
    func emptyContentViewDidClickImport(cell: UIView)
    
    // 所有格式
    func emptyContentViewDidClickFormats(cell: UIView)
}

class EmptyTableViewCell: UITableViewCell {
    
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
        contentView.addSubview(middleView)
        
        middleView.addSubview(emptyImgView)
        middleView.addSubview(titleLabel)
        middleView.addSubview(messaleLabel)
        middleView.addSubview(formatButton)
        middleView.addSubview(importButton)
        middleView.addSubview(loadingView)
        middleView.addSubview(loadingLabel)
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
            make.leading.equalTo(20.ckValue())
            make.top.equalTo(emptyImgView.snp.bottom).offset(30.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        messaleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            if kaka_IsiPhone() {
                make.leading.equalTo(0)
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
            make.height.equalTo(50.ckValue())
            make.bottom.equalToSuperview() // 设置 bottom 约束
        }
        
        middleView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-15.ckValue())
            make.width.equalTo(contentView).multipliedBy(0.9) // 可根据需要调整
        }
        
        loadingView.snp.makeConstraints { make in
            make.centerX.equalTo(middleView)
            make.centerY.equalToSuperview().offset(-4.ckValue())
            make.size.equalTo(loadingView.size)
        }
        
        loadingLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(loadingView.snp.bottom).offset(8.ckValue())
            make.width.equalToSuperview().multipliedBy(0.8)
            make.height.greaterThanOrEqualTo(0)
        }
    }
    
    
    private func preSetupHandleBuness() {
        self.accessoryType = .none
        self.selectionStyle = .none
        
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: Notification.Name(kAppearanceChangedKey), object: nil)
    }
    
    // MARK:  GET && SET 
    
    var delegate: EmptyContentCellDelegate?
    
    let normalMsg = "The ultimate player for your local library. Experience flawless support for embedded covers and lyrics. Running out of space? Seamlessly connect your cloud storage.".localStr()
    
    // 监听 tintColor 的变化
    @objc func appModeStyleChanged(_ noti: Notification) {
        guard let newColor = noti.object as? UIColor else { return }
        
        let isDark = AppLocalManager.shared.appearanceStyle == .dark || self.overrideUserInterfaceStyle == .dark

        if ColorFontManager.shared.accentTyle == .color0 && isDark {
            self.formatButton.layer.borderColor = UIColor.deAccent.cgColor
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
        view.text = self.normalMsg
        view.textColor = UIColor.secondaryLabel
        view.font = UIFontLight(16.ckValue())
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
    
    @objc func importButtonClick() {
        self.delegate?.emptyContentViewDidClickImport(cell: self.importButton)
    }
    
    lazy var formatButton: UIButton = {
        let text = "Why Wake Music?".localStr()
        
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
    
    @objc func formatButtonClick() {
        self.delegate?.emptyContentViewDidClickFormats(cell: self.formatButton)
    }
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 25.ckValue(), 25.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: .lineScalePulseOutRapid, color: appMainColor)
        return view
    }()
    
    lazy var loadingLabel: UILabel = {
        let view = UILabel()
        view.isHidden = true
        view.text = "Parsing music tags".localStr()
        view.font = UIFontLight(13.ckValue())
        view.textColor = appMainColor
        view.textAlignment = .center
        view.numberOfLines = 0
        return view
    }()
    
    func startRefreshData(_ loadingText: String = "Parsing music tags".localStr()) {
        self.formatButton.isHidden = true
        self.importButton.isHidden = true
        self.messaleLabel.isHidden = true
        self.emptyImgView.isHidden = true
        self.titleLabel.isHidden = true
        self.loadingLabel.isHidden = false
        
        self.loadingLabel.text = loadingText
        self.loadingView.startAnimating()
    }
    
    func stopRefreshData() {
        self.formatButton.isHidden = false
        self.importButton.isHidden = false
        self.messaleLabel.isHidden = false
        self.emptyImgView.isHidden = false
        self.titleLabel.isHidden = false
        self.loadingLabel.isHidden = true
        
        self.loadingView.stopAnimating()
    }
    
}
