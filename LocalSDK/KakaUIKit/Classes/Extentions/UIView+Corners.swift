//
//  UIView+Corners.swift
//  Kaka Inc.
//
//  Created by Kaka Inc. on 2019/8/19.
//  Copyright © 2021 Kaka Inc. All rights reserved.
//

import Foundation

extension UIView {
    
    /// 切割部分圆角
    /// - Parameters:
    ///   - corners: 需要实现为圆角的角，可传入多个
    ///   - radii: 圆角半径
    public func corner(byRoundingCorners corners: UIRectCorner, radii: CGFloat) {
        let maskPath = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radii, height: radii))
        let maskLayer = CAShapeLayer()
        maskLayer.frame = self.bounds
        maskLayer.path = maskPath.cgPath
        self.layer.mask = maskLayer
    }
    
    /// 设置圆角并返回Layer
    public func cornerLayer(byRoundingCorners corners: UIRectCorner, radii: CGFloat) -> CAShapeLayer {
        let maskPath = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radii, height: radii))
        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = self.bounds
        shapeLayer.path = maskPath.cgPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        self.layer.insertSublayer(shapeLayer, at: 0)
        return shapeLayer
    }
}

extension UIView {
    /// 添加矩形虚线边框
    /// - Parameters:
    ///   - lineWidth: 虚线宽
    ///   - lineColor: 虚线颜色
    ///   - cornerRadius: 虚线圆角
    public func kaka_addDotLineLayer(lineWidth: CGFloat, lineColor: UIColor, cornerRadius: CGFloat) {
        let shapeLayer = CAShapeLayer()
        let size = self.frame.size
        let shapeRect = self.bounds
        shapeLayer.bounds = shapeRect
        shapeLayer.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        shapeLayer.cornerRadius = self.layer.cornerRadius
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = lineColor.cgColor
        shapeLayer.lineWidth = lineWidth
        shapeLayer.lineJoin = .round
        
        shapeLayer.lineDashPattern = [3,4]
        let path = UIBezierPath(roundedRect: shapeRect, cornerRadius: cornerRadius)
        shapeLayer.path = path.cgPath
        self.layer.addSublayer(shapeLayer)
        
    }
}
