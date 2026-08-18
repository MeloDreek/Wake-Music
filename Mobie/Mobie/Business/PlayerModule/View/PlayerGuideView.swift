//
//  PlayerGuideView.swift
//  Mobie
//
//  Created by kaka on 2026/4/30.
//

import KakaFoundation
import KakaUIKit
import SnapKit

class PlayerGuideView: UIView {
    
    private var targetFrame: CGRect = .zero
    
    // 专门用于承载黑色镂空蒙层的 Layer
    private let maskBackgroundLayer = CAShapeLayer()
    
    // 提示文案
    private let hintLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = UIFontBold(17.ckValue())
        view.textAlignment = .center
        view.numberOfLines = 0
        view.text = "Click to customize your cassette and playback background".localStr()
        var italicTransform = CGAffineTransform.identity
        italicTransform.c = -0.2 // 负值向右倾斜，正值向左倾斜
        view.transform = italicTransform
        return view
    }()
    
    // 动画手指
    lazy var fingerView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        // 确保资源名称正确
        view.animationImages = [
            UIImage(named: "finger_1")!.flippedImage(),
            UIImage(named: "finger_2")!.flippedImage()
        ]
        view.animationDuration = 0.5
        view.animationRepeatCount = 0
        return view
    }()
    
    var onClickTap: (()->Void)?

    init(frame: CGRect, targetFrame: CGRect) {
        super.init(frame: frame)
        self.targetFrame = targetFrame
        setupView()
        setupConstraints()
        fingerView.startAnimating()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        // 1. 设置蒙层背景 Layer
        maskBackgroundLayer.frame = self.bounds
        maskBackgroundLayer.fillColor = UIColor.rgb(38, 33, 33).withAlphaComponent(0.5).cgColor
        maskBackgroundLayer.fillRule = .evenOdd
        
        let fullPath = UIBezierPath(rect: self.bounds)
        let holePath = UIBezierPath(ovalIn: targetFrame)
        fullPath.append(holePath)
        maskBackgroundLayer.path = fullPath.cgPath
        
        // 注意：这里是添加到 self.layer 而不是设置 self.layer.mask
        self.layer.addSublayer(maskBackgroundLayer)
        
        // 2. 将子视图添加到 self 上，它们现在不受 maskBackgroundLayer 的裁切影响
        addSubview(hintLabel)
        addSubview(fingerView)
    }
    
    private func setupConstraints() {
        hintLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(self.snp.top).offset(targetFrame.maxY + 70.ckValue())
            make.leading.equalTo(30.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        fingerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(60.ckValue())
            make.bottom.equalTo(hintLabel.snp.top).offset(-35.ckValue())
            make.size.equalTo(60.ckValue())
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if targetFrame.contains(point) {
            dismiss()
            return false // 允许点击穿透到封面
        }
        return true
    }
    
    private func dismiss() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { _ in
            self.onClickTap?()
            self.removeFromSuperview()
        }
    }
}
