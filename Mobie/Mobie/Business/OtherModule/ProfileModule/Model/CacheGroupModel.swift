//
//  CacheGroupModel.swift
//  Mobie
//
//  Created by 张文 on 4/1/25.
//

import AppGroupKit

enum CacheGroupCell: Int {
    case header = 0
    case config = 1
    case caches = 2
}

struct CacheGroupCellModel {
    
    /// 区分是哪一组
    var group = CacheGroupCell.config
    
    /// 头部标题
    var headTitle: String?
    
    /// 数据源
    var itemArray: [CacheGroupCellItem] = []
    
    /// 底部文字
    var footTitle: String?
    
}


// 开启缓存，缓存大小，缓存地址。
enum CacheGroupCellItem: Int {
    case header = 0
    
    case cacheSwitch = 1
    case cacheSize = 2
    case cachePath = 3
        
    func titleStr() -> String {
        switch self {
        case .header:
            return "Pre-download the next song while playing remote music. Once downloaded, it plays instantly without buffering, Wi-Fi, or cellular data.".localStr()
        case .cacheSwitch:
            return "Pre-download".localStr()
        case .cacheSize:
            return "Max Cache".localStr()
        case .cachePath:
            return "Cache Location".localStr()
        }
    }
    
}
