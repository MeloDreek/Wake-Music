//
//  KakaTabbarType.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/6/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

enum KakaTabbarType: Int {
    case musics = 0
    case collection = 1
    case connect = 2
    case profile = 3
    
    func formatStr() -> String {
        switch self {
        case .musics:
            return kaka_IsMacOS() ? "All Music".localStr() : "Offline".localStr()
        case .collection:
            return "Library".localStr()
        case .connect:
            return "Connect".localStr()
        case .profile:
            return kaka_IsMacOS() ? "Preferences".localStr() : "Profile".localStr()
        }
    }
    
    func normalImage() -> UIImage? {
        switch self {
        case .musics:
            return UIImage(systemName: "shippingbox")
        case .collection:
            return UIImage(systemName: "rectangle.stack")
        case .connect:
            return UIImage(systemName: "externaldrive.badge.wifi")
        case .profile:
            return UIImage(systemName: kaka_IsMacOS() ? "slider.vertical.3" : "person.crop.circle")
        }
    }
    
    func selectImage() -> UIImage? {
        switch self {
        case .musics:
//            return UIImage(systemName: "shippingbox.fill")
            return Reasource.systemNamed("shippingbox.fill")
        case .collection:
//            return UIImage(systemName: "rectangle.stack.fill")
            return Reasource.systemNamed("rectangle.stack.fill")
        case .connect:
//            return UIImage(systemName: "externaldrive.fill.badge.wifi")
            return Reasource.systemNamed("externaldrive.fill.badge.wifi")
        case .profile:
//            return UIImage(systemName: kaka_IsMacOS() ? "slider.vertical.3" : "person.crop.circle.fill")
            return Reasource.systemNamed(kaka_IsMacOS() ? "slider.vertical.3" : "person.crop.circle.fill")
        }
    }
    
}

