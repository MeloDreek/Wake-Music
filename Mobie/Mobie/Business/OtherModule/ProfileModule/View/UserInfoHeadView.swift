//
//  UserInfoHeadView.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/20.
//

import KakaFoundation
import AppGroupKit

protocol UserInfoHeadViewDelegate: AnyObject {
    // 点击头像
    func userHeadViewClickAVatar(view: UserInfoHeadView)
}

class UserInfoHeadView: UITableViewHeaderFooterView {
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        contentView.addSubview(avatarView)
        contentView.addSubview(uploadImgView)
        contentView.addSubview(nameLabel)
    }
    
    private func preSetupContains() {
        avatarView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-10.ckValue())
            make.size.equalTo(avatarView.layer.cornerRadius * 2)
        }
        
        uploadImgView.snp.makeConstraints { make in
            make.trailing.equalTo(avatarView.snp.trailing).offset(5.ckValue())
            make.bottom.equalTo(avatarView.snp.bottom).offset(-5.ckValue())
            make.size.equalTo(uploadImgView.layer.cornerRadius * 2)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(avatarView.snp.bottom).offset(10.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
    }
    
    
    private func preSetupHandleBuness() {
        self.update()
    }
    
    // MARK:  GET && SET 
    
    weak var delegate: UserInfoHeadViewDelegate?
    
    func update() {
        let vModel = UserInfoManager.shared
        
        self.avatarView.image = vModel.getAvatarImage()
        self.nameLabel.text = vModel.nickName
    }
    
    @objc func clickAvatarTap() {
        self.delegate?.userHeadViewClickAVatar(view: self)
    }
    
    // MARK:  懒加载 
    lazy var avatarView: UIImageView = {
        let view = UIImageView(image: avatarImage)
        view.backgroundColor = UIColor.rgb(191, 211, 253)
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 40.ckValue()
        view.isUserInteractionEnabled = true
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(clickAvatarTap))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    lazy var uploadImgView: UIImageView = {
        let view = UIImageView(image: Reasource.named("camera_upload"))
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 14.ckValue()
        view.layer.borderColor = UIColor.white.cgColor
        view.layer.borderWidth = 2.ckValue()
        view.isUserInteractionEnabled = true
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(clickAvatarTap))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.font = UIFontBold(18.ckValue())
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.text = UIDevice.current.name
        view.textColor = UIColor.label
        return view
    }()
    
}
