//
//  PlayerUICellModel.swift
//  Mobie
//
//  Created by 张文 on 5/20/25.
//

import AppGroupKit

/// 设置、默认、磁带、黑胶、自定义背景
enum PlayerUIGroupType {
    case defaultGroup
    case tapeGroup
    case vinylGroup
}

struct PlayerUICellModel {
    
    /// 区分是哪一组
    var group = PlayerUIGroupType.defaultGroup
    
    /// 头部标题
    var headTitle: String?
    
    /// 数据源
    var itemArray: [PlayerUIStyle] = []
    
    /// 底部文字
    var footTitle: String?
    
}

