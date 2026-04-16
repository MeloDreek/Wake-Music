//
//  String+Kaka.swift
//  Kaka Inc.
//
//  Created by Kaka Inc. on 2019/12/24.
//  Copyright © 2021 Kaka Inc. All rights reserved.
//

import CommonCrypto

extension String {
    
    /// 判断字符串是否都是字母
    public func isAllAlpha() -> Bool {
      let reg = "^[a-zA-Z]+$"
      let pre = NSPredicate(format: "SELF MATCHES %@", reg)
      return pre.evaluate(with: self)
    }
      
    /// 是否为URL
    public func isWebURL() -> Bool {
        guard let urlComponts = URLComponents(string: self) else {
            return false
        }
        
        guard let scheme = urlComponts.scheme, let host = urlComponts.host else { return false }
        
        return true
    }
      
    /// 是不是手机号码
    public func isPhoneNum() -> Bool {
        let match: String = "(^[1][123456789][0-9]{9}$)"
        let predicate: NSPredicate = NSPredicate(format: "SELF MATCHES %@", match)
        return predicate.evaluate(with: self)
    }
      
    /// 是不是阿拉伯数字
      public func isArabNumber(_ count: Int) -> Bool {
        let match: String = "(^[0123456789]{\(count)}$)"
        let predicate: NSPredicate = NSPredicate(format: "SELF MATCHES %@", match)
        return predicate.evaluate(with: self)
    }
      
    /// 手机号码扣****
    public func replacePhone() -> String {
      if !self.isPhoneNum() {
          return self
      }
      let start = self.index(self.startIndex, offsetBy: 3)
      let end = self.index(self.startIndex, offsetBy: 7)
      let range = Range(uncheckedBounds: (lower: start, upper: end))
      return self.replacingCharacters(in: range, with: "****")
    }
  
    /// 是不是强密码，字母数字特殊字符
    public func isStrongPassWord() -> Bool {
        let regexPattern = "^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[#?!@$%+&*-]).{8,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", regexPattern)
        return predicate.evaluate(with: self)
    }

    /// 去除空格
    public func removeSpace() -> String {
      let newStr = self.replacingOccurrences(of: " ", with: "")
      return newStr
    }
    
    /// 去除某些字符
    public func removeChar(_ char: String) -> String {
        if char.contains(char) {
            let newStr = self.replacingOccurrences(of: char, with: "")
            return newStr
        }else{
            return self
        }
    }
    
    /// 替换某个字符
    public func replaceChar(oldChar: String, newChar: String) -> String {
        if oldChar.contains(oldChar) {
            let newStr = self.replacingOccurrences(of: oldChar, with: newChar)
            return newStr
        }else{
            return self
        }
    }
      
      /// 截取到任意位置
      public func kaka_subString(to: Int) -> String {
        let offsetByIndex = to > self.count ? self.count : to
        let index: String.Index = self.index(startIndex, offsetBy: offsetByIndex)
        return String(self[..<index])
      }
      
      /// swift字符串默认为UTF-16编码
      public func toUTF8String() -> String? {
          guard let data = self.data(using: .utf8) else {
              return nil
          }
          
          return String(data: data, encoding: .utf8)
      }
    
    /// 大写MD5值
    public func MD5String() -> String {
        let utf8 = cString(using: .utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5(utf8, CC_LONG(utf8!.count - 1), &digest)
        return digest.reduce("") {
            $0 + String(format:"%02X", $1)
        }
    }
    
    /// 小写md5值
    public func md5String() -> String {
        let utf8 = cString(using: .utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5(utf8, CC_LONG(utf8!.count - 1), &digest)
        return digest.reduce("") {
            $0 + String(format:"%02x", $1)
        }
    }
    
    ///本地化语言
    public func localStr(_ comment: String? = nil) -> String {
        let result = NSLocalizedString(self, comment: comment ?? "")
        return result.count > 0 ? result : self
    }
  
    /// 转OC字符串
    public var ocString: NSString {
        return NSString(string: self)
    }
    
    /// 转义URL
    public func formatUrlQueryAllowed() -> String {
        if let encodedString = self.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)  {
            return encodedString
        } else {
            return self
        }
    }
    
    /// SHA256值
    public func sha256() -> String {
        if let stringData = self.data(using: String.Encoding.utf8) {
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            stringData.withUnsafeBytes {
                _ = CC_SHA256($0.baseAddress, CC_LONG(stringData.count), &digest)
            }
            let hexBytes = digest.map { String(format: "%02x", $0) }
            return hexBytes.joined()
        }
        return ""
    }
    
    /// 生成二维码图片
    public func generateQRCode(_ logo: UIImage?) -> UIImage? {
        // 1. 创建二维码滤镜
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        let data = self.data(using: .utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // 高容错等级

        // 2. 生成 CIImage
        guard let outputImage = filter.outputImage else { return nil }

        // 3. 放大二维码图像
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        // 4. 转换为清晰的 UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        let qrImage = UIImage(cgImage: cgImage)

        // 5. 如果没有 logo，直接返回二维码
        guard let logo = logo else {
            return qrImage
        }

        // 6. 合成 logo 到二维码图像中心
        let size = qrImage.size
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)

        // 绘制二维码
        qrImage.draw(in: CGRect(origin: .zero, size: size))

        // 计算 logo 大小和位置（建议宽度为二维码的 1/5）
        let logoSize = CGSize(width: size.width * 0.2, height: size.height * 0.2)
        let logoOrigin = CGPoint(x: (size.width - logoSize.width) / 2,
                                 y: (size.height - logoSize.height) / 2)
        let logoRect = CGRect(origin: logoOrigin, size: logoSize)

        // 绘制 logo（可加圆角、边框等处理）
        logo.draw(in: logoRect)

        // 获取合成后的图像
        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return combinedImage
    }
    
    /// 是否为全汉语
    public func isAllChinese() -> Bool {
        // 全部为汉语：[\u4e00-\u9fa5]+，汉语+字母+数字：[a-zA-Z0-9\u4e00-\u9fa5]*
        let match: String = "[\\u4e00-\\u9fa5]+"
        let predicate: NSPredicate = NSPredicate(format: "SELF MATCHES %@", match)
        return predicate.evaluate(with: self)
    }
    
    /// 是否包含汉语
    public func isContainChinese() -> Bool {
        for i in 0..<self.count {
            let a = self.ocString.character(at: i)
            if (a > 0x4e00 && a < 0x9fff) {
                return true
            }
        }
        
        return false
    }
    
    /// 计算文字在指定字体下的宽度
    public func width(_ font: KakaFont) -> CGFloat {
        #if os(iOS)
        // iOS 计算文字宽度
        let attributes = [NSAttributedString.Key.font: font]
        let size = (self as NSString).size(withAttributes: attributes)
        return size.width
        #elseif os(macOS)
        // macOS 计算文字宽度
        let attributes = [NSAttributedString.Key.font: font]
        let size = (self as NSString).size(withAttributes: attributes)
        return size.width
        #endif
    }
    
    /// 计算文字在指定字体下的高度
    public func height(forWidth width: CGFloat, font: KakaFont) -> CGFloat {
        #if os(iOS)
        // iOS 计算文字高度
        let attributes = [NSAttributedString.Key.font: font]
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = (self as NSString).boundingRect(with: constraintRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        return ceil(boundingBox.height)
        #elseif os(macOS)
        // macOS 计算文字高度
        let attributes = [NSAttributedString.Key.font: font]
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = (self as NSString).boundingRect(with: constraintRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        return ceil(boundingBox.height)
        #endif
    }

    
}

extension NSAttributedString {
    /// 对富文本进行平均分割区域
    /// - Parameters:
    ///   - width: 分割单元的宽度
    ///   - height: ⚠️分割单元的高度，请谨慎使用font.lineHeight，如果使用了，务必自增一些高度甚至可以使用font.lineHeight * 1.5，否则CTFramesetterCreateFrame时将导致单元格面积不足以放下富文本内容分割失败
    /// - Returns: 分割后的富文本数组
    public func kaka_separatedAttLines(width: CGFloat, height: CGFloat) -> [NSAttributedString] {
        let textFrame = CGRect(x: 0, y: 0, width: width, height: height)
        let rectPath: CGPath = CGPath(rect: textFrame, transform: nil)

        var textPos = 0
        let cfAttStr: CFAttributedString = self as CFAttributedString

        let framesetter: CTFramesetter = CTFramesetterCreateWithAttributedString(cfAttStr)
        var pagingResult = [NSAttributedString]()

        while textPos < self.length {
            let frame: CTFrame = CTFramesetterCreateFrame(framesetter, CFRange(location: textPos, length: 0), rectPath, nil)
            let frameRange = CTFrameGetVisibleStringRange(frame)
            if frameRange.length == 0 {
              // 如果传入的width和height不足以放下文字内容（比如字体是20，但是传入的高度却只有18，那明显放下不嘛），CTFrameGetVisibleStringRange顾名思义这是在可视范围内分割内容，导致frameRange长度为0，分割就会失败。
              pagingResult.append(self)
              break
            }

            let range = NSRange(location: frameRange.location, length: frameRange.length)
            let subStr = self.attributedSubstring(from: range)
            pagingResult.append(subStr)
            textPos += frameRange.length
        }

        return pagingResult
    }
    
    
}

extension NSString {
    public func swiftString() -> String {
        return String(format: "%@", self)
    }
    
}
