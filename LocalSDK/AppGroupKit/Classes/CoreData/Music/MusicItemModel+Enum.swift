//
//  MusicItemModel+Enum.swift
//  AppGroupKit
//
//  Created by 张文 on 7/16/25.
//

import SmartCodable

/// 分组类型
public enum GroupItemType: Int, CaseIterable, SmartCaseDefaultable {
    case nonGroup = 0         // 不分组
    case musictagGroup = 1    // 音乐标签
    case titleGroup = 2       // 歌名分组
    case artistGroup = 3      // 艺术家分组
}

/// 排序方式
public enum SortedbyType: Int, SmartCaseDefaultable {
    case createDate = 0     // 创建时间排序
    case modifyDate = 1     // 修改时间排序
    case fileSize = 2        // 文件尺寸排序
    case fileName = 3        // 文件名称排序
}

/// 声道
public enum AudioChannels: Int, SmartCaseDefaultable {
    case mono = 1            // 声道（单声道, Mono)
    case stereo = 2          // 声道（立体声, Stereo）
    case surround51 = 6      // 声道（5.1 环绕声, Surround Sound）
    case surround71 = 8      // 声道（7.1 环绕声, Surround Sound）
    case atmos = 9           // 9.1 Atmos 环绕声，11.1 Atmos 环绕声，13.1 Atmos 环绕声（极少见）

    public init(channel: Int) {
        switch channel {
        case 1:
            self = .mono
        case 2:
            self = .stereo
        case 5,6:
            self = .surround51
        case 7,8:
            self = .surround71
        default:
            self = channel > 8 ? .atmos : .mono
        }
    }
        
    public func iconImage() -> UIImage? {
        var iconName = "dot.radiowaves.right"
        switch self {
        case .mono:
            iconName = "dot.radiowaves.right"
        case .stereo:
            iconName = "dot.radiowaves.left.and.right"
        case .surround51:
            iconName = "waveform"
        case .surround71:
            iconName = "waveform"
        case .atmos:
            iconName = "waveform.path"
        }
        
        let image = UIImage(systemName: iconName, withConfiguration: nil)
        return image?.withRenderingMode(.alwaysOriginal)
    }
    
}

/// 文件操作方式
public enum FileHandleType: Int, SmartCaseDefaultable {
    case copy = 0   // 复制源文件
    case move = 1   // 移动源文件
    case link = 2   // 连接源路径
}

/// 文件类型
public enum ConnectFileType: Int {
    case folder = 0
    case music = 1
    case other = 2
    
    public func titleStr() -> String {
        switch self {
        case .folder:
            return "Folder".localStr()
        case .music:
            return "Music".localStr()
        case .other:
            return "Others".localStr()
        }
    }
    
    public func keyStr() -> String {
        switch self {
        case .folder:
            return "📁"
        case .music:
            return "🎵"
        case .other:
            return "⚠️"
        }
    }
}
