//
//  SocialMediaHeadView.swift
//  Mobie
//
//  Created by 张文 on 12/27/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

class SocialMediaHeadView: UITableViewHeaderFooterView {
    
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
        self.backgroundColor = UIColor.rgb(110, 168, 175)
        
        contentView.addSubview(avatarView)
        contentView.addSubview(popView)
        contentView.addSubview(blueView)
        contentView.addSubview(messageLabel)
    }
    
    private func preSetupContains() {
        avatarView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(5.ckValue())
            make.width.equalTo(300.ckValue())
            make.height.equalTo(Self.avatarHeight)
        }
        
        popView.snp.makeConstraints { make in
            make.centerX.equalTo(avatarView.snp.trailing)
            make.size.equalTo(50.ckValue())
            make.top.equalTo(avatarView).offset(10.ckValue())
        }
        
        blueView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(avatarView.snp.bottom)
            make.height.greaterThanOrEqualTo(0)
            make.bottom.equalToSuperview()
        }
        
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(blueView).offset(20.ckValue())
            make.centerX.equalToSuperview()
            make.leading.equalToSuperview().offset(20.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
    }
    
    private func preSetupHandleBuness() {
        
    }
    
    static func allheight(_ maxWidth: CGFloat) -> CGFloat {
        let avavtarHeight = 5.ckValue() + Self.avatarHeight
        
        let messageHeight = Self.messageStr.height(forWidth: maxWidth - 40.ckValue(), font: Self.messageFont)
        
        return avavtarHeight + messageHeight + 60.ckValue() + 50.ckValue()
    }
    
    // MARK:  GET && SET
    
    static let avatarHeight = kaka_IsiPhone() ? 200.0 : 240.0.ckValue()

    static let messageStr = "Hi, this is indie developer Melo, I am responsible for the technical support of this application on iPhone, iPad, macOS, Apple Watch, CarPlay and Apple TV. If you encounter any issues during use, you can contact me through social media. We always welcome your suggestions and feedback, communicating like friends.".localStr()
    
    static let messageFont = UIFontLight(16.ckValue())
    
    // MARK:  Lazy Init
    lazy var avatarView: UIImageView = {
        let language = PhoneSetManager.formatLanguage()
        var image: UIImage
        switch language {
        case .chinese_simplified, .chinese_traditional:
            image = Reasource.named("avatar_1")
            break
        default:
            image = Reasource.named("avatar_4")
            break
        }
        
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var popView: UIImageView = {
        let view = UIImageView(image: Reasource.named("pop_chat"))
        return view
    }()
    
    lazy var blueView: KakaAutoCornerView = {
        let view = KakaAutoCornerView(frame: CGRect(x: 0, y: 0, width: self.width, height: 30.ckValue()))
        view.sksCornersInfo = ([UIRectCorner.topLeft, UIRectCorner.topRight], 20.ckValue())
        view.backgroundColor = UIColor.systemBlue
        return view
    }()

    lazy var messageLabel: UILabel = {
        let view = UILabel()
        
        let attach1 = NSTextAttachment()
        attach1.image = Reasource.named("reply_char_start").withTintColor(UIColor.rgb(217, 245, 194)).flippedImage()
        attach1.bounds = CGRect(x: 0, y: -5, width: 30, height: 30)
        
        let attach2 = NSTextAttachment()
        attach2.image = Reasource.named("reply_char_end").withTintColor(UIColor.rgb(217, 245, 194)).flippedImage()
        attach2.bounds = CGRect(x: 0, y: -10, width: 30, height: 30)
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(NSAttributedString(attachment: attach1))
        attributedText.append(self.introduceAttbuteStr())
        attributedText.append(NSAttributedString(attachment: attach2))
        
        view.attributedText = attributedText
        view.numberOfLines = 0
        return view
    }()
    
    func introduceAttbuteStr() -> NSAttributedString {
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        paragraphStyle.lineSpacing = 5.ckValue()
        let attbutes: [NSAttributedString.Key: Any] = [.font: Self.messageFont, .foregroundColor: UIColor.white, .paragraphStyle: paragraphStyle]
        
        let sumStr = Self.messageStr
        
        let attributedText = NSAttributedString(string: " " + sumStr + " ", attributes: attbutes)
        
        return attributedText
    }
    
}


class SocialMediaTableCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.accessoryType = .disclosureIndicator
        self.selectionStyle = .default
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var socialType: SocialMediaType? {
        didSet {
            guard let socialType = self.socialType else { return }
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.image = socialType.iconImage()
            cellConfig.text = socialType.titleStr()
            cellConfig.imageProperties.maximumSize = CGSize(width: 35.ckValue(), height: 35.ckValue())
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            self.contentConfiguration = cellConfig
        }
    }
    
}
