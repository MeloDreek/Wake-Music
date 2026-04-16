//
//  UIViewController.swift
//  KakaUIKit
//
//  Created by Kaka Inc. on 2024/2/23.
//

import Foundation
import UIKit

extension NSObject {

    open func currentViewController() -> UIViewController? {
                
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        var window: UIWindow?
        if #available(iOS 15.0, *) {
            window = windowScene?.keyWindow
        } else {
            window = windowScene?.windows.first
        }
        
        if window?.windowLevel != UIWindow.Level.normal {
            let windows = windowScene?.windows ?? UIApplication.shared.windows
            for  windowTemp in windows {
              if windowTemp.windowLevel == UIWindow.Level.normal {
                 window = windowTemp
                 break
               }
             }
         }
        
        let vc = window?.rootViewController
        return self.currentViewController(vc)
    }

    private func currentViewController(_ vc :UIViewController?) -> UIViewController? {
       if vc == nil {
          return nil
       }
       if let presentVC = vc?.presentedViewController {
          return currentViewController(presentVC)
       }
       else if let tabVC = vc as? UITabBarController {
          if let selectVC = tabVC.selectedViewController {
              return currentViewController(selectVC)
           }
           return nil
        }
        else if let naiVC = vc as? UINavigationController {
           return currentViewController(naiVC.visibleViewController)
        }
        else {
           return vc
        }
     }
}
