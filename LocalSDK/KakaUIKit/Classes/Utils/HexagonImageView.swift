//
//  HexagonImageView.swift
//  KakaUIKit
//
//  Created by 张文 on 5/28/25.
//

import UIKit

public enum ShapeType {
    case rect(CGFloat)
    case circle
    case octagon
}

public extension UIImageView {

    /// 根据指定形状裁剪 UIImageView
    public func applyShape(_ shape: ShapeType) {
        
        self.layoutIfNeeded()
        
        // 若 bounds 不合法，稍后再尝试
        guard bounds.width > 0 && bounds.height > 0 else {
            DispatchQueue.main.async { [weak self] in
                self?.applyShape(shape)
            }
            return
        }
        
        let path: UIBezierPath

        switch shape {
        case .rect(let radius):
            path = UIBezierPath(roundedRect: bounds, cornerRadius: radius)
        case .circle:
            path = circlePath(in: bounds)
        case .octagon:
            path = octagonPath(in: bounds)
        }

        // ✅ 关键：移除旧的 mask，强制系统刷新遮罩层
        self.layer.mask = nil
        
        let mask = CAShapeLayer()
        mask.frame = bounds
        mask.path = path.cgPath
        self.layer.mask = mask

    }

    /// 八边形路径
    private func octagonPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let width = rect.width
        let height = rect.height
        let sideLength = min(width, height)
        let center = CGPoint(x: width / 2, y: height / 2)
        let radius = sideLength / 2

        for i in 0..<8 {
            let angle = CGFloat(i) * CGFloat.pi / 4 // 45度一个角
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.close()
        return path
    }
    
    /// 圆形路径
    private func circlePath(in rect: CGRect) -> UIBezierPath {
        let diameter = min(rect.width, rect.height)
        let originX = (rect.width - diameter) / 2
        let originY = (rect.height - diameter) / 2
        let circleRect = CGRect(x: originX, y: originY, width: diameter, height: diameter)
        return UIBezierPath(ovalIn: circleRect)
    }
    
}
