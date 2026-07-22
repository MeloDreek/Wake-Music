//
//  AboutAppCellType.swift
//  Mobie
//
//  Created by 张文 on 5/30/25.
//

import Foundation

enum AboutAppCellType {
    
    case crossSystem
    case appStore

    case privacy
    case userMent
    
    case contactus
    case systemSet
    case cleanCache
    
    func titleStr() -> String? {
        switch self {
        case .crossSystem:
            return nil
        case .appStore:
            return "App Store"
            
        case .privacy:
            return "Privacy Policy".localStr()
        case .userMent:
            return "Terms of Service".localStr()
            
        case .contactus:
            return "Contact Us".localStr()
        case .systemSet:
            return "System Settings".localStr()
        case .cleanCache:
            return "Clear Cache".localStr()
        }
    }
    
    func descStr(_ string: String? = nil) -> String? {
        
        switch self {
        case .crossSystem:
            return nil
        case .appStore:
            return "iOS & Mac"
        
        case .privacy:
            return string
        case .userMent:
            return string
            
        case .contactus:
            return ""
        case .systemSet:
            return string
        case .cleanCache:
            return string
        }
    }
    
}
