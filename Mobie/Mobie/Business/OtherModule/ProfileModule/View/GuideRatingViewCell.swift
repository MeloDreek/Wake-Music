//
//  GuideRatingViewCell.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/2/4.
//

import KakaUIKit
import KakaFoundation
import AppGroupKit

protocol GuideRatingViewCellDelegate: AnyObject {
    // 评分
    func guideCommentDidScore(cell: GuideRatingViewCell)
    
    // 分享
    func guideCommentDidShare(cell: GuideRatingViewCell, shareButton: UIButton)
}

///  引导评分和分享
class GuideRatingViewCell: UITableViewCell {
    
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
        self.backgroundColor = appMainColor
        self.selectionStyle = .none
        self.accessoryType = .none
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(descLabel)
        contentView.addSubview(appstoreButton)
        contentView.addSubview(shareButton)
    }
    
    private func preSetupContains() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(30.ckValue())
            make.centerX.equalToSuperview()
            make.leading.equalToSuperview().offset(20.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        descLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(20.ckValue())
            make.leading.equalTo(titleLabel)
            make.height.greaterThanOrEqualTo(0)
        }
        
        appstoreButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(descLabel.snp.bottom).offset(20.ckValue())
            make.leading.equalToSuperview().offset(30.ckValue())
            make.height.equalTo(50.ckValue())
        }
        
        shareButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(appstoreButton.snp.bottom).offset(15.ckValue())
            make.leading.equalToSuperview().offset(30.ckValue())
            make.height.equalTo(appstoreButton)
            make.bottom.equalToSuperview().inset(30.ckValue())
        }
    }
    
    private func preSetupHandleBuness() {
        NotificationCenter.default.addObserver(self, selector: #selector(appModeSwitchChanged), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
    }
    
    @objc func appModeSwitchChanged() {
        if self.isBlue {
            return
        }
        
        self.backgroundColor = appMainColor
        appstoreButton.setTitleColor(appMainColor, for: .normal)
        shareButton.setTitleColor(appMainColor, for: .normal)
    }
    
    // MARK:  GET && SET 
    
    weak var delegate: GuideRatingViewCellDelegate?
    
    var isBlue: Bool = false {
        didSet {
            self.backgroundColor = UIColor.systemBlue
            
            appstoreButton.backgroundColor = UIColor.white
            shareButton.backgroundColor = UIColor.white
            
            appstoreButton.setTitleColor(.systemBlue, for: .normal)
            shareButton.setTitleColor(.systemBlue, for: .normal)
            
            titleLabel.attributedText = self.titleAttbuteStr()
            descLabel.attributedText = self.descAttbuteStr()
        }
    }
    
    @objc func appstoreButtonClick() {
        
        self.delegate?.guideCommentDidScore(cell: self)
        
    }
    
    @objc func shareButtonClick(_ sender: UIButton) {
        
        self.delegate?.guideCommentDidShare(cell: self, shareButton: sender)
        
    }
    
    // MARK:  懒加载 
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.attributedText = self.titleAttbuteStr()
        view.textAlignment = .center
        return view
    }()
    
    func titleAttbuteStr() -> NSAttributedString {
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
        let attbutes: [NSAttributedString.Key: Any] = [.font: UIFontBold(20.ckValue()), .foregroundColor: self.isBlue ? UIColor.white : UIColor.deAccent, .paragraphStyle: paragraphStyle]
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(NSAttributedString(attachment: attach1))
        attributedText.append(NSAttributedString(string: "  " + "We need your help".localStr() + "  ", attributes: attbutes))
        attributedText.append(NSAttributedString(attachment: attach2))
        
        return attributedText
    }
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.attributedText = self.descAttbuteStr()
        view.numberOfLines = 0
        return view
    }()
    
    func descAttbuteStr() -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 3.ckValue()
        let attbutes: [NSAttributedString.Key: Any] = [.font: UIFontLight(15.ckValue()), .foregroundColor: self.isBlue ? UIColor.white : UIColor.deAccent, .paragraphStyle: paragraphStyle]

        let attributedText = NSAttributedString(string: "If you think we are not bad, please give us a 5 star rating or recommend it to your friends. Thank you for your support!".localStr(), attributes: attbutes)
        
        return attributedText
    }
    
    lazy var appstoreButton: UIButton = {
        let font = UIFontLight(15.ckValue())
        let text = "Five Star Rating".localStr()
        
        let view = UIButton(type: .custom)
        view.setTitle(text, for: .normal)
        view.titleLabel?.font = font
        view.backgroundColor = UIColor.deAccent
        view.setTitleColor(appMainColor, for: .normal)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        view.addTarget(self, action: #selector(appstoreButtonClick), for: .touchUpInside)
        return view
    }()

    lazy var shareButton: UIButton = {
        
        let font = UIFontLight(15.ckValue())
        let text = "Share with Friends".localStr()
        
        let view = UIButton(type: .custom)
        view.setTitle(text, for: .normal)
        view.titleLabel?.font = font
        view.backgroundColor = UIColor.deAccent
        view.setTitleColor(appMainColor, for: .normal)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = appstoreButton.layer.cornerRadius
        view.addTarget(self, action: #selector(shareButtonClick(_:)), for: .touchUpInside)
        return view
    }()
    
}
