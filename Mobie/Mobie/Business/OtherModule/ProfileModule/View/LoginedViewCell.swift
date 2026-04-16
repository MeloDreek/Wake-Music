//
//  LoginedViewCell.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/19.
//

import KakaFoundation
import AppGroupKit

/// 已登录的Cell
class LoginedViewCell: UITableViewCell {
    
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
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(descdescLabel)
    }
    
    private func preSetupContains() {
        avatarView.snp.makeConstraints { make in
            if kaka_IsiPhone() {
                make.centerY.equalToSuperview()
                make.leading.equalToSuperview().offset(20.ckValue())
            }else{
                make.top.equalToSuperview().offset(20.ckValue())
                make.centerX.equalToSuperview()
            }
            make.size.equalTo(avatarView.layer.cornerRadius * 2)
        }
        
        nameLabel.snp.makeConstraints { make in
            if kaka_IsiPhone() {
                make.leading.equalTo(avatarView.snp.trailing).offset(20.ckValue())
                make.bottom.equalTo(avatarView.snp.centerY).offset(1.ckValue())
            }else{
                make.centerX.equalToSuperview()
                make.top.equalTo(avatarView.snp.bottom).offset(10.ckValue())
            }
            make.size.greaterThanOrEqualTo(0)
        }
        
        descdescLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(3.ckValue())
            make.leading.equalTo(nameLabel)
            if kaka_IsiPhone() {
                make.trailing.equalToSuperview().inset(20.ckValue())
            }else{
                make.centerX.equalTo(nameLabel)
            }
            make.height.greaterThanOrEqualTo(0)
        }
    }
    
    private func preSetupHandleBuness() {
        self.accessoryType = .disclosureIndicator
        self.selectionStyle = .default
        
        let userModel = UserInfoManager.shared
        
        self.avatarView.image = userModel.getAvatarImage()
    }
    
    func update() {
        let userModel = UserInfoManager.shared
        
        let isVIP = UserInfoManager.shared.isVIP()
        let avatarPlace = userModel.getAvatarImage()
        self.avatarView.image = avatarPlace
        self.nameLabel.text = userModel.nickName
        
        if isVIP {
            self.accessoryType = .none
            self.accessoryView = self.headwareView
        }else{
            self.accessoryType = .disclosureIndicator
            self.accessoryView = nil
        }
        let isExperiencing = userModel.expireDate == nil || userModel.expireDate == 0
        
#if Target_Mobie_Pro
        self.descdescLabel.text = "Premium User".localStr()
        self.descdescLabel.textColor = UIColor.secondaryLabel
#else
        self.descdescLabel.text = isVIP ? "Premium User".localStr() : (isExperiencing ? "Basic User".localStr() : "Premium expired".localStr())
        self.descdescLabel.textColor = (isVIP || isExperiencing) ? UIColor.secondaryLabel : UIColor.red
#endif
        
    }
    
    @objc func clickAvatarTap() {
        self.onAvatarBlock?(self.avatarView)
    }
    
    // MARK:  GET && SET 
    var onAvatarBlock: ((UIImageView)->Void)?
    
    // MARK:  懒加载 
    lazy var avatarView: UIImageView = {
        let view = UIImageView(image: avatarImage)
        view.backgroundColor = UIColor.rgb(191, 211, 253)
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = kaka_IsiPhone() ? 30.ckValue() : 42.ckValue()
        view.isUserInteractionEnabled = true
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(clickAvatarTap))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.font = UIFontBold(16.ckValue())
        view.textAlignment = kaka_IsiPhone() ? (PhoneSetManager.isArabicLanguage() ? .right : .left) : .center
        view.text = UIDevice.current.name
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var headwareView: UIImageView = {
        let view = UIImageView(image: Reasource.named("vip_gift_crown"))
        view.contentMode = .scaleAspectFit
        view.size = CGSizeMake(34.ckValue(), 34.ckValue())
        return view
    }()
    
    lazy var descdescLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = UIFontLight(12.ckValue())
        view.textAlignment = nameLabel.textAlignment
        view.textColor = UIColor.secondaryLabel
        return view
    }()
}
