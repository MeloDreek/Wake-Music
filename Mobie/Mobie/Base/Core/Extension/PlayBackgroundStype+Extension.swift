//
//  PlayBackgroundStype+Extension.swift
//  Mobie
//
//  Created by 张文 on 5/20/25.
//

import KakaFoundation
import AppGroupKit

extension PlayBackgroundEffect {
    
    public func titleStr() -> String {
        switch self {
        case .gaussianBlur:
            return "Gaussian Blur".localStr()
        case .coverAssetColor:
            return "Dominant Colors".localStr()
        case .translucencyMask:
            return "Customize wallpaper".localStr()
            
        case .showAlphaMask:
            return "Show Translucency Mask".localStr()
        }
    }
    
    public func descStr() -> String? {
        switch self {
        case .gaussianBlur:
            return "Frosted glass effect".localStr()
        case .coverAssetColor:
            return "Extract the dominant color tone of cover art or wallpapers".localStr()
        case .translucencyMask:
            return "DIY"
        
        case .showAlphaMask:
            return nil
        }
    }
    
}


extension PlayBackgroundModel {
    /// 背景图
    public func backgroundImage() -> UIImage? {
        switch backgroundType {
        case .defaultType:
            return nil
        case .systemType:
            let filePath = Reasource.fullFilePath(self.backgroundName ?? "")
            return UIImage(contentsOfFile: filePath)
        case .customType:
            let filePath = SandboxFileManager.shared.customPlayerbackURL().appendingPathComponent(self.backgroundName ?? "")
            return UIImage(contentsOfFile: filePath.path)
        }
    }
        
}


extension PlayBackgroundSystem {
    func systemImageName() -> String {
        switch self {
        case .style1:
            return kaka_IsMacOS() ? "player_mac_1@3x.png" : "player_ios_1@3x.png"
        case .style2:
            return kaka_IsMacOS() ? "player_mac_2@3x.png" : "player_ios_2@3x.png"
        case .style3:
            return kaka_IsMacOS() ? "player_mac_3@3x.png" : "player_ios_3@3x.png"
        case .style4:
            return kaka_IsMacOS() ? "player_mac_4@3x.png" : "player_ios_4@3x.png"
        case .style5:
            return kaka_IsMacOS() ? "player_mac_5@3x.png" : "player_ios_5@3x.png"
        case .style6:
            return kaka_IsMacOS() ? "player_mac_6@3x.png" : "player_ios_6@3x.png"
        case .style7:
            return kaka_IsMacOS() ? "player_mac_7@3x.png" : "player_ios_7@3x.png"
        case .style8:
            return kaka_IsMacOS() ? "player_mac_8@3x.png" : "player_ios_8@3x.png"
        case .style9:
            return kaka_IsMacOS() ? "player_mac_9@3x.png" : "player_ios_9@3x.png"
        case .style10:
            return kaka_IsMacOS() ? "player_mac_10@3x.png" : "player_ios_10@3x.png"
        case .style11:
            return kaka_IsMacOS() ? "player_mac_11@3x.png" : "player_ios_11@3x.png"
        case .style12:
            return kaka_IsMacOS() ? "player_mac_12@3x.png" : "player_ios_12@3x.png"
        case .style13:
            return kaka_IsMacOS() ? "player_mac_13@3x.png" : "player_ios_13@3x.png"
        case .style14:
            return kaka_IsMacOS() ? "player_mac_14@3x.png" : "player_ios_14@3x.png"
        }
    }
}

extension PlayerUIStyle {
    func titleStr() -> String? {
        switch self {
        case .defaultRect: return "Square shape".localStr()
        case .defaultCircle: return "Round shape".localStr()
        case .default8Side: return "Octagon shape".localStr()
        default: return nil
        }
    }
    
    func iconImage() -> UIImage? {
        switch self {
        case .defaultRect: return nil
        case .defaultCircle: return nil
        case .default8Side: return nil
            
        case .Vinyl1, .Vinyl2, .Vinyl3, .Vinyl4, .Vinyl5, .Vinyl6, .Vinyl7, .Vinyl8:
            return Reasource.named("vinyl_\(self.rawValue)")
        case .tape1, .tape2, .tape3, .tape4, .tape5, .tape6, .tape7, .tape8:
            return nil
        }
    }
    
    /// 背景色、底部色、中间色、顶部色、轮子色
    func sectionColors() -> (UIColor, UIColor, UIColor, UIColor, UIColor)? {
        switch self {
        case .tape1:
            return (UIColor.white, UIColor.rgb(253, 208, 124), UIColor.rgb(235, 168, 68), UIColor.rgb(237, 127, 66), UIColor.rgb(102, 97, 255))
        case .tape2:
            return (UIColor.white, UIColor.rgb(143, 98, 223), UIColor.rgb(230, 82, 130), UIColor.rgb(253, 155, 202), UIColor.rgb(253, 153, 156))
        case .tape3:
            return (UIColor.white, UIColor.rgb(252, 33, 37), UIColor.rgb(119, 98, 77), UIColor.rgb(19, 35, 27), UIColor.rgb(59, 38, 45))
        case .tape4:
            return (UIColor.white, UIColor.rgb(253, 117, 44), UIColor.rgb(233, 97, 24), UIColor.rgb(203, 77, 4), UIColor.rgb(24, 90, 86))
        case .tape5:
            return (UIColor.white, UIColor.rgb(123, 194, 218), UIColor.rgb(254, 183, 9), UIColor.rgb(255, 236, 103), UIColor.rgb(44, 123, 241))
        case .tape6:
            return (UIColor.white, UIColor.rgb(253, 86, 117), UIColor.rgb(128, 54, 115), UIColor.rgb(97, 73, 134), UIColor.rgb(91, 123, 171))
        case .tape7:
            return (UIColor.white, UIColor.rgb(72, 64, 179), UIColor.rgb(35, 153, 140), UIColor.rgb(228, 112, 224), UIColor.rgb(254, 172, 133))
        case .tape8:
            return (UIColor.white, UIColor.rgb(217, 22, 34), UIColor.rgb(20, 160, 236), UIColor.rgb(26, 35, 113), UIColor.rgb(0, 0, 72))
            
        default:
            return nil
        }
    }
    
}
