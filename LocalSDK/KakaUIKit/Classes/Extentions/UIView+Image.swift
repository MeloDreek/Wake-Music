//
//  UIView+Image.swift
//  KakaUIKit
//
//  Created by Melo Dreek on 2023/8/6.
//

import Foundation

public extension UIView {
    
    // 将UIView转成UIImage
    public func convertPiexImage() -> UIImage? {

        // Create a new image context with a white background
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.bounds.size.height))

        let piexl: CGFloat = 8

        // Draw diagonal lines with alternating colors
        let colors: [UIColor] = [UIColor.white, UIColor.rgb(240, 240, 240), UIColor.rgb(225, 225, 225)]
        
        let colorCount: Int = Int(self.frame.size.width / piexl)
        
        var tempColors = [UIColor]()
        while tempColors.count < colorCount {
            tempColors += colors
        }
        
        tempColors += tempColors
        
        for (index, color) in tempColors.enumerated() {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: CGFloat(index) * piexl, y: 0))
            path.addLine(to: CGPoint(x: 0, y: CGFloat(index) * piexl))
            path.addLine(to: CGPoint(x: 0, y: CGFloat(index) * piexl + piexl))
            path.addLine(to: CGPoint(x: CGFloat(index) * piexl + piexl, y: 0))
            path.close()
            color.setFill()
            path.fill()
        }

        // Get the final image from the context
        let image = UIGraphicsGetImageFromCurrentImageContext()

        // End the image context
        UIGraphicsEndImageContext()

        // Display the image in an image view or save it to a file
        return image
                
    }
    
}

