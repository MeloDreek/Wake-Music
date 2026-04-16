//
//  ColorFontManager.swift
//  Mobie
//
//  Created by 张文 on 12/23/24.
//

import KakaFoundation
import KakaUIKit
import SmartCodable

public enum ThemeColorType: String, CaseIterable, SmartCaseDefaultable {
    case color0 = "AccentColor"
    case color1 = "AccentColor1"
    case color2 = "AccentColor2"
    case color3 = "AccentColor3"
    case color4 = "AccentColor4"
    case color5 = "AccentColor5"
    case color6 = "AccentColor6"
    case color7 = "AccentColor7"
    case color8 = "AccentColor8"
    case color9 = "AccentColor9"
    case color10 = "AccentColor10"
    case color11 = "AccentColor11"
    case color12 = "AccentColor12"
    case color13 = "AccentColor13"
    case color14 = "AccentColor14"
    
    public func color() -> UIColor {
        switch self {
        case .color0:
            return UIColor.accent
        case .color1:
            return UIColor.accentColor1
        case .color2:
            return UIColor.accentColor2
        case .color3:
            return UIColor.accentColor3
        case .color4:
            return UIColor.accentColor4
        case .color5:
            return UIColor.accentColor5
        case .color6:
            return UIColor.accentColor6
        case .color7:
            return UIColor.accentColor7
        case .color8:
            return UIColor.accentColor8
        case .color9:
            return UIColor.accentColor9
        case .color10:
            return UIColor.accentColor10
        case .color11:
            return UIColor.accentColor11
        case .color12:
            return UIColor.accentColor12
        case .color13:
            return UIColor.accentColor13
        case .color14:
            return UIColor.accentColor14
        }
    }
}

/// APP主色调
public var appMainColor: UIColor {
    get {
        return ColorFontManager.shared.accentTyle.color()
    }
}

public class ColorFontManager: SmartCodable {
    
    required public init() {}
    
    static public var shared = ColorFontManager.read() ?? ColorFontManager()
    
    /// 强调色
    var accentTyle = ThemeColorType.color0 {
        didSet {
            save()
        }
    }
    
    /// 如果是黑白配，则默认使用此颜色
    var defaultType = ThemeColorType.color3
    
}

extension ColorFontManager {
    private class func kaka_UserCacheDefaultkey() -> String {
        return "ColorFontManager_key"
    }
    
    private class func read() -> ColorFontManager? {
        let key = ColorFontManager.kaka_UserCacheDefaultkey()
        let sharedUD = UserDefaults.standard
        guard let json = sharedUD.string(forKey: key) else { return nil }
          
        let model = ColorFontManager.deserialize(from: json)
        return model
    }
    
    private func save() {
        let json = self.toJSONString()
        let sharedUD = UserDefaults.standard
        sharedUD.set(json, forKey: ColorFontManager.kaka_UserCacheDefaultkey())
        sharedUD.synchronize()
    }
    
    public class func reset() {
        let key = ColorFontManager.kaka_UserCacheDefaultkey()
        let sharedUD = UserDefaults.standard
        sharedUD.set(nil, forKey: key)
        sharedUD.synchronize()
        
        ColorFontManager.shared = ColorFontManager()
    }
    
}
