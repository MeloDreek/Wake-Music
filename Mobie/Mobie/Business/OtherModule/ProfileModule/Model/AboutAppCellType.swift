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
    case nameStory
    
    case privacy
    case userMent
    
    case systemSet
    case cleanCache
    
    func titleStr() -> String? {
        switch self {
        case .crossSystem:
            return nil
        case .appStore:
            return "App Store"
        case .nameStory:
            return "The Name Story".localStr()
            
        case .privacy:
            return "Privacy Policy".localStr()
        case .userMent:
            return "Terms of Service".localStr()
            
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
        case .nameStory:
            return "Wake Music"
        case .privacy:
            return string
        case .userMent:
            return string
        case .systemSet:
            return string
        case .cleanCache:
            return string
        }
    }
    
}
