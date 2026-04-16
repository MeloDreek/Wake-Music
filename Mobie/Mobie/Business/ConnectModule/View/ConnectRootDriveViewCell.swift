//
//  ConnectRootDriveViewCell.swift
//  Mobie
//
//  Created by 张文 on 4/2/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import Kingfisher


class ConnectRootDriveViewCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        contentView.addSubview(colorView)
        contentView.addSubview(avatarImgView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(arrowIconView)
    }
    
    private func setupAutoLayout() {
        colorView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(13.ckValue())
            make.centerX.equalToSuperview()
            make.top.equalTo(13.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        avatarImgView.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.bottom.equalToSuperview().inset(8.ckValue())
            make.size.equalTo(avatarImgView.layer.cornerRadius * 2)
        }
        
        arrowIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(12.ckValue())
            make.size.equalTo(16.ckValue())
        }
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    // MARK:  GET && SET
    var serverModel: ServerConfigModel? {
        didSet {
            guard let serverModel = self.serverModel else { return }
            if let baiduUser = serverModel.baiduUser {
                avatarImgView.kf.setImage(with: URL(string: baiduUser.avatar_url), placeholder: serverModel.serverType.iconImage())
                nameLabel.text = kaka_IsiPhone() ? baiduUser.baidu_nickname() : serverModel.serverType.titleStr() + " | " + baiduUser.baidu_nickname()
            }else if let drive115User = serverModel.drive115User {
                avatarImgView.kf.setImage(with: URL(string: drive115User.user_face_l), placeholder: serverModel.serverType.iconImage())
                nameLabel.text = "115" + "_" + drive115User.user_name
            }else{
                avatarImgView.image = serverModel.serverType.iconImage()
                nameLabel.text = serverModel.serverType.titleStr()
            }
            
            colorView.backgroundColor = ColorFontManager.shared.defaultType.color()
        }
    }
    
    static func headHeight() -> CGFloat {
        let height = (kaka_IsiPhone() ? 120 : 160).ckValue()
        return height
    }
    
    // MARK:  懒加载
    lazy var colorView: UIView = {
        let view = UIView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = kaka_IsMacOS() ? 12 : 8.ckValue()
        return view
    }()
    
    lazy var avatarImgView: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = false
        view.contentMode = .scaleAspectFit
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 20.ckValue()
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.isUserInteractionEnabled = false
        view.numberOfLines = 0
        view.font = UIFontBold(18.ckValue())
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.textColor = .white
        return view
    }()
    
    lazy var arrowIconView: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("chevron.forward", color: .white))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
}

