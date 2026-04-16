//
//  KakaTimer.swift
//  KakaFoundation
//
//  Created by Kaka Inc. on 2020/9/10.
//

import Foundation

/// 计时器
public class KakaTimer {
  
  public typealias KakaTimerCallBack = ((KakaTimer) -> Void)
  
  private var repeatsTime: Bool = false
  private var timer: Timer?
  private var onCallBack: KakaTimerCallBack?
    
  public init() {}
  
  /// 开始计时
  /// - Parameters:
  ///   - seconds: 间隔
  ///   - repeats: 是否循环
  ///   - callSoon: 是否立马回调
  ///   - callBack: 计时回调
    public func startTimer(seconds: TimeInterval, repeats: Bool, callSoon: Bool = false, callBack: KakaTimerCallBack? = nil) {
        
        repeatsTime = repeats
        let tempSeconds = seconds < 0 ? -seconds : seconds
        if self.timer != nil {
          self.stopTimer()
        }
        self.onCallBack = callBack
        self.timer = Timer.scheduledTimer(timeInterval: tempSeconds, target: self, selector: #selector(timeReapets), userInfo: nil, repeats: repeats)
    
        if callSoon {
            self.timeReapets()
        }
  }
  
  /// 计时回调
  @objc private func timeReapets() {
    if let callBack = self.onCallBack {
      callBack(self)
    }
  }
  
  /// 停止计时
  public func stopTimer() {
    if let time = self.timer {
      time.invalidate()
    }
  }
  
  deinit {
    // print("### KakaTimer已销毁 ###")
    self.stopTimer()
  }
}
