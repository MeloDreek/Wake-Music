//
//  KakaAlertView.swift
//  KakaUIKit
//
//  Created by Kaka Inc. on 2020/9/9.
//

import KakaFoundation
import SnapKit

public enum SKSAlertActionStyle: Int {
  case cancel = 0
  case confirm = 1
  case close  = 2
}

/// 自定义弹窗
public class KakaAlertView: KakaView {
  
  public typealias OnSKSAlertActionCallBack = ((_ style: SKSAlertActionStyle)->Void)
  
  // MARK: 🍌🚗🍌 开始绘制 🍌🚗🍌
  public override init(frame: CGRect) {
    super.init(frame: frame)
    
    self.preInitChildViews()
    self.layoutChildViews()
    self.handleBusiness()
  }
  
  deinit {
    // print("### KakaAlertView ###")
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func preInitChildViews() {
    addSubview(bgBlurView)
    addSubview(contentView)
    addSubview(alertIconView)
    addSubview(closeButton)
    
    contentView.addSubview(titleNameLabel)
    contentView.addSubview(messageLabel)
    contentView.addSubview(cancleButton)
    contentView.addSubview(confirmButton)
  }
  
  private func layoutChildViews() {
    unowned  let wSelf = self
    bgBlurView.snp.remakeConstraints { (make) in
      make.edges.equalToSuperview()
    }
    
    closeButton.snp.remakeConstraints { (make) in
      make.top.equalTo(wSelf.contentView.snp.bottom).offset(20.ckValue())
      make.centerX.equalToSuperview()
      make.size.equalTo(30.ckValue())
    }
    
    alertIconView.snp.makeConstraints {
        $0.bottom.equalTo(wSelf.contentView.snp.top).offset(20.ckValue())
        $0.centerX.equalToSuperview()
        $0.width.equalTo(200.ckValue())
        $0.height.equalTo(alertIconView.snp.width).multipliedBy(alertIconView.image!.size.height / alertIconView.image!.size.width)
    }
    
    contentView.snp.makeConstraints {
      $0.centerX.equalToSuperview()
      $0.centerY.equalToSuperview().offset(23.ckValue())
      $0.width.equalTo(kaka_IsiPhone() ? 300.ckValue() : (kaka_IsMacOS() ? 400.ckValue() : 350.ckValue()))
      $0.height.greaterThanOrEqualTo(180.ckValue())
    }

      titleNameLabel.snp.remakeConstraints { (make) in
      make.top.equalToSuperview().offset(25.ckValue())
      make.leading.trailing.equalToSuperview().inset(30.ckValue())
      make.height.lessThanOrEqualTo((wSelf.titleNameLabel.font.lineHeight + wSelf.kTitleLineSpace) * CGFloat(wSelf.kTitleMaxLineCount))
    }
    
    messageLabel.snp.remakeConstraints { (make) in
      make.top.equalTo(wSelf.titleNameLabel.snp.bottom).offset(8.ckValue())
      make.leading.trailing.equalToSuperview().inset(30.ckValue())
      make.height.lessThanOrEqualTo((wSelf.messageLabel.font.lineHeight + wSelf.kMessageLineSpace) * CGFloat(wSelf.kMessageMaxLineCount))
    }
    
    if let cusView = customView {
      contentView.addSubview(cusView)
      cusView.snp.remakeConstraints { (make) in
          make.top.equalTo(wSelf.messageLabel.snp.bottom).offset(20.ckValue())
        make.centerX.equalToSuperview()
        make.width.equalTo(cusView.frame.size.width)
        make.height.equalTo(cusView.frame.size.height)
      }
    }
    
    let isCustomView = customView != nil
    let isTwoButton = self.cancelActionTitle?.count ?? 0 > 0
    let btnWidth = isTwoButton ? 120.ckValue() : 130.ckValue()
    let buttonSpace = (kAlertMaxWidth - btnWidth * 2) / 3
    let topView = isCustomView ? customView! : messageLabel
    
    if isTwoButton {
      // 2个按钮
      cancleButton.snp.remakeConstraints { (make) in
        make.top.equalTo(topView.snp.bottom).offset(20.ckValue())
        make.leading.equalToSuperview().offset(buttonSpace)
        make.bottom.equalTo(wSelf.contentView.snp.bottom).inset(24.ckValue())
        make.width.equalTo(btnWidth)
        make.height.equalTo(44.ckValue())
      }
      
      confirmButton.snp.remakeConstraints { (make) in
        make.leading.equalTo(wSelf.cancleButton.snp.trailing).offset(buttonSpace)
        make.centerY.equalTo(wSelf.cancleButton)
        make.width.equalTo(btnWidth)
        make.height.equalTo(44.ckValue())
      }
    }else{
      // 1个按钮
      confirmButton.snp.remakeConstraints { (make) in
        make.top.equalTo(topView.snp.bottom).offset(20.ckValue())
        make.centerX.equalToSuperview()
        make.bottom.equalTo(wSelf.contentView.snp.bottom).inset(24.ckValue())
        make.width.equalTo(btnWidth)
        make.height.equalTo(44.ckValue())
      }
    }
    
  }
  
  private func handleBusiness() {
    addGestureRecognizer(tapMaskToCloseGesture)
  }
  
  // MARK: 🍌🚗🍌 GET && SET 🍌🚗🍌
  
  /// 动画时间
  private let kAnimationDuration = 0.3
  
  /// AlertView宽度，自定义视图宽度不要超过该值
    private let kAlertMaxWidth = 300.ckValue()
  
  /// 标题文本最多行数
  private let kTitleMaxLineCount = 3
  
  /// 内容文本最多行数
  private let kMessageMaxLineCount = 20
  
  /// 标题文本行间距
  private let kTitleLineSpace = 1.ckValue()
  
  /// 内容文本行间距
  private let kMessageLineSpace = 2.ckValue()
  
  /// 点击回调
  public var clickCallBack: OnSKSAlertActionCallBack?
  
  /// 点击毛玻璃是否可以关闭窗口
  public var canTapMaskToClose: Bool = false
  
  /// 标题
  public var title: String? {
    didSet {
        titleNameLabel.attributedText = p_attributedString(title ?? "", kTitleLineSpace)
      layoutChildViews()
    }
  }
  
  /// 内容
  public var message: String? {
    didSet {
      messageLabel.attributedText = p_attributedString(message ?? "", kMessageLineSpace)
      layoutChildViews()
    }
  }
  
  /// 取消按钮
  public var cancelActionTitle: String? {
    didSet {
      cancleButton.setTitle(cancelActionTitle, for: .normal)
      layoutChildViews()
    }
  }
  
  /// 确认按钮
  public var confirmActionTitle: String? {
    didSet {
      confirmButton.setTitle(confirmActionTitle, for: .normal)
      layoutChildViews()
    }
  }
  
  /// 是否隐藏关闭按钮
  public var isShowCloseButton: Bool? {
    didSet {
      self.closeButton.isHidden = !(isShowCloseButton ?? false)
    }
  }
  
  /// 自定义区域
  public var customView: UIView? {
    didSet {
      layoutChildViews()
    }
  }
  
  // MARK: 🍌🚗🍌 懒加载 🍌🚗🍌
    
    /// 毛玻璃层
    private lazy var bgBlurView: UIView = {
      let view = UIView()
      view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
      return view
    }()
  
    /// 顶部图片
    lazy var alertIconView: UIImageView = {
        let img = KakaReasource.named("kaka_ops_404@3x.png")
        let view = UIImageView(image: img)
        view.isHidden = true
        return view
    }()
    
    /// 内容区域
    private lazy var contentView: UIView = {
      let view = UIView()
      view.backgroundColor = .white
      view.layer.masksToBounds = true
      view.layer.cornerRadius = 20.ckValue()
      return view
    }()
    
    /// 标题
    private lazy var titleNameLabel: UILabel  = {
      let view = UILabel()
      view.font = UIFont.boldSystemFont(ofSize: 16.ckValue())
      view.textColor = UIColor.hexColor("#4A4A54")
      view.numberOfLines = 0
      return view
    }()
    
    /// 内容
    private lazy var messageLabel: UILabel = {
      let view = UILabel()
      view.font = UIFont.systemFont(ofSize: 14.ckValue())
      view.textColor = UIColor.hexColor("#4A4A54")
      view.numberOfLines = 0
      return view
    }()
  
    /// 关闭按钮
    private lazy var closeButton: UIButton = {
      let view = UIButton(type: .custom)
      view.setImage(KakaReasource.named("tips_dismiss_image@3x.png"), for: .normal)
      view.addTarget(self, action: #selector(closeBtnClickEvent), for: .touchUpInside)
      view.isHidden = true
      return view
    }()
  
    /// 取消按钮
    public lazy var cancleButton: UIButton = {
      let btn = UIButton()
      btn.titleLabel?.font = UIFont.systemFont(ofSize: 14.ckValue())
      btn.setTitleColor(UIColor.hexColor("#4A4A54").withAlphaComponent(0.6), for: .normal)
        btn.setTitle("Cancel".localStr(), for: .normal)
      
      btn.layer.cornerRadius = 22.ckValue()
      btn.layer.masksToBounds = true
      btn.backgroundColor = UIColor.hexColor("#6B6B85").withAlphaComponent(0.1)
      btn.addTarget(self, action: #selector(cancleBtnClickEvent), for: .touchUpInside)
      return btn
    }()
    /// 确认按钮
    public lazy var confirmButton: UIButton = {
      let btn = UIButton()
      btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14.ckValue())
      btn.setTitleColor(.white, for: .normal)
        btn.setTitle("OK".localStr(), for: .normal)
      
      btn.layer.cornerRadius = 22.ckValue()
      btn.layer.masksToBounds = true
      btn.backgroundColor = UIColor.hexColor("#FA5B40")
      btn.addTarget(self, action: #selector(confirmBtnClickEvent), for: .touchUpInside)
      return btn
    }()
  
    /// 点击毛玻璃手势
    private lazy var tapMaskToCloseGesture: UITapGestureRecognizer = {
      let tap = UITapGestureRecognizer(target: self, action: #selector(p_tapOnMaskView(_:)))
      return tap
    }()
}

// MARK: 🍌🚗🍌 拓展一些方法 🍌🚗🍌
extension KakaAlertView {
  
  /// 出现
  /// - Parameter inView: 添加在哪
  public func show(_ inView: UIView) {
    
    inView.addSubview(self)
    self.snp.makeConstraints { (make) in
      make.edges.equalToSuperview()
    }
    
    self.alpha = 0
    UIView.animate(withDuration: kAnimationDuration, animations: { [weak self] () in
      self?.alpha = 1
    })
  }
  
  /// 消失
  private func dismiss(_ completion: (()->Void)? = nil) {
    UIView.animate(withDuration: kAnimationDuration, animations: { [weak self] () in
      self?.alpha = 0
    }) { [weak self] (finish) in
      completion?()
      self?.removeFromSuperview()
    }
  }
  
  /// 点击确定按钮
  @objc private func confirmBtnClickEvent() {
    self.dismiss { [weak self] () in
      self?.clickCallBack?(.confirm)
    }
  }
  
  /// 点击取消按钮
  @objc private func cancleBtnClickEvent() {
    self.dismiss { [weak self] () in
      self?.clickCallBack?(.cancel)
    }
  }
  
  /// 关闭按钮或者点击毛玻璃
  @objc private func closeBtnClickEvent() {
    self.dismiss { [weak self] () in
      self?.clickCallBack?(.close)
    }
  }
  
  /// 富文本
  private func p_attributedString(_ text: String, _ lineSpace: CGFloat) -> NSAttributedString {
    let attributedString = NSMutableAttributedString()
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = lineSpace
    paragraphStyle.alignment = .center
    paragraphStyle.lineBreakMode = NSLineBreakMode.byTruncatingTail
    attributedString.append(NSAttributedString(string: text, attributes: [NSAttributedString.Key.paragraphStyle: paragraphStyle]))
    return attributedString
  }
  
  /// 点击毛玻璃手势
  @objc private func p_tapOnMaskView(_ tap: UITapGestureRecognizer) {
    if !canTapMaskToClose { return }
    let point = tap.location(in: self)
    if !self.contentView.frame.contains(point) {
      self.closeBtnClickEvent()
    }
  }
  
}
