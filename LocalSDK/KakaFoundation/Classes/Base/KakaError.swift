//
//  KakaError.swift
//  KakaFoundation
//
//  Created by 张文 on 8/12/25.
//

import Foundation

public enum KakaError: LocalizedError, Equatable {
    case custom(String)   // 自定义错误
    case unknowError      // 未知错误
    case youhaveCanceled // 您已取消
    case duplicateNames // 重复的文件名
    case tokenExpiredAuthAgain   // 网盘token过期，需要重新授权
    case emptyData             // 暂无数据
    
    /// 自定义的错误提示
    public var errorDescription: String {
        switch self {
        case .custom(let message):
            return message
        case .unknowError:
            return "Unknown Error❗️".localStr()
        case .youhaveCanceled:
            return "You have canceled😭".localStr()
        case .duplicateNames:
            return "Duplicate file name. Please rename the file.".localStr()
        case .tokenExpiredAuthAgain:
            return "Login failed or your authorization has expired. Please sign in again.".localStr()
        case .emptyData:
            return "No data available".localStr()
        }
    }
            
    public static func == (lhs: KakaError, rhs: KakaError) -> Bool {
        switch (lhs, rhs) {
        case (.custom(let code1), .custom(let code2)):
            return code1 == code2
        case (.duplicateNames, .duplicateNames),
            (.unknowError, .unknowError),
            (.youhaveCanceled, .youhaveCanceled),
              (.tokenExpiredAuthAgain, .tokenExpiredAuthAgain),
            (.emptyData, .emptyData):
            return true
        default:
            return false
        }
    }
    
}

extension Error {
    public var nsError: NSError? {
        get {
            return (self as? NSError)
        }
    }
    
}

