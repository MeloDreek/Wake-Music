//
//  UIApplication+Top.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2023/12/2.
//
import KakaUIKit
import KakaFoundation
import AppGroupKit
import Toast

/// 定义具体的按钮行为配置
public struct AlertActionConfig {
    let title: String
    let style: UIAlertAction.Style
    let actionType: AlertActionType
}

/// 用来区分回调的标识
public enum AlertActionType {
    case first
    case second
}

extension UIViewController {
    /// Keep 115 DSD files browsable; enqueue only after the user's confirmation.
    func show115StreamingDownloadAlert(for model: MusicItemModel) {
        let alert = UIAlertController(
            title: "Reminder".localStr(),
            message: "115 Drive does not support streaming DSF or DFF files. Download them to your device to play them.".localStr(),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel".localStr(), style: .cancel))
        alert.addAction(UIAlertAction(title: "Download".localStr(), style: .default) { [weak self] _ in
            DownloadManager.shared.addMusicModel([model])
            self?.view.makeToast("Added to Downloads".localStr())
        })
        present(alert, animated: true)
    }
    
    
    public func isPresent() -> Bool {
        let isPresent = (self.navigationController?.viewControllers.count ?? 1) == 1
        return isPresent
    }
    
    /// 1个alertView的回调提示
    public func showOneAlert(title: String = "Reminder".localStr(), message: String, confirm: String = "Confirm".localStr(), complete: (() -> Void)? = nil) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: confirm, style: .default) { (sender) in
            complete?()
        }
        
        alertVC.addAction(action)
        self.present(alertVC, animated: true, completion: nil)
    }
    
    /// 2个alertView的回调提示
    public func showTwoAlert(title: String = "Reminder".localStr(), message: String, confirm: String = "Confirm".localStr(), cancle: String = "Cancel".localStr(), style: UIAlertController.Style = .alert, complete: @escaping () -> Void) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: style)
        let action1 = UIAlertAction(title: confirm, style: .destructive) { (sender) in
            complete()
        }
        let action2 = UIAlertAction(title: cancle, style: .cancel)
        
        alertVC.addAction(action1)
        alertVC.addAction(action2)
        
        self.present(alertVC, animated: true, completion: nil)
    }
    
    /// 3个alertView的回调提示
    public func showThreeAlert(
        title: String = "Reminder".localStr(),
        message: String,
        btn1: AlertActionConfig,
        btn2: AlertActionConfig,
        confirmHandler: @escaping (AlertActionType) -> Void
    ) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // 创建第一个按钮
        let action1 = UIAlertAction(title: btn1.title, style: btn1.style) { _ in
            confirmHandler(btn1.actionType)
        }
        
        // 创建第二个按钮
        let action2 = UIAlertAction(title: btn2.title, style: btn2.style) { _ in
            confirmHandler(btn2.actionType)
        }
        
        // 固定的取消按钮
        let cancelAction = UIAlertAction(title: "Cancel".localStr(), style: .cancel)
        
        alertController.addAction(action1)
        alertController.addAction(action2)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
}
