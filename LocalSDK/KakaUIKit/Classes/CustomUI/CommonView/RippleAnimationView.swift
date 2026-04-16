//
//  RippleAnimationView.swift
//  KakaUIKit
//
//  Created by 张文 on 6/9/25.
//

import UIKit

public class RippleAnimationView: UIView {
    
    private let replicatorLayer = CAReplicatorLayer()
    private let rippleLayer = CALayer()
    private var animationGroup: CAAnimationGroup?
    
    public var rippleColor: UIColor = .orange {
        didSet {
            rippleLayer.backgroundColor = rippleColor.cgColor
        }
    }
    
    /// 动画持续时间（默认 5 秒）
    public var duration: CFTimeInterval = 5
    
    /// 波纹圆的大小
    public var rippleSize: CGFloat = 100
    
    /// 实例数量
    public var instanceCount: Int = 6
    
    /// 判断是否正在动画
    public private(set) var isAnimating: Bool = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.rippleSize = frame.height / 3
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        // 设置复制层参数
        replicatorLayer.instanceCount = instanceCount
        replicatorLayer.instanceDelay = duration * 0.3
        self.layer.addSublayer(replicatorLayer)
        
        // 设置圆形图层参数
        rippleLayer.bounds = CGRect(x: 0, y: 0, width: rippleSize, height: rippleSize)
        rippleLayer.cornerRadius = rippleSize / 2
        rippleLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        rippleLayer.backgroundColor = rippleColor.cgColor
        rippleLayer.transform = CATransform3DMakeScale(0, 0, 1)
        
        replicatorLayer.addSublayer(rippleLayer)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        replicatorLayer.frame = bounds
        rippleLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    public func startAnimation() {
        guard !isAnimating else { return } // 如果已经在动画中，则返回

        stopAnimation() // 确保先停止任何现有动画

        let scale = CABasicAnimation(keyPath: "transform.scale.xy")
        scale.fromValue = 0.1
        scale.toValue = 4
        scale.duration = duration

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1, 0.45, 0]
        opacity.keyTimes = [0, 0.45, 1]
        opacity.duration = duration

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = duration
        group.repeatCount = .infinity
        
        rippleLayer.add(group, forKey: "ripple")
        self.animationGroup = group
        
        isAnimating = true // 设置为正在动画状态
    }
    
    public func stopAnimation() {
        rippleLayer.removeAnimation(forKey: "ripple")
        isAnimating = false // 设置为未动画状态
    }
}
