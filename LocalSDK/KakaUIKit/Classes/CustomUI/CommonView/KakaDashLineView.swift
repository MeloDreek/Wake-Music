//
//  KakaDashLineView.swift
//  KakaUIKit
//
//  Created by Kaka Inc. on 2021/2/20.
//

import KakaFoundation

// MARK: 🍌🚗🍌 横向虚线 🍌🚗🍌
public class KakaHorizontalDashxianView : KakaView {
  /// 绘制横向虚线
  /// - Parameters:
  ///   - lineColor: 虚线颜色
  ///   - lineLength: 虚线宽度
  ///   - lineSpacing: 虚线间距
  ///   - lineHeight: 虚线高度
  ///   - frame: 坐标
    public init(lineColor: KakaColor, lineLength:CGFloat, lineSpacing: CGFloat, lineHeight: CGFloat? = nil) {
    self.lineColor = lineColor
    self.lineHeight = lineHeight ?? 1.ckValue()
    self.lineLength = lineLength
    self.lineSpacing = lineSpacing
    super.init(frame: .zero)
    self.backgroundColor = .clear
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func draw(_ rect: CGRect) {
    super.draw(rect)
    //获取绘图用的图形上下文
    let context = UIGraphicsGetCurrentContext()
    context?.setLineCap(.square)
    let lineH = self.lineHeight
    context?.setLineWidth(lineH)
    let lengths = [self.lineLength, self.lineSpacing]
    context?.setLineDash(phase: 0, lengths: lengths)
    
    // 设置线的颜色
    context?.setStrokeColor(self.lineColor.cgColor)
    //画线的起始点位置
    let y = self.bounds.height / 2
    context?.move(to: CGPoint(x: 0, y: y))
    //画线的终点位置
    context?.addLine(to: CGPoint(x: self.bounds.width, y: y))
    
    //把线在界面上绘制出来
    context?.strokePath()
  }
  
  // MARK: 🍌🚗🍌 GET && SET 🍌🚗🍌
  /// 点颜色
  public var lineColor: KakaColor = KakaColor.black {
    didSet {
      self.layoutIfNeeded()
    }
  }
  
  /// 点高
  public var lineHeight: CGFloat = 1 {
    didSet {
      self.layoutIfNeeded()
    }
  }
  
  /// 点长
  public var lineLength: CGFloat = 1 {
    didSet {
      self.layoutIfNeeded()
    }
  }
  
  /// 设置点间距
  public var lineSpacing: CGFloat = 1 {
    didSet {
      self.layoutIfNeeded()
    }
  }
  
}


// MARK: 🍌🚗🍌 竖直虚线 🍌🚗🍌
public class KakaVerticalDashxianView: UIView {
  
  public override func draw(_ rect: CGRect) {
    super.draw(rect)
    //获取绘图用的图形上下文
    let context = UIGraphicsGetCurrentContext()
    context?.setLineCap(.square)
    let lineH = self.lineLength
    context?.setLineWidth(lineH)
    let lengths: [CGFloat] = [self.lineHeight, self.lineSpacing]
    context?.setLineDash(phase: 0, lengths: lengths)
    
    // 设置线的颜色
    context?.setStrokeColor(self.lineColor.cgColor)
    //画线的起始点位置
    context?.move(to: CGPoint(x: 0, y: 0))
    //画线的终点位置
    context?.addLine(to: CGPoint(x: self.bounds.width, y: self.bounds.height))
    
    //把线在界面上绘制出来
    context?.strokePath()
  }
  
  // MARK: 🍌🚗🍌 GET && SET 🍌🚗🍌
  
  /// 点颜色
  public var lineColor: KakaColor = KakaColor.black {
    didSet {
      self.layoutIfNeeded()
    }
  }
  
  /// 点高
  public var lineHeight: CGFloat = 1 {
    didSet {
      self.layoutIfNeeded()
    }
  }
  
  /// 点长
  public var lineLength: CGFloat = 1 {
    didSet {
      self.layoutIfNeeded()
    }
  }
  
  /// 设置点间距
  public var lineSpacing: CGFloat = 1 {
    didSet {
      self.layoutIfNeeded()
    }
  }
  
}
