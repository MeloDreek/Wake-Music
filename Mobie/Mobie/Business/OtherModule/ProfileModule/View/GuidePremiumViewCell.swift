//
//  GuidePremiumViewCell.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/19.
//

import KakaFoundation
import AppGroupKit

/// 引导开通VIP
class GuidePremiumViewCell: UITableViewCell {
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
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.contentView.backgroundColor = appMainColor
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(descLabel)
        contentView.addSubview(moreButton)
    }
    
    private func preSetupContains() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(25.ckValue())
            make.centerX.equalToSuperview()
            make.leading.equalTo(10.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        descLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(8.ckValue())
            make.trailing.equalToSuperview().inset(20.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        moreButton.snp.makeConstraints { make in
            make.top.equalTo(descLabel.snp.bottom).offset(25.ckValue())
            make.centerX.equalTo(titleLabel)
            make.leading.equalTo(titleLabel).offset(20.ckValue())
            make.height.equalTo(50.ckValue())
            make.bottom.equalToSuperview().inset(20.ckValue())
        }
    }
    
    private func preSetupHandleBuness() {
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
    }
    
    @objc func appModeStyleChanged(_ noti: Notification) {
        guard let newColor = noti.object as? UIColor else { return }
        self.contentView.backgroundColor = newColor
        self.moreButton.setTitleColor(newColor, for: .normal)
    }
    
    
    lazy var titleLabel: UILabel = {
        let sizeValue = 128.0 / 61
        let attach1 = NSTextAttachment()
        attach1.image = Reasource.named("maizi_left").flippedImage()
        attach1.bounds = CGRect(x: 0, y: -5.ckValue(), width: 15.ckValue(), height: 15.ckValue() * sizeValue)
        
        let attach2 = NSTextAttachment()
        attach2.image = Reasource.named("maizi_right").flippedImage()
        attach2.bounds = attach1.bounds
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 3.ckValue()
        let attbutes: [NSAttributedString.Key: Any] = [.font: UIFontBold(20.ckValue()), .foregroundColor: UIColor.deAccent, .paragraphStyle: paragraphStyle]
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(NSAttributedString(attachment: attach1))
        attributedText.append(NSAttributedString(string: "  " + "Upgrade to Premium".localStr() + "  ", attributes: attbutes))
        attributedText.append(NSAttributedString(attachment: attach2))
        
        let view = UILabel()
        view.numberOfLines = 0
        view.attributedText = attributedText
        view.textAlignment = .center
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textColor = UIColor.deAccent
        view.text = "One-time payment to unlock all features on native iPhone, iPad, Mac".localStr()
        view.textAlignment = titleLabel.textAlignment
        view.font = kaka_IsMacOS() ? UIFontLight(12.ckValue()) : UIFontLight(13.ckValue())
        return view
    }()
    
    lazy var moreButton: UIButton = {
        
        let text = "Upgrade to Premium".localStr()
        let font = UIFontBold(15.ckValue())
        let width = text.width(font) + 60.ckValue()
        
        let view = UIButton(type: .custom)
        view.isUserInteractionEnabled = false
        view.setTitle(text, for: .normal)
        view.titleLabel?.font = font
        view.backgroundColor = UIColor.deAccent
        view.setTitleColor(appMainColor, for: .normal)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        return view
    }()
    
}
