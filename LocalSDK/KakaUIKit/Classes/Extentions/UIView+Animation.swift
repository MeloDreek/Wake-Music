//
//  UIView+Anim.swift
//  Kaka Inc.
//
//  Created by Kaka Inc. on 2019/10/16.
//  Copyright © 2021 Kaka Inc. All rights reserved.
//

import Foundation

/// 摇一摇动画
extension UIView {
  /// 摇一摇
    public func kaka_playShakeAnim(_ repeatCount: Float = 2) {
    self.kaka_stopShakeAnim()
    
    let shakeAnim = CABasicAnimation(keyPath: "transform.translation.x")
    shakeAnim.fromValue = -5
    shakeAnim.toValue = 5
    shakeAnim.duration = 0.1
    shakeAnim.autoreverses = true
    shakeAnim.repeatCount = repeatCount
    self.layer.add(shakeAnim, forKey: "kaka_shake_anim")
  }
    
  /// 停止摇一摇
  public func kaka_stopShakeAnim() {
    self.layer.removeAnimation(forKey: "kaka_shake_anim")
  }
}

/// X轴位移动画
extension UIView {
  public func kaka_playMoveAnim(_ fromValue: Float, toValue: Float, duration: TimeInterval = 1.5, autoreverses: Bool = true, repeatCount: Float = MAXFLOAT) {
    self.kaka_stopMoveAnim()
    
    let shakeAnim = CABasicAnimation(keyPath: "transform.translation.x")
    shakeAnim.fromValue = fromValue
    shakeAnim.toValue = toValue
    shakeAnim.duration = duration
    shakeAnim.autoreverses = autoreverses
    shakeAnim.repeatCount = repeatCount
    self.layer.add(shakeAnim, forKey: "kaka_move_anim")
  }
  
  public func kaka_stopMoveAnim() {
    self.layer.removeAnimation(forKey: "kaka_move_anim")
  }
}

/// Y轴位移动画
extension UIView {
    public func kaka_playMoveYAnim(_ fromValue: Float, toValue: Float, duration: TimeInterval = 0.5, autoreverses: Bool = true, repeatCount: Float = MAXFLOAT, isRemovedOnCompletion: Bool = true) {
    self.kaka_stopMoveYAnim()
    
    let shakeAnim = CABasicAnimation(keyPath: "transform.translation.y")
    shakeAnim.fromValue = fromValue
    shakeAnim.toValue = toValue
    shakeAnim.duration = duration
    shakeAnim.autoreverses = autoreverses
    shakeAnim.repeatCount = repeatCount
    shakeAnim.isRemovedOnCompletion = isRemovedOnCompletion
    self.layer.add(shakeAnim, forKey: "kaka_move_y_anim")
  }
  
  public func kaka_stopMoveYAnim() {
    self.layer.removeAnimation(forKey: "kaka_move_y_anim")
  }
}

/// 位移动画
extension UIView {
  public func kaka_playPostionAnim(_ from:CGPoint, to: CGPoint, duration: TimeInterval = 1.5, autoreverses: Bool = true, repeatCount: Float = MAXFLOAT) {
    self.kaka_stopPostionAnim()
    
    let shakeAnim = CABasicAnimation(keyPath: "position")
    shakeAnim.fromValue = from
    shakeAnim.toValue = to
    shakeAnim.duration = duration
    shakeAnim.autoreverses = autoreverses
    shakeAnim.repeatCount = repeatCount
    self.layer.add(shakeAnim, forKey: "kaka_postion_anim")
  }
  
  public func kaka_stopPostionAnim() {
    self.layer.removeAnimation(forKey: "kaka_postion_anim")
  }
}

/// 呼吸灯动画
extension UIView {
  /// 添加呼吸灯动画
  public func kaka_addAlphaLight(_ time: CGFloat) {
    self.kaka_removeAlphaLight()
    
    let animation = CABasicAnimation.init(keyPath: "opacity")
    animation.fromValue = 1
    animation.toValue = 0
    animation.autoreverses = true
    animation.duration = CFTimeInterval(time)
    animation.repeatCount = 1000
    animation.isRemovedOnCompletion = false
    animation.fillMode = .forwards
    animation.timingFunction = CAMediaTimingFunction.init(name: .easeIn)
    self.layer.add(animation, forKey: "kaka_opacity")
  }
  /// 去除呼吸灯效果
  public func kaka_removeAlphaLight() {
    self.layer.removeAnimation(forKey: "kaka_opacity")
  }
}

/// 旋转动画
extension UIView {
    /// 添加360°旋转动画
    public func addTransform360Animation(repeats: Float?, duration: CFTimeInterval?) {
        let anim = CABasicAnimation(keyPath: "transform.rotation")
        anim.toValue = 2 * Double.pi
        anim.repeatCount = repeats ?? 1
        anim.duration = duration ?? 0.5
        anim.isRemovedOnCompletion = true
        self.layer.add(anim, forKey: nil)
    }
    
    /// 除移360°旋转动画
    public func removeTransform360Animation() {
        self.layer.removeAnimation(forKey: "transform.rotation")
    }
    
    /// 旋转动画
    public func kaka_addTransformAnimation(from: Any? = -Double.pi / 8.0,
                                          to: Any? = Double.pi / 8.0,
                                          repeats: Float = 1,
                                          duration: CFTimeInterval = 0.5,
                                          autoreverses: Bool = true,
                                          isRemovedOnCompletion: Bool = true) {
        let anim = CABasicAnimation(keyPath: "transform.rotation")
        anim.fromValue = from
        anim.toValue = to
        anim.repeatCount = repeats
        anim.duration = duration
        anim.autoreverses = autoreverses
        anim.isRemovedOnCompletion = isRemovedOnCompletion
        self.layer.add(anim, forKey: nil)
    }
    
    /// 除移旋转动画
    public func kaka_removeTransformAnimation() {
      self.layer.removeAnimation(forKey: "transform.rotation")
    }
}

/// 缩放动画
extension UIView {
  /// 缩放动画
  public func kaka_scaleAnimation(_ from:CGFloat, to: CGFloat, duration: TimeInterval = 1.5, autoreverses: Bool = true, repeatCount: Float = MAXFLOAT) {
      kaka_stopScaleAnim()
      
      let animation = CABasicAnimation(keyPath: "transform.scale")
      animation.fromValue = from
      animation.toValue = to
      animation.autoreverses = autoreverses
      animation.duration = duration
      animation.repeatCount = repeatCount
      animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      animation.isRemovedOnCompletion = false
      self.layer.add(animation, forKey: "kaka_scale_anim")
  }
  
  /// 停止缩放动画
  public func kaka_stopScaleAnim() {
    self.layer.removeAnimation(forKey: "kaka_scale_anim")
  }
}

/// 上下晃动动画
extension UIView {
    public func kaka_rotaYAnimation(_ rotateVal: Double = 0.1, repeats: Float? = nil, duration: CFTimeInterval? = nil) {
        let anim = CABasicAnimation(keyPath: "transform.rotation")
        anim.fromValue = 0
        anim.toValue = rotateVal * Double.pi
        anim.repeatCount = repeats ?? MAXFLOAT
        anim.duration = duration ?? 0.5
        anim.autoreverses = true
        anim.isRemovedOnCompletion = false
        self.layer.add(anim, forKey: "kaka_rota_y_animation")
    }

    public func kaka_stopRotaYAnimation() {
        self.layer.removeAnimation(forKey: "kaka_rota_y_animation")
    }
    
    // 旋转一圈
    public func rotate360Degrees(duration: TimeInterval, repeatCount: Int) {
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.toValue = CGFloat(Double.pi * 2)
        rotateAnimation.duration = duration
        rotateAnimation.isRemovedOnCompletion = true
        rotateAnimation.repeatCount = Float(repeatCount)
        self.layer.add(rotateAnimation, forKey: nil)
    }
}

//extension UIView {
//    
//    /// 添加旋转动画
//    public func addRotateAndScale(_ duration: TimeInterval) {
//        
//        // 创建旋转动画
//        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
//        rotationAnimation.toValue = NSNumber(value: Double.pi * 2) // 360 degrees
//        rotationAnimation.duration = duration
//        rotationAnimation.isCumulative = true
//        rotationAnimation.repeatCount = Float.infinity
//        
//        // 设置 fillMode 和 isRemovedOnCompletion
//        rotationAnimation.fillMode = .forwards
//        rotationAnimation.isRemovedOnCompletion = false
//        rotationAnimation.autoreverses = false
//
//        // 添加动画到图层
//        self.layer.add(rotationAnimation, forKey: "rotateAndScaleAnimation")
//    }
//    
//    /// 暂停旋转动画
//    public func pauseRotateAndScale() {
//        let pausedTime = self.layer.convertTime(CACurrentMediaTime(), from: nil)
//        self.layer.speed = 0.0
//        self.layer.timeOffset = pausedTime
//    }
//    
//    /// 恢复旋转动画
//    public func resumeRotateAndScale() {
//        // 获取暂停时间
//        let pausedTime = self.layer.timeOffset
//        self.layer.speed = 1.0
//        self.layer.timeOffset = 0.0
//        self.layer.beginTime = 0.0
//        let timeSincePause = self.layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
//        self.layer.beginTime = timeSincePause
//    }
//    
//    /// 停止动画，并重置状态
//    public func stopRotateAndScale() {
//        // 移除旋转动画
//        self.layer.removeAnimation(forKey: "rotateAndScaleAnimation")
//        
//        // 重置角度为当前状态
//        let currentTransform = self.layer.presentation()?.transform
//        self.layer.transform = currentTransform ?? CATransform3DIdentity
//    }
//    
//}

extension UIView {
    /// 开始旋转动画
    public func startRotating(_ duration: Double = 20.0) {
        if self.layer.animation(forKey: "rotationAnimation") == nil {
            let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
            rotationAnimation.fromValue = 0.0
            rotationAnimation.toValue = CGFloat.pi * 2.0
            rotationAnimation.duration = duration
            rotationAnimation.repeatCount = Float.infinity
            rotationAnimation.isRemovedOnCompletion = false
            self.layer.add(rotationAnimation, forKey: "rotationAnimation")
        }
    }
    
    /// 暂停旋转动画
    public func pauseRotating() {
        guard self.layer.animation(forKey: "rotationAnimation") != nil else { return }
        let pausedTime = self.layer.convertTime(CACurrentMediaTime(), from: nil)
        self.layer.speed = 0.0
        self.layer.timeOffset = pausedTime
    }
    
    /// 继续旋转动画
    public func resumeRotating() {
        guard self.layer.speed == 0.0 else { return } // 确保是在暂停状态下再继续
        
        let pausedTime = self.layer.timeOffset
        self.layer.speed = 1.0
        self.layer.timeOffset = 0.0
        self.layer.beginTime = 0.0
        let timeSincePause = self.layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        self.layer.beginTime = timeSincePause
    }
    
    /// 停止并重置旋转动画
    public func stopRotating() {
        self.layer.transform = CATransform3DIdentity // 重置旋转角度
    }
    
}
