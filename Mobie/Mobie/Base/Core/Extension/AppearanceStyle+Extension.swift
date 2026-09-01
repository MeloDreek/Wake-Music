//
//  AppearanceStyle+Extension.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2024/3/8.
//

import KakaUIKit
import AppGroupKit

extension AppearanceStyle {
    func formatStr() -> String {
        switch self {
        case .auto:
            return "Auto".localStr()
        case .light:
            return "Light".localStr()
        case .dark:
            return "Dark".localStr()
        }
    }
    
    func statusBarStyle() -> UIStatusBarStyle {
        switch self {
        case .auto:
            return .default
        case .light:
            return .darkContent
        case .dark:
            return .lightContent
        }
    }
    
    func iconImage() -> UIImage? {
        switch self {
        case .auto:
            if #available(iOS 16.0, *) {
                return UIImage(systemName: "moonphase.last.quarter")
            }else{
                return UIImage(systemName: "moon.circle.fill")
            }
        case .light:
            return UIImage(systemName: "sun.max.fill")
        case .dark:
            return UIImage(systemName: "moon.stars.fill")
        }
    }
    
    func userInterfaceStyle() -> UIUserInterfaceStyle {
        switch self {
        case .auto:
            return .unspecified
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
