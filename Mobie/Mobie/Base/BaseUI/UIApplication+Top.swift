//
//  UIApplication+Top.swift
// Wake Music
//
//  Created by Kaka Inc. on 2023/12/2.
//

import KakaUIKit
import KakaFoundation


extension UIViewController {
    public func isPresent() -> Bool {
        let isPresent = (self.navigationController?.viewControllers.count ?? 1) == 1
        return isPresent
    }
  
    /// 2个alertView的回调提示
    public func showTwoAlert(title: String, message: String, confirm: String = "Confirm".localStr(), cancle: String = "Cancel".localStr(), style: UIAlertController.Style = .alert, complete: @escaping () -> Void) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: style)
        let action1 = UIAlertAction(title: confirm, style: .destructive) { (sender) in
            complete()
        }
        let action2 = UIAlertAction(title: cancle, style: .cancel) { (sender) in
            
        }
        
        alertController.addAction(action1)
        alertController.addAction(action2)
        
        action1.setValue(UIColor.systemRed, forKey: "_titleTextColor")
        action2.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    public func showOneAlert(title: String, message: String, confirm: String = "Confirm".localStr(), complete: (() -> Void)? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: confirm, style: .default) { (sender) in
            complete?()
        }
        
        action.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        alertController.addAction(action)
        self.present(alertController, animated: true, completion: nil)
    }
    
  
}
