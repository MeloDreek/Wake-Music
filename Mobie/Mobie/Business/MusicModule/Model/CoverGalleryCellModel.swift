//
//  CoverGalleryCellModel.swift
//  Mobie
//
//  Created by 张文 on 5/12/25.
//

import Foundation

enum CoverGalleryGroupType: Int {
    case headGroup = 0
    case selectImage
    case audioFinger
    case localGroup
}

struct CoverGalleryCellModel {
    
    /// 区分是哪一组
    var group = CoverGalleryGroupType.headGroup
    
    /// 头部标题
    var headTitle: String?
    
    /// 底部文字
    var footTitle: String?
    
}
