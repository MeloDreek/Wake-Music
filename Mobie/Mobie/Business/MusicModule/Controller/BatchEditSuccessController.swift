//
//  BatchEditSuccessController.swift
//  Mobie
//
//  Created by kaka on 2026/8/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import StoreKit

/// 批量编辑成功后的庆祝页面
class BatchEditSuccessController: SuperViewController {
    
    /// 初始化结算页
    /// - Parameters:
    ///   - spentTime: 总耗时
    ///   - totalCount: 总数
    ///   - missingTagCount: 缺失标签数
    init(spentTime: TimeInterval, totalCount: Int, missingTagCount: Int) {
        super.init(nibName: nil, bundle: nil)
        self.spentTime = spentTime
        self.totalCount = totalCount
        self.missingTagCount = missingTagCount
    }
        
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .clear
        
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + (kaka_IsMacOS() ? 0.1 : 0)) {
            self.setupUI()
            self.setupLayout()
            self.handleBueeness()
        }
    }

    // MARK: - Setup UI

    @objc func setupUI() {

        // 背景遮罩
        view.addSubview(mengView)

        // 弹窗容器
        view.addSubview(containerView)
        
        // 关闭按钮
        view.addSubview(closeButton)
        
        // 成就卡片图片
        containerView.addSubview(achieveCardView)

        // Share 按钮（主按钮）
        containerView.addSubview(rateButton)

        // VIP 按钮（次按钮）
        containerView.addSubview(vipButton)
                
        // 关闭按钮
    }

    // MARK: - Layout
    @objc func setupLayout() {
        
        achieveCardView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(achieveCardView.height)
        }
        
        rateButton.snp.makeConstraints { make in
            make.top.equalTo(achieveCardView.snp.bottom).offset(20.ckValue())
            make.centerX.equalToSuperview()
            make.leading.equalToSuperview().offset(12.ckValue())
            make.trailing.equalToSuperview().offset(-12.ckValue())
            make.height.greaterThanOrEqualTo(50.ckValue())
        }
        
        vipButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(rateButton.snp.bottom).offset(15.ckValue())
            make.width.equalTo(rateButton)
            make.height.greaterThanOrEqualTo(50.ckValue())
        }
        
#if targetEnvironment(macCatalyst)
        closeButton.snp.makeConstraints { make in
            make.leading.equalTo(containerView.snp.leading).offset(20.ckValue())
            make.top.equalTo(containerView.snp.top).offset(20.ckValue())
            make.size.equalTo(30.ckValue())
        }
#else
        closeButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(containerView.snp.bottom).offset(15.ckValue())
            make.size.equalTo(30.ckValue())
        }
#endif
        
    }
    
    @objc func handleBueeness() {
        self.perform(#selector(animateAction), with: nil, afterDelay: kaka_IsMacOS() ? 0 : 0.02)
        
        self.updateComplete(time: self.spentTime, totalCount: self.totalCount, misstagCount: self.missingTagCount)
    }
    
    // MARK:  GET && SET

    let duration = kaka_IsMacOS() ? 0 :  0.32
    
    var spentTime: TimeInterval = 0
    
    var totalCount: Int = 0
        
    var missingTagCount: Int = 0
    
    var isGuideScore: Bool = false
    
    var isShowPremium: Bool {
        get {
            if UserInfoManager.shared.isVIP() {
                let isFreeTrail = UserInfoManager.shared.isFreeTrail
                return isFreeTrail ? true : false
            }else{
                return false
            }
        }
    }
    
    var otherHeight: CGFloat {
        get {
            let oneHeight = 20.ckValue() + 50.ckValue()
            return oneHeight * (self.isShowPremium ? 2 : 1) + 20.ckValue()
        }
    }
    
    // 更新数据
    func updateComplete(time: TimeInterval, totalCount: Int, misstagCount: Int) {
        let fullTagCount = totalCount - misstagCount
        let successRate = Double(fullTagCount) / Double(totalCount)
        let isGuideScore = totalCount >= 5 && successRate >= 0.75
        
        self.isGuideScore = isGuideScore
        self.rateButton.setTitle(isGuideScore ? "Rate Us 5 Stars".localStr() : "Share with Friends".localStr(), for: .normal)
        
        self.achieveCardView.updateComplete(time: time, totalCount: totalCount, missingTagCount: misstagCount, isGuideScore: isGuideScore)
    }
    
    // MARK: 懒加载
    private var confettiLayer: CAEmitterLayer?
    
    lazy var mengView: UIView = {
        let view = UIView(frame: self.view.bounds)
        view.isHidden = kaka_IsMacOS()
        view.alpha = 0
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()
    
    lazy var closeButton: UIButton = {
        let color = kaka_IsMacOS() ? UIColor.secondaryLabel : UIColor.white.withAlphaComponent(0.68)
        let view = UIButton(type: .custom)
        view.alpha = 0
        view.setBackgroundImage(Reasource.systemNamed("xmark.circle", color: color), for: .normal)
        view.addTarget(self, action: #selector(dismissAction), for: .touchUpInside)
        return view
    }()
    
    lazy var containerView: UIView = {
#if targetEnvironment(macCatalyst)
        let view = UIView(frame: self.view.bounds)
#else
        let width = self.view.width * 0.88
        let height = achieveCardView.height + otherHeight
        let view = UIView(frame: CGRectMake((self.view.width - width) / 2, (self.view.height - height) / 2, width, height))
#endif
        view.alpha = 0
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20.ckValue()
        view.clipsToBounds = true
        return view
    }()
    
    lazy var achieveCardView: BatchEditSuccessView = {
        let height = kaka_IsMacOS() ? self.view.height - otherHeight : (kaka_IsiPhone() ? 400 : 600)
        let view = BatchEditSuccessView(frame: CGRectMake(0, 0, self.view.width, height))
        return view
    }()
    
    lazy var rateButton: UIButton = {
        let view = UIButton(type: .custom)
        view.titleLabel?.font = UIFontBold(16.ckValue())
        view.backgroundColor = appMainColor
        view.setTitleColor(.white, for: .normal)
        view.layer.cornerRadius = 25.ckValue()
        view.titleLabel?.numberOfLines = 2
        view.titleLabel?.textAlignment = .center
        view.titleLabel?.lineBreakMode = .byWordWrapping
        view.titleLabel?.adjustsFontSizeToFitWidth = true
        view.titleLabel?.minimumScaleFactor = 0.85
        view.addTarget(self, action: #selector(rateButtonClick), for: .touchUpInside)
        return view
    }()
    
    lazy var vipButton: UIButton = {
        let vipTitle = "★" + "Upgrade to Lifetime".localStr()
        let view = UIButton(type: .custom)
        view.setTitle(vipTitle, for: .normal)
        view.titleLabel?.font = UIFontLight(14.ckValue())
        view.backgroundColor = UIColor.secondarySystemBackground
        view.setTitleColor(.label, for: .normal)
        view.layer.cornerRadius = self.rateButton.layer.cornerRadius
        view.titleLabel?.numberOfLines = 2
        view.titleLabel?.textAlignment = .center
        view.titleLabel?.lineBreakMode = .byWordWrapping
        view.titleLabel?.adjustsFontSizeToFitWidth = true
        view.titleLabel?.minimumScaleFactor = 0.85
        view.addTarget(self, action: #selector(vipButtonClick), for: .touchUpInside)
        return view
    }()
    
    
}

extension BatchEditSuccessController {
    @objc func animateAction() {
        
        self.containerView.transform = CGAffineTransformMakeScale(0.01, 0.01)
        self.containerView.alpha = 0
        self.mengView.alpha = 0
        self.closeButton.alpha = 0
        
        UIView.animate(withDuration: self.duration, animations: {
            self.containerView.alpha = 1
            self.mengView.alpha = 1
            self.closeButton.alpha = 1
            self.containerView.transform = .identity
        }, completion: { finished in
            self.startConfetti()
        })

    }

    @objc func dismissAction() {
        self.containerView.transform = CGAffineTransformMakeScale(1, 1)
        self.containerView.alpha = 1
        self.mengView.alpha = 1
        self.closeButton.alpha = 1
        
        UIView.animate(withDuration: duration, animations: {
            self.containerView.alpha = 0
            self.mengView.alpha = 0
            self.closeButton.alpha = 0
            self.containerView.transform = CGAffineTransformMakeScale(0.01, 0.01)
        }) { finish in
            self.dismiss(animated: false)
        }
    }
    
    // 五星好评
    @objc func rateButtonClick() {
        if self.isGuideScore {
            let appStoreURL = Application.wakeTag.appstoreWriteURL()
            UIApplication.shared.open(appStoreURL)
        }else{
            let shareVC = UIActivityViewController(activityItems: [Application.wakeTag.appstoreURL()], applicationActivities: nil)
            if !kaka_IsiPhone() {
                shareVC.popoverPresentationController?.sourceView = self.rateButton
            }
            
            self.present(shareVC, animated: true, completion: nil)
        }
    }
    
    // 解锁VIP
    @objc func vipButtonClick() {
        
        AppStoreKitManager.presentPurcharseVC(self)
    }

}

// MARK: 烟花庆祝动画
extension BatchEditSuccessController {
    private func startConfetti() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(
            x: view.bounds.midX,
            y: -10
        )
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: view.bounds.width, height: 1)
        
        let colors: [UIColor] = [
            .systemRed,
            .systemBlue,
            .systemGreen,
            .systemYellow,
            .systemOrange,
            .systemPink,
            .systemPurple
        ]
        
        let cells = colors.map { color -> CAEmitterCell in
            let cell = CAEmitterCell()
            cell.birthRate = 6
            cell.lifetime = 6
            cell.velocity = 180
            cell.velocityRange = 80
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 6
            cell.spin = 3
            cell.spinRange = 4
            cell.scale = 0.6
            cell.scaleRange = 0.3
            cell.contents = makeConfettiImage(color: color)
            return cell
        }
        
        emitter.emitterCells = cells
        view.layer.addSublayer(emitter)
        confettiLayer = emitter
        
        // 3 秒后自动停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.stopConfetti()
        }
    }
    
    private func makeConfettiImage(color: UIColor) -> CGImage {
        let size = kaka_IsMacOS() ? CGSizeMake(8, 12) : CGSize(width: 4, height: 6)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()!.cgImage!
    }
    
    private func stopConfetti() {
        confettiLayer?.birthRate = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.confettiLayer?.removeFromSuperlayer()
            self.confettiLayer = nil
        }
    }
    
}

class BatchEditSuccessView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        self.addSubview(iconView)
        self.addSubview(spentTimeLabel)
        self.addSubview(pointView)
        self.addSubview(missingLabel)
        self.addSubview(completeLabel)
        self.addSubview(middleView)
        self.addSubview(warningLabel)
    }
    
    private func setupAutoLayout() {
        iconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(kaka_IsMacOS() ? 60.ckValue() : 25.ckValue())
            make.size.equalTo(kaka_IsMacOS() ? 200 : 150.ckValue())
        }
        
        spentTimeLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(iconView.snp.bottom).offset(15.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        pointView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(spentTimeLabel.snp.bottom).offset(15.ckValue())
            make.size.equalTo(pointView.size)
        }
        
        missingLabel.snp.makeConstraints { make in
            make.centerY.equalTo(pointView)
            make.leading.equalTo(pointView.snp.trailing).offset(13.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        completeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(pointView)
            make.trailing.equalTo(pointView.snp.leading).offset(-13.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        middleView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(completeLabel.snp.bottom)
            make.bottom.equalToSuperview()
        }
        
        warningLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(middleView)
            make.leading.equalTo(kaka_IsMacOS() ? 50 : 20.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
    }
    
    private func setupCusBuness() {
        self.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
    }
    
    // MARK:  GET && SET
    
    var isShowPremium: Bool {
        get {
            if UserInfoManager.shared.isVIP() {
                let isFreeTrail = UserInfoManager.shared.isFreeTrail
                return isFreeTrail ? true : false
            }else{
                return false
            }
        }
    }
        
    
    func updateComplete(time: TimeInterval, totalCount: Int, missingTagCount: Int, isGuideScore: Bool) {
        let spendTime = time.toLocalizedDurationString()
        let fullTagCount = totalCount - missingTagCount
        let completeStr = "Complete Tags".localStr() + ": " + "\(fullTagCount)"
        let missStr = "Missing Tags".localStr() + ": " + "\(missingTagCount)"
        
        self.spentTimeLabel.text = spendTime
        self.completeLabel.text = completeStr
        self.missingLabel.text = missStr
        
        if missingTagCount > 2 {
            var message = ""
            
            if self.isShowPremium {
                message = "Your free trial is almost over! Enjoying our auto-tagging algorithm? Upgrade to Lifetime Premium with a one-time purchase for permanent access.".localStr()
            }else{
                message = String(format: "%d files embedded permanently! %d files have partially mismatched tags. Please edit manually.".localStr(), fullTagCount, missingTagCount)
            }
            
            self.warningLabel.text = message
            
            if isGuideScore {
                self.perform(#selector(self.guideFiveStarRating), with: nil, afterDelay: 2.0)
            }
        } else {
            self.warningLabel.text = String(format: "Awesome! %d tracks fully updated. Enjoying the app? Leave us a review on the App Store!".localStr(), fullTagCount)
            // 百分之百全成功，用户处于极度兴奋状态，2秒后直接安排评分
            AppLocalManager.shared.isGuideFiveStar = false
            self.perform(#selector(self.guideFiveStarRating), with: nil, afterDelay: 2.0)
        }
        
    }
    
    /// 弹出好评
    @objc func guideFiveStarRating() {
        #if !DEBUG
        if AppLocalManager.shared.isGuideFiveStar {
            return
        }
        
        AppLocalManager.shared.isGuideFiveStar = true
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            AppStore.requestReview(in: windowScene)
        } else {
            SKStoreReviewController.requestReview(in: windowScene)
        }
        #endif
    }
    
    // MARK:  懒加载
    lazy var iconView: UIImageView = {
        let image = Reasource.systemNamed("checkmark.circle.fill", color: .systemBlue)
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var spentTimeLabel: UILabel = {
        let view = UILabel()
        view.textColor = .label
        view.textAlignment = .center
        view.font = UIFontNumber(20.ckValue())
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var pointView: UIView = {
        let size = 7.ckValue()
        let view = UIView(frame: CGRectMake(0, 0, size, size))
        view.backgroundColor = .secondaryLabel
        view.layer.masksToBounds = true
        view.layer.cornerRadius = size / 2
        return view
    }()
    
    lazy var completeLabel: UILabel = {
        let view = UILabel()
        view.textColor = pointView.backgroundColor
        view.textAlignment = .center
        view.font = UIFontBold(16.ckValue())
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var missingLabel: UILabel = {
        let view = UILabel()
        view.textColor = pointView.backgroundColor
        view.textAlignment = completeLabel.textAlignment
        view.font = completeLabel.font
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var middleView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var warningLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = UIFontLight(17.ckValue())
        view.textColor = .systemRed
        view.textAlignment = .center
        return view
    }()
    
}
