//
//  Image+Kaka.swift
//  Kaka Inc.
//
//  Created by Kaka Inc. on 2019/12/30.
//  Copyright © 2021 Kaka Inc. All rights reserved.
//

/*
import Foundation
import UIKit

extension UIImage {
  /**
   *  重设图片大小
   */
  public func kaka_reSize(reSize:CGSize) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(reSize,false,UIScreen.main.scale)
    self.draw(in: CGRect(x: 0, y: 0, width: reSize.width, height: reSize.height))
    let newImg = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return newImg
  }
  
  /**
  *  重设图标颜色
  */
  public func kaka_newImage(_ color: UIColor) -> UIImage {
      UIGraphicsBeginImageContext(self.size)
      color.setFill()
      let bounds = CGRect.init(x: 0, y: 0, width: self.size.width, height: self.size.height)
      UIRectFill(bounds)
      self.draw(in: bounds, blendMode: CGBlendMode.destinationIn, alpha: 1.0)
      let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()
      return tintedImage!
  }
   
  /**
   *  等比率缩放
   */
  public func kaka_scaleImage(scale: CGFloat) -> UIImage? {
    let reSize = CGSize(width: self.size.width * scale, height: self.size.height * scale)
    return kaka_reSize(reSize: reSize)
  }
    
   /// 黑白照
    public func kaka_blackWhiteImage() -> UIImage {
        let tempImage = self
        guard let vData = self.pngData() else { return tempImage }
        
        let inputImage = CoreImage.CIImage(data: vData)
        let context = CIContext(options: nil)
        let filter = CIFilter(name:"CIPhotoEffectNoir")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        if let outputImage = filter?.outputImage {
          if let outImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: outImage)
          }else{
            return tempImage
          }
        }else{
            return tempImage
        }
    }
    
    // 阿拉伯语镜像
    public func flippedImage() -> UIImage {
        return PhoneSetManager.isArabicLanguage() ? self.imageFlippedForRightToLeftLayoutDirection() : self
    }
    
    public func sfHorizontallyImage() -> UIImage {
        return PhoneSetManager.isArabicLanguage() ? self.withHorizontallyFlippedOrientation() : self
    }
}

*/

import Foundation

extension KakaImage {
    
    /**
     *  重设图片大小
     */
    public func kaka_reSize(reSize: CGSize) -> KakaImage? {
        #if os(iOS)
        UIGraphicsBeginImageContextWithOptions(reSize, false, UIScreen.main.scale)
        self.draw(in: CGRect(x: 0, y: 0, width: reSize.width, height: reSize.height))
        let newImg = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImg
        #elseif os(macOS)
        let newImage = NSImage(size: reSize)
        newImage.lockFocus()
        let ctx = NSGraphicsContext.current?.cgContext
        ctx?.interpolationQuality = .high
        self.draw(in: CGRect(x: 0, y: 0, width: reSize.width, height: reSize.height), from: NSZeroRect, operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
        #endif
    }
    
    /**
     *  重设图标颜色
     */
    public func kaka_newImage(_ color: KakaColor) -> KakaImage? {
        #if os(iOS)
        UIGraphicsBeginImageContext(self.size)
        color.setFill()
        let bounds = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        UIRectFill(bounds)
        self.draw(in: bounds, blendMode: .destinationIn, alpha: 1.0)
        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return tintedImage
        #elseif os(macOS)
        let newImage = NSImage(size: self.size)
        newImage.lockFocus()
        color.setFill()
        let bounds = NSRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        bounds.fill()
        self.draw(in: bounds, from: NSZeroRect, operation: .destinationIn, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
        #endif
    }
    
    /**
     *  等比率缩放
     */
    public func kaka_scaleImage(scale: CGFloat) -> KakaImage? {
        let reSize = CGSize(width: self.size.width * scale, height: self.size.height * scale)
        return kaka_reSize(reSize: reSize)
    }
    
    /**
     *  黑白照
     */
    public func kaka_blackWhiteImage() -> KakaImage? {
        #if os(iOS)
        guard let vData = self.pngData() else { return self }
        let inputImage = CoreImage.CIImage(data: vData)
        #elseif os(macOS)
        guard let vData = self.tiffRepresentation else { return self }
        let inputImage = CoreImage.CIImage(data: vData)
        #endif
        
        let context = CIContext(options: nil)
        let filter = CIFilter(name: "CIPhotoEffectNoir")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        
        if let outputImage = filter?.outputImage {
            if let outImage = context.createCGImage(outputImage, from: outputImage.extent) {
                #if os(iOS)
                return UIImage(cgImage: outImage)
                #elseif os(macOS)
                return NSImage(cgImage: outImage, size: self.size)
                #endif
            }
        }
        return self
    }
    
    
    
    /// 由颜色和尺寸生成的图片
    public static func createImage(color: KakaColor, size: CGSize) -> KakaImage? {
#if os(iOS)
        // iOS 生成 UIImage
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
#elseif os(macOS)
        // macOS 生成 NSImage
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
#endif
    }
    
    
    #if os(iOS)
    // 阿拉伯语镜像
    public func flippedImage() -> KakaImage {
        return PhoneSetManager.isArabicLanguage() ? self.imageFlippedForRightToLeftLayoutDirection() : self
    }
    
    public func sfHorizontallyImage() -> KakaImage {
        return PhoneSetManager.isArabicLanguage() ? self.withHorizontallyFlippedOrientation() : self
    }
    #endif
    
}
