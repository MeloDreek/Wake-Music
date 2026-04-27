//
//  PlayBackgroundModel.swift
//  AppGroupKit
//
//  Created by 张文 on 5/21/25.
//

import SmartCodable

/// 内置的播放器背景
public enum PlayBackgroundSystem: Int, SmartCaseDefaultable {
    case style1 = 1
    case style2 = 2
    case style3 = 3
    case style4 = 4
    case style5 = 5
    case style6 = 6
    case style7 = 7
    case style8 = 8
    case style9 = 9
    case style10 = 10
    case style11 = 11
    case style12 = 12
    case style13 = 13
    case style14 = 14
}

// 高斯模糊、封面主色调、半透明遮罩
public enum PlayBackgroundEffect: Int, SmartCaseDefaultable {
    case gaussianBlur = 0
    case coverAssetColor = 1
    case translucencyMask = 2
    
    case showAlphaMask = 3 
}

/// 播放器背景样式
public enum PlayBackgroundStyle: Int, SmartCaseDefaultable {
    case defaultType = 0 // 封面艺术
    case systemType = 1  // 系统背景图
    case customType = 2  // 自定义背景图
}

/// 播放器背景模型
public struct PlayBackgroundModel: SmartCodableX {
    
    public init() {
        
    }
    
    public init(backgroundType: PlayBackgroundStyle = PlayBackgroundStyle.defaultType, backgroundName: String? = nil, backgroundConfig: PlayBackgroundEffect = PlayBackgroundEffect.gaussianBlur, isShowAlphaMask: Bool = false) {
        self.backgroundType = backgroundType
        self.backgroundName = backgroundName
        self.backgroundConfig = backgroundConfig
        self.isShowAlphaMask = isShowAlphaMask
    }
    
    /// 哪一种背景
    public var backgroundType = PlayBackgroundStyle.defaultType
    
    /// 背景图片的名称
    public var backgroundName: String?
    
    /// 背景偏好设置
    public var backgroundConfig = PlayBackgroundEffect.gaussianBlur
    
    /// 是否显示半透明遮罩
    public var isShowAlphaMask: Bool = false
    
}
