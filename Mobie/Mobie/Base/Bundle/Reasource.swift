//
//  Reasource.swift
//  Kaka
//
//  Created by Kaka Inc.on 2021/12/19.
//

import KakaFoundation
import AppGroupKit

/// 资源管理器
public class Reasource {
  
    /// 根据图片名获取图片
    public static func named(_ name: String, color: UIColor? = nil) -> UIImage {
        let bundle = self.imagePath()
        
        guard let filePath = bundle.path(forResource: "Images/" + name + "@3x.png", ofType: nil), let image = UIImage(contentsOfFile: filePath) else {
            return KakaImage.createImage(color: .random(), size: CGSize(width: 1, height: 1))!
        }
      
        guard let color = color else { return image }
        
        return image.withTintColor(color)
    }
    
    // 获取文件链接
    public static func mediaUrl(_ name: String) -> String {
      let bundle = self.mediaPath()

      guard let filePath = bundle.path(forResource: "Media/" + name, ofType: nil) else {
          return ""
      }

      return filePath
    }
    
    private static func imagePath() -> Bundle {
        let bundlePath = Bundle.main.path(forResource: "Reasource", ofType: "bundle")!
        return Bundle(path: bundlePath)!
    }
  
    private static func mediaPath() -> Bundle {
        let bundlePath = Bundle.main.path(forResource: "Reasource", ofType: "bundle")!
        return Bundle(path: bundlePath)!
    }
  
}

// MARK:  获取系统的图标 
extension Reasource {
    
    // 获取系统图标
    public static func systemNamed(_ name: String, color: UIColor = appMainColor, config: UIImage.SymbolConfiguration? = nil) -> UIImage {
        
        let image = UIImage(systemName: name, withConfiguration: config)
                
        return image?.withRenderingMode(.alwaysOriginal).withTintColor(color) ?? UIImage()
    }
    
}

extension Reasource {
    /// 获取SVG文件链接，不需要后缀
    public static func svgFileUrl(_ name: String) -> String {
      let bundle = self.mediaPath()

      guard let filePath = bundle.path(forResource: "Files/" + name, ofType: "svg") else {
          return ""
      }

      return filePath
    }
    
    /// 获取文件全路径，需要后缀
    public static func fullFilePath(_ name: String) -> String {
      let bundle = self.mediaPath()

      guard let filePath = bundle.path(forResource: "Files/" + name, ofType: nil) else {
          return ""
      }

      return filePath
    }
}
