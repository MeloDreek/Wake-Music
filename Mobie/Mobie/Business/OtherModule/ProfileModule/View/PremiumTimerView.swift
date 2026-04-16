//
//  PremiumTimerView.swift
//  Mobie
//
//  Created by 张文 on 12/6/24.
//

import KakaFoundation
import AppGroupKit

class PremiumTimerView: UIButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func preSetupSubViews() {
        self.addSubview(iconView)
        self.addSubview(timerLabel)
    }
    
    func preSetupContains() {
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(25.ckValue())
        }
        
        timerLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(2.ckValue())
            make.width.greaterThanOrEqualTo(timerLabel.width)
            make.height.equalTo(timerLabel.height)
            make.centerY.equalToSuperview()
        }
    }
    
    func preSetupHandleBuness() {
        self.isUserInteractionEnabled = true
        self.backgroundColor = .clear
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateDiscountTime(_:)), name: Notification.Name(rawValue: kDiscountLeftTimeKey), object: nil)
    }
    
    // MARK:  GET && SET
    
    var onStopCallback: (()->Void)?
    
    
    static func maxWidth() -> CGFloat {
        let text = "02:59:59.59"
        let font = UIFontBold(14.ckValue())
        let textWidth = text.width(font) + 3.ckValue()
        
        return 25.ckValue() + 2.ckValue() + textWidth
    }
    
    @objc func updateDiscountTime(_ noti: Notification) {
        
        guard let userInfo = noti.userInfo, let leftDiscountTime = userInfo["leftTime"] as? TimeInterval else { return }
        
        if leftDiscountTime <= 0 {
            self.onStopCallback?()
            return
        }
        
        let totalMilliseconds = Int(leftDiscountTime * 100)
        let hours = totalMilliseconds / (60 * 60 * 100)
        let minutes = (totalMilliseconds % (60 * 60 * 100)) / (60 * 100)
        let seconds = (totalMilliseconds % (60 * 100)) / 100
        let milliseconds = totalMilliseconds % 100
        
        self.timerLabel.text = String(format: "%02d:%02d:%02d.%02d", hours, minutes, seconds, milliseconds)
    }
    
    // MARK:  懒加载
    lazy var iconView: UIImageView = {
        let view = UIImageView(image: Reasource.named("gift_box"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var timerLabel: UILabel = {
        let text = "03:00:00.00"
        let font = UIFontBold(14.ckValue())
        
        let view = UILabel(frame: CGRectMake(0, 0, text.width(font) + 3.ckValue(), font.lineHeight))
        view.text = text
        view.textColor = appMainColor
        view.font = font
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        return view
    }()
}
