//
//  ConnectedSourceTableCell.swift
//  Mobie
//
//  Created by 张文 on 2/26/25.
//

import KakaFoundation
import AppGroupKit

class ConnectedSourceTableCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.accessoryType = .disclosureIndicator
        self.selectionStyle = .default
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.hanldeBessness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        contentView.addSubview(coverImgView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(descLabel)
    }
    
    private func preSetupContains() {
        coverImgView.snp.makeConstraints { make in
            make.top.equalTo(20.ckValue())
            make.leading.equalTo(18.ckValue())
            make.size.equalTo(30.ckValue())
            make.centerY.equalToSuperview()
        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImgView.snp.trailing).offset(10.ckValue())
            make.trailing.equalToSuperview().offset(-5.ckValue())
            make.height.greaterThanOrEqualTo(nameLabel.font.lineHeight)
            make.centerY.equalTo(coverImgView.snp.centerY).offset(-descLabel.font.lineHeight / 2)
        }
        
        descLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalTo(nameLabel)
            make.height.greaterThanOrEqualTo(descLabel.font.lineHeight)
            make.top.equalTo(nameLabel.snp.bottom)
        }
        
    }
    
    private func hanldeBessness() {
        self.accessoryType = .disclosureIndicator
    }
        
    
    var serverModel: ServerConfigModel? {
        didSet {
            guard let serverModel = self.serverModel else { return  }
            
            let isSelect = ConnectConfigManager.shared.currentServerModel() == serverModel
            
            coverImgView.image = serverModel.serverType.iconImage()
            nameLabel.attributedText = self.titleAttbuteStr(title: serverModel.showTitle(), isSelect: isSelect)
            descLabel.text = serverModel.descString()
        }
    }
    
    func titleAttbuteStr(title: String, isSelect: Bool) -> NSAttributedString {
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        let attbutes: [NSAttributedString.Key: Any] = [.font: nameLabel.font!, .foregroundColor: UIColor.label, .paragraphStyle: paragraphStyle]
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(NSAttributedString(string: title + "  ", attributes: attbutes))
        
        return attributedText
    }
    
    lazy var coverImgView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 4.ckValue()
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.lineBreakMode = .byTruncatingMiddle
        view.numberOfLines = 1
        view.font = UIFontBold(16.ckValue())
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.lineBreakMode = .byTruncatingMiddle
        view.font = UIFontLight(12.ckValue())
        view.textAlignment = nameLabel.textAlignment
        view.textColor = UIColor.label
        return view
    }()
    
}
