//
//  LoginGroupModel.swift
//  Mobie
//
//  Created by 张文 on 12/29/24.
//

import AppGroupKit

enum LoginGroupType: Int {
    case titleGroup = 0
    case serverGroup = 1
    case loginGroup = 2
    case buttonGroup = 3
}

struct LoginGroupModel {
    
    /// 区分是哪一组
    var group = LoginGroupType.titleGroup
    
    /// 头部标题
    var headTitle: String?
    
    /// 数据源
    var itemArray: [LoginGroupItemType] = []
    
    /// 底部文字
    var footTitle: String?
    
}

enum LoginGroupItemType: Int {
    
    case title = 0
    
    case httpOption = 1
    case host = 2
    case path = 3
    case port = 4
    case serverType = 5
    
    case username = 6
    case password = 7
    
    case cusButton = 8
    
    case otherDav = 9
            
    func titleStr(_ importType: ImportFileType) -> String {
        switch self {
        case .title:
            return "Name".localStr()
            
        case .httpOption:
            return "Protocol".localStr()
        case .host:
            return importType == .fromNavidrome ? "URL" : "Host".localStr()
        case .path:
            return "Path".localStr()
        case .port:
            return "Port".localStr()
        case .serverType:
            return "More than 10,000 songs?".localStr()
        
        case .username:
            return "Username".localStr()
        case .password:
            return "Password".localStr()
            
        case .cusButton:
            return ""
            
        case .otherDav:
            return ""
        }
    }
    
    func placeHolder(_ importType: ImportFileType) -> String? {
        switch self {
        case .title:
            return "Optional".localStr()
            
        case .httpOption:
            return nil
        case .host:
            return importType == .fromWebDAV ? ("Required".localStr() + " (127.0.0.1)") : "https://example.com"
        case .path:
            return "Optional".localStr() + " (dav)"
        case .port:
            return "Optional".localStr() + " (80)"
        case .serverType:
            return nil
        
        case .username:
            return importType == .fromWebDAV ? "Optional".localStr() : "Required".localStr()
        case .password:
            return importType == .fromWebDAV ? "Optional".localStr() : "Required".localStr()
            
        case .otherDav:
            return nil
        case .cusButton:
            return nil
        }
    }
    
}
