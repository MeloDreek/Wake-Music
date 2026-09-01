//
//  SortedbyType.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2024/2/26.
//

import AppGroupKit

/// 排序类型
public extension SortedbyType {
    
    func formatStr() -> String {
        switch self {
        case .createDate:
            return "Date Created".localStr()
        case .modifyDate:
            return "Date Modified".localStr()
        case .fileSize:
            return "File Size".localStr()
        case .fileName:
            return "File Name".localStr()
        }
    }
    
}

/// 文件分组
public extension GroupItemType {
    func formatStr() -> String {
        switch self {
        case .nonGroup:
            return "Ungroup".localStr()
        case .musictagGroup:
            return "Music Tags".localStr()
        case .titleGroup:
            return "Title".localStr()
        case .artistGroup:
            return "Artist".localStr()
        }
    }
    
}
