//
//  UserInfoGroupCellModel.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/20.
//

import AppGroupKit

enum UserInfoCellGroupType: Int {
    case info = 0
    case purchage = 1
}

struct UserInfoGroupCellModel {
    
    /// 区分是哪一组
    var group = UserInfoCellGroupType.info
    
    /// 头部标题
    var headTitle: String?
    
    /// 数据源
    var itemArray: [UserInfoCellItemType] = []
    
    /// 底部文字
    var footTitle: String?
    
}

enum UserInfoCellItemType: Int {
    case nickName = 0
    case endDate = 1
    case premium = 2
    
    case purchageList = 3
    
    func titleStr() -> String {
        switch self {
        case .nickName:
            return "Nickname".localStr()
        case .endDate:
            return "Expiration Date".localStr()
        case .premium:
            return "Upgrade to Lifetime".localStr()
            
        case .purchageList:
            return "Purchase History".localStr()
        
        }
    }
    
    func cellImage() -> UIImage? {
        switch self {
        case .nickName:
            let image = UIImage(systemName: "at.badge.plus", compatibleWith: .current)
            return image
        case .endDate:
            let image = UIImage(systemName: "v.square", compatibleWith: .current)
            return image
        case .premium:
            let image = UIImage(systemName: "crown", compatibleWith: .current)
            return image
        case .purchageList: return nil
        }
        
    }
    
    
}
