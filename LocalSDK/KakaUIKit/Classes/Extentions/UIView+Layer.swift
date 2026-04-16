import UIKit

extension UIView {
    // 给View添加水平渐变色
    public func drawHorizontalGradientLayer(_ colors: [CGColor]) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "HorizontalGradientLayer"
        gradientLayer.frame = self.bounds
        self.layer.insertSublayer(gradientLayer, at: 0)
//        self.layer.addSublayer(gradientLayer)
        gradientLayer.colors = colors

        gradientLayer.locations = [0, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
    }

    // 添加垂直渐变色
    public func drawVerticalGradientLayer(_ colors: [CGColor]) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "VerticalGradientLayer"
        gradientLayer.frame = self.bounds
        self.layer.insertSublayer(gradientLayer, at: 0)
//        self.layer.addSublayer(gradientLayer)
        gradientLayer.colors = colors

        gradientLayer.locations = [0, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
    }

    public func removeHorizontalGradientLayer() {
        self.layer.sublayers?.forEach({ subLayer in
            if subLayer.name == "HorizontalGradientLayer" {
                subLayer.removeFromSuperlayer()
            }
        })
    }
    
    public func removeVerticalGradientLayer() {
        self.layer.sublayers?.forEach({ subLayer in
            if subLayer.name == "VerticalGradientLayer" {
                subLayer.removeFromSuperlayer()
            }
        })
    }
    
}

