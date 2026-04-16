//
//  KakaAlertView+Action.swift
//  KakaUIKit
//
//  Created by Kaka Inc. on 2020/9/9.
//

import KakaFoundation

extension KakaAlertView {
  
  /// 弹出传统样式的窗口
  /// - Parameters:
  ///   - title: 标题
  ///   - message: 文本内容
  ///   - cancleTitle: 取消按钮文字
  ///   - confirmTitle: 确认按钮文字
  ///   - isShowCloseButton: 是否显示关闭按钮
  ///   - action: 点击回调
    public static func popupAlertView(title: String? = nil, message: String? = nil, cancleTitle: String? = nil, confirmTitle: String? = nil, action: OnSKSAlertActionCallBack? = nil, inView: UIView? = nil) -> KakaAlertView {
        
        let inView = inView ?? (appKeyWindow ?? UIView())
        
        let alertView = KakaAlertView()
        alertView.title = title
        alertView.message = message
        alertView.cancelActionTitle = cancleTitle
        alertView.confirmActionTitle = confirmTitle
        alertView.clickCallBack = action
        alertView.show(inView)
        return alertView
  }
  
  /// 弹出有自定义区域的窗口
  /// - Parameters:
  ///   - title: 标题
  ///   - customView: 自定义区域，必须有宽高
  ///   - cancleTitle: 取消按钮文字
  ///   - confirmTitle: 确认按钮文字
  ///   - action: 点击回调
    public static func popupAlertView(title: String? = nil, message: String? = nil, customView: UIView, cancleTitle: String? = nil, confirmTitle: String? = nil, action: OnSKSAlertActionCallBack? = nil, inView: UIView? = nil) -> KakaAlertView {
        
        let inView = inView ?? (appKeyWindow ?? UIView())
        
        let alertView = KakaAlertView()
        alertView.title = title
        alertView.message = message
        alertView.customView = customView
        alertView.cancelActionTitle = cancleTitle
        alertView.confirmActionTitle = confirmTitle
        alertView.clickCallBack = action
        alertView.canTapMaskToClose = false
        alertView.show(inView)
        return alertView
  }
  
}
