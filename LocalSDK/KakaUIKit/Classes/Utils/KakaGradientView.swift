//
//  KakaGradientView.swift
//  KakaUIKit
//
//  Created by 张文 on 5/28/25.
//

import KakaFoundation

/// 一个支持实时调整渐变色、响应尺寸变化的 UIView
public class KakaGradientView: UIView {

    /// 渐变图层（类型为 `CAGradientLayer`）
    private var gradientLayer: CAGradientLayer {
        return layer as! CAGradientLayer
    }

    /// 设置渐变色数组（可随时修改）
    public var gradientColors: [CGColor] = [] {
        didSet {
            updateGradientColors()
        }
    }

    /// 渐变起点（默认左上角）
    public var startPoint: CGPoint = CGPoint(x: 0, y: 0) {
        didSet {
            gradientLayer.startPoint = startPoint
        }
    }

    /// 渐变终点（默认右下角）
    public var endPoint: CGPoint = CGPoint(x: 1, y: 1) {
        didSet {
            gradientLayer.endPoint = endPoint
        }
    }

    // MARK: - 初始化

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    private func setup() {
        updateGradientColors()
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
    }

    /// 更新颜色
    private func updateGradientColors() {
        gradientLayer.colors = gradientColors
    }

    /// 自动响应尺寸变化
    public override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}
