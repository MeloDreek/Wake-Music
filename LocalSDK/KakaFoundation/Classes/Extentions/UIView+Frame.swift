//
//  UIView+Frame.swift
//  Pods
//
//  Created by 张文 on 9/22/24.
//

import Foundation

extension KakaView {
    // left: 获取和设置视图的x坐标
    public var left: CGFloat {
        get {
            return self.frame.origin.x
        }
        set(newLeft) {
            var frame = self.frame
            frame.origin.x = newLeft
            self.frame = frame
        }
    }

    // top: 获取和设置视图的y坐标
    public var top: CGFloat {
        get {
            return self.frame.origin.y
        }
        set(newTop) {
            var frame = self.frame
            frame.origin.y = newTop
            self.frame = frame
        }
    }

    // right: 获取和设置视图的右边缘坐标
    public var right: CGFloat {
        get {
            return self.frame.origin.x + self.frame.size.width
        }
        set(newRight) {
            var frame = self.frame
            frame.origin.x = newRight - frame.size.width
            self.frame = frame
        }
    }

    // bottom: 获取和设置视图的底边缘坐标
    public var bottom: CGFloat {
        get {
            return self.frame.origin.y + self.frame.size.height
        }
        set(newBottom) {
            var frame = self.frame
            frame.origin.y = newBottom - frame.size.height
            self.frame = frame
        }
    }

    // width: 获取和设置视图的宽度
    public var width: CGFloat {
        get {
            return self.frame.size.width
        }
        set(newWidth) {
            var frame = self.frame
            frame.size.width = newWidth
            self.frame = frame
        }
    }

    // height: 获取和设置视图的高度
    public var height: CGFloat {
        get {
            return self.frame.size.height
        }
        set(newHeight) {
            var frame = self.frame
            frame.size.height = newHeight
            self.frame = frame
        }
    }

    // centerX: 获取和设置视图的中心点x坐标
    public var centerX: CGFloat {
        get {
            #if os(iOS)
            return self.center.x
            #elseif os(macOS)
            return self.frame.midX
            #endif
        }
        set(newCenterX) {
            #if os(iOS)
            self.center = CGPoint(x: newCenterX, y: self.center.y)
            #elseif os(macOS)
            self.setFrameOrigin(CGPoint(x: newCenterX - self.frame.size.width / 2, y: self.frame.origin.y))
            #endif
        }
    }

    // centerY: 获取和设置视图的中心点y坐标
    public var centerY: CGFloat {
        get {
            #if os(iOS)
            return self.center.y
            #elseif os(macOS)
            return self.frame.midY
            #endif
        }
        set(newCenterY) {
            #if os(iOS)
            self.center = CGPoint(x: self.center.x, y: newCenterY)
            #elseif os(macOS)
            self.setFrameOrigin(CGPoint(x: self.frame.origin.x, y: newCenterY - self.frame.size.height / 2))
            #endif
        }
    }

    // origin: 获取和设置视图的起始点坐标
    public var origin: CGPoint {
        get {
            return self.frame.origin
        }
        set(newOrigin) {
            #if os(iOS)
            self.frame.origin = newOrigin
            #elseif os(macOS)
            self.setFrameOrigin(newOrigin)
            #endif
        }
    }

    // size: 获取和设置视图的尺寸
    public var size: CGSize {
        get {
            return self.frame.size
        }
        set(newSize) {
            #if os(iOS)
            self.frame.size = newSize
            #elseif os(macOS)
            self.setFrameSize(newSize)
            #endif
        }
    }
}

