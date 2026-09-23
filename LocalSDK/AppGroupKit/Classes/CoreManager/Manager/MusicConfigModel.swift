//
//  MusicConfigModel.swift
//  AppGroupKit
//
//  Created by 张文 on 5/21/25.
//

import SmartCodable

/// 屏幕歌词顺序
public enum LyricSortStyle: Int, SmartCaseDefaultable {
    case dontShow = 0
    case firstLine = 1
    case secondLine = 2
}

/// 播放器内核
public enum PlayerEngineType: Int, SmartCaseDefaultable {
    case avPlayer = 0
    case wakePlayer = 1
    case autoPlayer = 2
}

/// 播放顺序
public enum PlaybackOrderType: Int, SmartCaseDefaultable {
    case normal = 0
    case random = 1
    case single = 2
}

/// 播放模式
public enum MusicPlayMode: Int, SmartCaseDefaultable {
    case music = 0
    case game  = 1
}

public enum PreDownloadSize: Int, SmartCaseDefaultable {
    case GB2 = 2
    case GB4 = 4
    case GB8 = 8
    case GB16 = 16
    case GB32 = 32
    case GB64 = 64
    
    public func formatStr() -> String {
        return String(format: "\(self.rawValue)GB")
    }
}

/// Navidrome最大比特率
public enum NavidromeMaxBitRate: Int, SmartCaseDefaultable {
    case bitRate0 = 0        // 不转码
    case bitRate128 = 128   // 128：较低
    case bitRate192 = 192   // 192：标准
    case bitRate320 = 320   // 320：极高
    
    public func formatStr() -> String {
        switch self {
        case .bitRate0:
            return "No Transcoding".localStr()
        case .bitRate128:
            return "128 kbps"
        case .bitRate192:
            return "192 kbps"
        case .bitRate320:
            return "320 kbps"
        }
    }
}

/// 字体对齐方式
public enum LyricTextAlignment: Int, SmartCaseDefaultable {
    case center = 0
    case left = 1
    case right = 2
}

/// Navidrome转码格式
public enum NavidromeTargetFormat: String, SmartCaseDefaultable {
    case raw = "raw"    // 特殊值：禁止转格式
    case mp3 = "mp3"    // MP3
    case opus = "opus"  // OPUS
    case aac = "aac"    // AAC
    
    public func formatStr() -> String {
        switch self {
        case .raw:
            return "No Transcoding".localStr()
        case .mp3:
            return "MP3"
        case .opus:
            return "OPUS"
        case .aac:
            return "AAC"
        }
    }
}

public enum MiniLyricAnimation: Int, SmartCaseDefaultable {
    case normal = 0
    case anvil = 1
    case scale = 2
    case evaporate = 3
    case fall = 4
    case pixelate = 5
    case sparkle = 6
    case burn = 7
    case random = 8
}

/// 歌词字体配置
public struct LyricConfigModel: SmartCodableX {
    
    public init(norFontSize: Float, selFontSize: Float, norFontColor: String, selFontColor: String, alignment: LyricTextAlignment, lineSpace: Float) {
        self.norFontSize = norFontSize
        self.selFontSize = selFontSize
        self.norFontColor = norFontColor
        self.selFontColor = selFontColor
        self.alignment = alignment
        self.lineSpace = lineSpace
    }
    
    public init() {
        
    }
    
    /// 显示迷你歌词区域，磁带和黑胶不受此影响
    public var isShowMiniLyric: Bool = true
    
    /// 迷你歌词动画
    public var miniLyricAnimation: MiniLyricAnimation = .random
    
    /// 低电量模式
    public var isLowPowerMode: Bool = true
    
    /// 常规字体
    public var norFontSize: Float = 16
    
    /// 高亮字体
    public var selFontSize: Float = 18
    
    /// 常规颜色
    public var norFontColor: String = UIColor.gray.hex16String
    
    /// 高亮颜色
    public var selFontColor: String = UIColor.white.hex16String
    
    /// 对齐方式
    public var alignment: LyricTextAlignment = .center
    
    /// 上下
    public var lineSpace: Float = 15
}

// 默认、磁带、黑胶
public enum PlayerUIStyle: Int, SmartCaseDefaultable {
    
    case defaultRect = 0
    case defaultCircle = 1
    case default8Side = 2
    
    case tape1 = 11
    case tape2 = 12
    case tape3 = 13
    case tape4 = 14
    case tape5 = 15
    case tape6 = 16
    case tape7 = 17
    case tape8 = 18
    
    
    case Vinyl1 = 31
    case Vinyl2 = 32
    case Vinyl3 = 33
    case Vinyl4 = 34
    case Vinyl5 = 35
    case Vinyl6 = 36
    case Vinyl7 = 37
    case Vinyl8 = 38
    
    /// 是否为默认的几何样式
    public func isDefaultStyle() -> Bool {
        return self == .defaultRect || self == .default8Side  || self == .defaultCircle
    }
    
    /// 是否为磁带样式
    public func isTapeStyle() -> Bool {
        return self == .tape1  || self == .tape2  || self == .tape3  || self == .tape4  || self == .tape5  || self == .tape6  || self == .tape7  || self == .tape8
    }
    
    /// 是否为磁带样式
    public func isVinylStyle() -> Bool {
        return self == .Vinyl1  || self == .Vinyl2  || self == .Vinyl3  || self == .Vinyl4  || self == .Vinyl5  || self == .Vinyl6  || self == .Vinyl7  || self == .Vinyl8
    }
    
}
