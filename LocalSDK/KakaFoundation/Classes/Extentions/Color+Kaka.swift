//
//  Color+Kaka.swift
//
//  Created by Kaka Inc. on 2020/5/8.
//

import Foundation

extension KakaColor {
    
    // 获取随机颜色
    public class func random() -> KakaColor {
        let r : CGFloat = CGFloat(arc4random_uniform(256))
        let g : CGFloat = CGFloat(arc4random_uniform(256))
        let b : CGFloat = CGFloat(arc4random_uniform(256))
        
        let color: KakaColor = KakaColor(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: 1)
        
        return color
    }
    
    /// 获取RGB色
    public class func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ alpha: CGFloat = 1) -> KakaColor {
        let color: KakaColor = KakaColor(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: alpha)
        return color
    }
    
}

extension KakaColor {
    public var hex16String: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "#000000" }
        let r = Int(red * 255), g = Int(green * 255), b = Int(blue * 255), a = Int(alpha * 255)
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }

    /// 通过十六进制字符串生成颜色
    public class func hexColor(_ hexString: String, _ alpha: CGFloat = 1.0) -> KakaColor {
        var hexSanitized = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return .random() }

        let r, g, b: CGFloat

        switch hexSanitized.count {
        case 8:
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255
            let parsedAlpha = CGFloat(rgb & 0x000000FF) / 255
            return KakaColor(red: r, green: g, blue: b, alpha: parsedAlpha)
        case 6:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255
            b = CGFloat(rgb & 0x0000FF) / 255
            return KakaColor(red: r, green: g, blue: b, alpha: alpha)
        default:
            return .random()
        }
    }
    
}
