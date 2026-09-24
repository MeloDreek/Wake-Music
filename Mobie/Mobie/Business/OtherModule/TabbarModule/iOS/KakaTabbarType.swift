//
//  KakaTabbarType.swift
//  Wakemusic
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
            return kaka_IsMacOS() ? "All Music".localStr() : "Music".localStr()
        case .collection:
            return "Library".localStr()
        case .connect:
            return "Connect".localStr()
        case .profile:
            return "Profile".localStr()
        }
    }
    
    func normalImage() -> UIImage? {
        switch self {
        case .musics:
            return UIImage(systemName: "music.note.house")
        case .collection:
            return UIImage(systemName: "rectangle.stack")
        case .connect:
            return UIImage(systemName: "externaldrive.badge.wifi")
        case .profile:
            return UIImage(systemName: "person.crop.circle")
        }
    }
    
    func selectImage() -> UIImage? {
        switch self {
        case .musics:
            return Reasource.systemNamed("music.note.house.fill")
        case .collection:
            return Reasource.systemNamed("rectangle.stack.fill")
        case .connect:
            return Reasource.systemNamed("externaldrive.fill.badge.wifi")
        case .profile:
            return Reasource.systemNamed("person.crop.circle.fill")
        }
    }
    
}

