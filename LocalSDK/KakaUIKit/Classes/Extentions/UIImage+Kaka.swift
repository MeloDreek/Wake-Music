//
//  UIImage+Kaka.swift
//  Kaka Inc.
//
//  Created by Kaka Inc. on 2019/8/27.
//  Copyright © 2021 Kaka Inc. All rights reserved.
//

import KakaFoundation

extension KakaImage {
    /// 点九图对半拉伸
	public func stretchableImage() -> KakaImage {
		let leftCapWidth: Int = Int(self.size.width / 2.0)
		let topCapHeight: Int = Int(self.size.height / 2.0)
		let image = self.stretchableImage(withLeftCapWidth: leftCapWidth, topCapHeight: topCapHeight)
		return image
	}
	
    /// 自定义点九图拉伸比例
	public func stretchableImage(leftRate: CGFloat, topRate: CGFloat) -> KakaImage {
		let leftCapWidth: Int = Int(self.size.width * leftRate)
		let topCapHeight: Int = Int(self.size.height * topRate)
		let image = self.stretchableImage(withLeftCapWidth: leftCapWidth, topCapHeight: topCapHeight)
		return image
	}
    
    /// 纵向拉伸图片
    public func verticallyStretchableImage(withTopRate topRate: CGFloat, bottomRate: CGFloat) -> UIImage {
        let topCapHeight = CGFloat(self.size.height * topRate)
        let bottomCapHeight = CGFloat(self.size.height * bottomRate)
        return self.resizableImage(withCapInsets: UIEdgeInsets(top: topCapHeight, left: 0, bottom: bottomCapHeight, right: 0), resizingMode: .stretch)
    }
    
    /// 根据图片大小决定是否压缩
    /// - Parameter maxSize: 最大允许的图片大小（以字节为单位），默认为 5MB
    /// - Returns: 返回压缩后的图片数据或原始图片数据
    public func dataWithCompression(maxSize: Int = 5 * 1024 * 1024) -> Data? {
        // 获取原始图片数据
        guard let originalImageData = self.jpegData(compressionQuality: 1.0) else {
            return nil
        }
        
        // 检查图片大小
        if originalImageData.count > maxSize {
            // 图片大于指定大小，进行压缩
            var compressionQuality: CGFloat = 0.9
            var compressedImageData = originalImageData
            
            // 循环压缩直到满足条件
            while compressedImageData.count > maxSize && compressionQuality > 0 {
                if let newData = self.jpegData(compressionQuality: compressionQuality) {
                    compressedImageData = newData
                }
                compressionQuality -= 0.1
            }
            
            return compressedImageData
        } else {
            // 图片小于等于指定大小，返回原始数据
            return originalImageData
        }
    }
    
    /// 图片镜像
    public func horizontallyMirrored() -> UIImage? {
        // 创建一个图形上下文
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        
        // 获取当前上下文
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        // 翻转上下文
        context.translateBy(x: size.width, y: 0)
        context.scaleBy(x: -1.0, y: 1.0)
        
        // 绘制原始图像
        context.draw(cgImage!, in: CGRect(origin: .zero, size: size))
        
        // 从当前上下文获取镜像图像
        let mirroredImage = UIGraphicsGetImageFromCurrentImageContext()
        
        // 结束图形上下文
        UIGraphicsEndImageContext()
        
        return mirroredImage
    }


    /// 裁剪出居中的正方形图像
    public func croppedToCenteredSquare() -> KakaImage? {
        let rect = centeredSquareRect(for: self)
        
        guard let cgImage = self.cgImage?.cropping(to: rect) else {
            return nil
        }
        
        return KakaImage(cgImage: cgImage, scale: self.scale, orientation: self.imageOrientation)
    }
    
    /// 计算居中的正方形裁剪区域
    private func centeredSquareRect(for image: KakaImage) -> CGRect {
        let size = image.size
        let sideLength = min(size.width, size.height)
        let originX = (size.width - sideLength) / 2
        let originY = (size.height - sideLength) / 2
        let scale = image.scale
        
        // 注意：裁剪的 CGRect 需要转换为像素单位（point * scale）
        return CGRect(x: originX * scale,
                      y: originY * scale,
                      width: sideLength * scale,
                      height: sideLength * scale)
    }
}

