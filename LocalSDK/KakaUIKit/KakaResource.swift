//
//  KakaResource.swift
//  Pods
//
//  Created by 张文 on 2023/3/18.
//

import Foundation

class Reasource {
    // 获取文件链接
    public static func svgaUrl(_ name: String) -> String {
      let bundle = self.bundlePath()

      guard let filePath = bundle.path(forResource: name, ofType: nil) else {
          return ""
      }

      return filePath
    }

    public static func bundlePath() -> Bundle {
      return Bundle.init(path:Bundle.init(for: Reasource.self).path(forResource: "KakaUIKit", ofType: "bundle")!)!
    }
}
