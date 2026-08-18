//
//  ServerSectionView.swift
//  Mobie
//
//  Created by 张文 on 2/23/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

class ServerSectionView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubViews()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        self.addSubview(backView)
        self.addSubview(serverLabel)
        self.addSubview(arrowView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let isRTL = UIView.userInterfaceLayoutDirection(for: self.semanticContentAttribute) == .rightToLeft
        
        let showTitle = self.serverModel?.showTitle() ?? self.defaultTitle

        let passWidth = showTitle.width(titleFont)
        let arroWidth = 16.ckValue()
        let leadSpace = 15.ckValue()
        let innerSpace = 5.ckValue()
        
        if isRTL {
            arrowView.frame = CGRectMake((self.width - passWidth) / 2 - (arroWidth + innerSpace) / 2, (self.height - arroWidth) / 2, arroWidth, arroWidth)
            serverLabel.frame = CGRectMake(CGRectGetMaxX(arrowView.frame) + innerSpace, (self.height - titleFont.lineHeight) / 2, passWidth, titleFont.lineHeight)
            backView.frame = CGRectMake(arrowView.left - leadSpace, 0, passWidth + 5.ckValue() + arroWidth + leadSpace * 2, self.height)
        }else{
            serverLabel.frame = CGRectMake((self.width - passWidth) / 2 - (arroWidth + innerSpace) / 2, (self.height - titleFont.lineHeight) / 2, passWidth, titleFont.lineHeight)
            arrowView.frame = CGRectMake(CGRectGetMaxX(serverLabel.frame) + innerSpace, (self.height - arroWidth) / 2, arroWidth, arroWidth)
            backView.frame = CGRectMake(serverLabel.left - leadSpace, 0, passWidth + 5.ckValue() + arroWidth + leadSpace * 2, self.height)
        }
    }
    
    private func setupCusBuness() {
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: Notification.Name(kAppearanceChangedKey), object: nil)
        
        self.backgroundColor = .clear
        self.serverModel = ConnectConfigManager.shared.currentServerModel()
        self.appearanceChanged()
    }
    
    @objc func appearanceChanged() {
        backView.layer.borderColor = appMainColor.cgColor
        serverLabel.textColor = appMainColor
        
        self.updateArrowImage()
    }
    
    @objc func appModeStyleChanged(_ noti: Notification) {
        guard let newColor = noti.object as? UIColor else { return }
        
        backView.layer.borderColor = newColor.cgColor
        serverLabel.textColor = newColor
        
        self.updateArrowImage()
    }
    
    // MARK:  GET && SET
    
    let titleFont = UIFont.boldSystemFont(ofSize: 14.ckValue())
    
    let defaultTitle = "Connect".localStr()
    
    var onClickCallBack: (()->Void)?
    
    var serverModel: ServerConfigModel? {
        didSet {
            
            self.updateArrowImage()
            
            guard let serverModel = serverModel else {
                self.serverLabel.text = defaultTitle
                self.layoutSubviews()
                return
            }
            
            self.serverLabel.text = serverModel.showTitle()
            self.layoutSubviews()
        }
    }
    
    func updateArrowImage()  {
        let isNone = ConnectConfigManager.shared.connectedModels.count == 0
        self.arrowView.image = Reasource.systemNamed(isNone ? "plus.circle" : "chevron.forward.circle.fill").flippedImage()
    }
    
    // MARK:  懒加载
    
    lazy var backView: UIControl = {
        let view = UIControl()
        view.backgroundColor = UIColor.clear
        view.layer.borderColor = appMainColor.cgColor
        view.layer.borderWidth = 1.ckValue()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = self.frame.size.height / 2
        view.addTarget(self, action: #selector(backViewClick), for: .touchUpInside)
        return view
    }()
    
    lazy var serverLabel: UILabel = {
        let view = UILabel()
        view.text = defaultTitle
        view.font = titleFont
        view.textAlignment = .center
        view.textColor = appMainColor
        return view
    }()
    
    lazy var arrowView: UIImageView = {
        let arrowImage = Reasource.systemNamed("chevron.forward.circle.fill").flippedImage()
        let view = UIImageView(image: arrowImage)
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    @objc func backViewClick() {
        self.onClickCallBack?()
    }
    
}
