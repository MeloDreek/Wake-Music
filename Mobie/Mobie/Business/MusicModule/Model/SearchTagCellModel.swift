//
//  SearchTagCellModel.swift
//  Mobie
//
//  Created by 张文 on 5/11/25.
//

import Foundation

enum SearchTagGroupType: Int {
    case tipsGroup = 0
    case coverGroup = 1
    case lyricGroup = 2
}

struct SearchTagCellModel {
    
    /// 区分是哪一组
    var group = SearchTagGroupType.tipsGroup
    
    /// 头部标题
    var headTitle: String?
    
    /// 底部文字
    var footTitle: String?
    
}
