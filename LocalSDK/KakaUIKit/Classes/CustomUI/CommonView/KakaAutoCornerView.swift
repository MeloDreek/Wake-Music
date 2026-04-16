//
//  KakaAutoCornerView.swift
//  KakaUIKit
//
//  Created by Kaka Inc. on 2021/2/20.
//

import KakaFoundation

/// 动态改圆角
public class KakaAutoCornerView : KakaView {
  public override func layoutSubviews() {
    super.layoutSubviews()
    kaka_renderCorner()
  }
  
  private func kaka_renderCorner() {
    let info = sksCornersInfo ?? ([], 0)
    let maskPath = UIBezierPath(roundedRect: layer.bounds, byRoundingCorners: info.0, cornerRadii: CGSize(width: info.1, height: info.1))
    let shapeLayer = CAShapeLayer()
    shapeLayer.frame = layer.bounds
    shapeLayer.path = maskPath.cgPath
    layer.mask = shapeLayer
  }
  
    public var sksCornersInfo: (UIRectCorner, CGFloat)? {
        didSet {
          self.layoutIfNeeded()
        }
  }
}

public class SKSAutoCornerLabel : UILabel {
  public override func layoutSubviews() {
    super.layoutSubviews()
    kaka_renderCorner()
  }
  
  private func kaka_renderCorner() {
    let info = sksCornersInfo ?? ([], 0)
    let maskPath = UIBezierPath(roundedRect: layer.bounds, byRoundingCorners: info.0, cornerRadii: CGSize(width: info.1, height: info.1))
    let shapeLayer = CAShapeLayer()
    shapeLayer.frame = layer.bounds
    shapeLayer.path = maskPath.cgPath
    layer.mask = shapeLayer
  }
  
  var sksCornersInfo: (UIRectCorner, CGFloat)? {
    didSet {
      self.layoutIfNeeded()
    }
  }
}
