//
//  RadioTableViewCell.swift
//  Wake Music
//
//  Created by Melo on 9/6/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

class RadioTableViewCell: UITableViewCell {
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
        contentView.addSubview(topImgView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descLabel)
    }
    
    private func preSetupContains() {
        topImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
            make.size.equalTo(topImgView.size)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(topImgView.snp.bottom).offset(10.ckValue())
            make.height.greaterThanOrEqualTo(0)
            make.width.equalToSuperview()
        }
        
        descLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10.ckValue())
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.greaterThanOrEqualTo(0)
            make.bottom.equalToSuperview().inset(10.ckValue())
        }
    }
    
    
    private func preSetupHandleBuness() {
        self.selectionStyle = .none
        self.accessoryType = .none
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    // MARK:  GET && SET
    
    // MARK:  懒加载
    lazy var topImgView: UIImageView = {
        let image = UIImage(named: "radio_fm")
        let value = image!.size.height / image!.size.width
        
        let view = UIImageView(image: image)
        view.size = CGSize(width: 200.ckValue(), height: 200.ckValue() * value)
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.text = "Global Music Radio".localStr()
        view.font = UIFontBold(22.ckValue())
        view.textColor = .label
        view.textAlignment = .center
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.text = "Global Music Radio is a 24-hour never-ending music broadcasting which is suitable for your home, car, gym, 5 star hotel, party and all other scenarios that support Airdrop.".localStr()
        view.numberOfLines = 0
        view.font = UIFontLight(15.ckValue())
        view.textColor = UIColor.label.withAlphaComponent(0.8)
        view.textAlignment = .center
        return view
    }()
    
}
