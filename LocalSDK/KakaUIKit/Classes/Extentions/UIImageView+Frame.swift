//
//  UIImageView+FrameAnim.swift
//  Kaka Inc.
//
//  Created by Kaka Inc. on 2019/10/16.
//  Copyright © 2021 Kaka Inc. All rights reserved.
//

import Foundation

extension UIImageView {
    /// 开始帧动画
  public func kaka_playAnimation(_ imgs:[UIImage] = [UIImage](), duration: TimeInterval = 1.0, repeatCount: Int = 0) {
    if self.isAnimating {
      self.stopAnimating()
    }
    
    self.animationImages = imgs;
    self.animationDuration = duration;
    self.animationRepeatCount = repeatCount;
    self.startAnimating()
  }
    
  /// 停止帧动画
  public func kaka_stopAnimation() {
    self.animationImages = nil
    self.stopAnimating()
  }
}
