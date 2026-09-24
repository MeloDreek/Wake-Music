//
//  DownloadPoolView.swift
//  Mobie
//
//  Created by 张文 on 5/13/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit


/// 悬浮的下载池按钮
class DownloadPoolView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: fullSize.width, height: fullSize.height))
        self.beginPoint = center
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        self.addSubview(shadowView)
        shadowView.addSubview(contentView)
        contentView.addSubview(coverImgView)
        contentView.addSubview(countLabel)
    }
    
    private func setupAutoLayout() {

        coverImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalToSuperview().multipliedBy(0.8)
        }

        countLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.equalTo(countLabel.size)
            make.top.equalToSuperview().offset(5.ckValue())
        }
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(clickTap))
        self.addGestureRecognizer(clickTap)
    }
    
    @objc func clickTap() {
        self.onClickBlock?()
    }
    
    @objc func appModeStyleChanged(_ noti: Notification) {
        guard let newColor = noti.object as? UIColor else { return }

        self.tintColor = newColor
    }
    
    func updateTasks(_ tasks: [MusicItemModel]) {
        let text = "\(tasks.count)"
        let font = self.countLabel.font!
        self.countLabel.text = text
        
        let width = text.width(font) + 12.ckValue()
        let height = font.lineHeight + 6.ckValue()
        self.countLabel.size = CGSizeMake(width, height)
        
        self.contentView.layoutIfNeeded()
    }
    
    // MARK:  GET && SET
    
    var onClickBlock: (()->Void)?
    
    /// 悬浮view 大小
    private(set) var fullSize = CGSize(width: 80.ckValue(), height: 80.ckValue())
    
    /// 拖动开始时 位置
    private var beginPoint: CGPoint = CGPoint.zero
    
    /// 左边最小 margin
    private let leftMinMargin: CGFloat = 5.ckValue()
    
    /// 右边最小 magin
    private let rightMinMargin: CGFloat = 5.ckValue()

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        correctLocation(animated: false)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        correctLocation(animated: false)
    }
    
    
    // MARK:  懒加载
    
    lazy var shadowView: UIView = {
        let view = UIView(frame: self.bounds)
        view.backgroundColor = .clear // 保持背景透明
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.5).cgColor // 阴影颜色
        view.layer.shadowOpacity = 0.5 // 阴影透明度
        view.layer.shadowOffset = CGSize.zero // 阴影偏移
        view.layer.shadowRadius = 10.ckValue()
        return view
    }()
    
    lazy var contentView: UIView = {
        let view = UIView(frame: self.bounds)
        view.isUserInteractionEnabled = true
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = self.fullSize.width / 2
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var coverImgView: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("arrow.down.circle.fill", color: .white))
        view.isUserInteractionEnabled = true
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var countLabel: UILabel = {
        let text = "\(99)"
        let font = UIFontBold(14.ckValue())
        
        let width = text.width(font) + 12.ckValue()
        let height = font.lineHeight + 6.ckValue()
        
        let view = UILabel(frame: CGRectMake(0, 24.ckValue(), width, height))
        view.text = text
        view.font = font
        view.textColor = .white
        view.backgroundColor = .red
        view.textAlignment = .center
        view.layer.masksToBounds = true
        view.layer.cornerRadius = height / 2
        return view
    }()
}


extension DownloadPoolView {
    /// 点击开始
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else {return}
        
        let curPoint = touch.location(in: self)
        let prePoint = touch.previousLocation(in: self)
        
        let offsetX = curPoint.x - prePoint.x
        let offsetY = curPoint.y - prePoint.y
        
        let centerX = offsetX + self.center.x
        let centerY = offsetY + self.center.y
        /// 记录开始位置
        beginPoint = CGPoint(x: centerX, y: centerY)
        
    }
    /// 拖动
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else {return}
        
        let curPoint = touch.location(in: self)
        let prePoint = touch.previousLocation(in: self)
        
        let offsetX = curPoint.x - prePoint.x
        let offsetY = curPoint.y - prePoint.y
        
        let centerX = offsetX + self.center.x
        let centerY = offsetY + self.center.y
        /// 拖动
        self.center = CGPoint(x: centerX, y: centerY)
    
    }
    /// 点击结束
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first else {return}
        let curPoint = touch.location(in: self)
        let prePoint = touch.previousLocation(in: self)
        
        let offsetX = curPoint.x - prePoint.x
        let offsetY = curPoint.y - prePoint.y
        
        let centerX = offsetX + self.center.x
        let centerY = offsetY + self.center.y
        
        let endPoint = CGPoint(x: centerX, y: centerY)
        /// 区分点击和拖动
        if endPoint == beginPoint { /// 点击
            // TODO: 处理点击事件
        } else { /// 拖动
            correctLocation()
        }
    }
    /// 修正位置
    func correctLocation(animated: Bool = true) {
        guard let container = superview, !container.bounds.isEmpty else { return }
        let safeBounds = container.bounds.inset(by: container.safeAreaInsets)
        let minX = safeBounds.minX + leftMinMargin + bounds.width / 2
        let maxX = safeBounds.maxX - rightMinMargin - bounds.width / 2
        let minY = safeBounds.minY + bounds.height / 2
        let maxY = safeBounds.maxY - bounds.height / 2
        let endCenter = CGPoint(
            x: maxX >= minX ? min(max(center.x, minX), maxX) : safeBounds.midX,
            y: maxY >= minY ? min(max(center.y, minY), maxY) : safeBounds.midY
        )
        if animated {
            UIView.animate(withDuration: 0.25) { self.center = endCenter }
        } else {
            center = endCenter
        }
    }
}
