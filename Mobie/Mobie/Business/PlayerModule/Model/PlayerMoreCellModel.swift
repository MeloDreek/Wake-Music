//
//  PlayerMoreCellModel.swift
//  Mobie
//
//  Created by 张文 on 6/5/25.
//

import AppGroupKit

/// 设置、默认、磁带、黑胶、自定义背景
enum PlayerMoreGroup {
    case musictagGroup
    case playerSetGroup
    case otherGroup
}

struct PlayerMoreCellModel {
    
    /// 区分是哪一组
    var group = PlayerMoreGroup.musictagGroup
    
    /// 头部标题
    var headTitle: String?
    
    /// 数据源
    var itemArray: [PlayerMoreType] = []
    
    /// 底部文字
    var footTitle: String?
    
}

enum PlayerMoreType {
    case aiSearchLyric
}
