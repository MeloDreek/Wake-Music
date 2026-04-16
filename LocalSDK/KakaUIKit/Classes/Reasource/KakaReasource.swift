//
//  KakaReasource.swift
//  Alamofire
//
//  Created by Kaka Inc. on 2021/3/19.
//

import Foundation

/// 读取资源
public class KakaReasource {
    
    /// 读取图片IO
    /// - Parameter name: 图片全名称
    /// - Returns: 图标
    public static func named(_ name: String) -> UIImage {
        guard let filePath = self.bundlePath().path(forResource: name, ofType: nil), let image = UIImage(contentsOfFile: filePath) else {
            return UIImage()
        }
        return image
    }
    
    public static func svgaPath(_ svgaName: String) -> String {
        let bundle = self.bundlePath()
  
        guard let filePath = bundle.path(forResource: svgaName, ofType: nil) else {
            return ""
        }
  
        return filePath
    }
    
    /// Bundle
    public static func bundlePath() -> Bundle {
        let bundlePath = Bundle.main.path(forResource: "KakaUIKit", ofType: "bundle")!
        return Bundle(path: bundlePath)!
    }
    
}
