//
//  CircleProgressView.swift
//  Mobie
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import KakaUIKit

class CircleProgressView: UIView {
    // 灰色静态圆环
    var staticLayer: CAShapeLayer!
    // 进度可变圆环
    var arcLayer: CAShapeLayer!
    
    /// 进度值
    var progress: Double = 0 {
        didSet {
            self.progressLabel.text = String(format: "%.0f%%", progress * 100)
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = UIColor.clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        if staticLayer == nil {
            staticLayer = createLayer1(1, self.backgroundColor ?? UIColor.clear)
            self.layer.addSublayer(staticLayer)
        }
       
        if arcLayer != nil {
            arcLayer.removeFromSuperlayer()
        }
        arcLayer = createLayer(self.progress, appMainColor)
        self.layer.addSublayer(arcLayer)
        
        self.addSubview(self.progressLabel)
    }
    
    private func createLayer(_ progress: Double, _ color: UIColor) -> CAShapeLayer {
        let endAngle = -CGFloat.pi / 2 + (CGFloat.pi * 2) * CGFloat(progress) / 1
        let layer = CAShapeLayer()
        layer.lineWidth = 3.ckValue()
        layer.strokeColor = color.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineCap = .round
        let radius = self.bounds.width / 2
        let path = UIBezierPath.init(arcCenter: CGPoint(x: bounds.width / 2, y: bounds.height / 2), radius: radius, startAngle: -CGFloat.pi / 2, endAngle: endAngle, clockwise: true)
        
        layer.path = path.cgPath
        return layer
    }
    
    private func createLayer1(_ progress: Int, _ color: UIColor) -> CAShapeLayer {
        let endAngle = -CGFloat.pi / 2 + (CGFloat.pi * 2) * CGFloat(progress) / 1
        let layer = CAShapeLayer()
        layer.lineWidth = 1.5.ckValue()
        layer.strokeColor = color.cgColor
        layer.fillColor = color.cgColor
        let radius = self.bounds.width / 2 - layer.lineWidth
        let path = UIBezierPath.init(arcCenter: CGPoint(x: bounds.width / 2, y: bounds.height / 2), radius: radius, startAngle: -CGFloat.pi / 2, endAngle: endAngle, clockwise: true)
        layer.path = path.cgPath
        return layer
    }
    
    lazy var progressLabel: UILabel = {
        let view = UILabel(frame: self.bounds)
        view.textColor = .label
        view.font = UIFontLight(10.ckValue())
        view.textAlignment = .center
        return view
    }()

}



