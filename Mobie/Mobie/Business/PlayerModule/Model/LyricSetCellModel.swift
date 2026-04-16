//
//  LyricSetCellModel.swift
//  Mobie
//
//  Created by 张文 on 5/27/25.
//

import AppGroupKit

/// 设置、默认、磁带、黑胶、自定义背景
enum LyricSetCellGroup {
    case animationGroup
    case timeOffsetGroup
    case lowPowerGroup
    case norFontGroup
    case selFontGroup
    case norColorGroup
    case selColorGroup
    case alignmentGroup
    case lineSpaceGroup
    
    func titleStr() -> String? {
        switch self {
        case .lowPowerGroup: return "Low Power Mode".localStr()
        case .timeOffsetGroup: return "Time Offset".localStr()
        default: return nil
        }
    }
        
    func recommentColors() -> [String?] {
        switch self {
        case .norColorGroup:
            return [nil, UIColor.lightGray, UIColor.gray, .systemGray2, .systemGray3, .systemGray4, UIColor.separator, UIColor.rgb(255, 192, 203), UIColor.rgb(240, 248, 255), UIColor.rgb(255, 255, 240), UIColor.rgb(255, 222, 173), UIColor.rgb(255, 228, 196), UIColor.rgb(192, 192, 192)].map {
                return $0?.hex16String
            }
        case .selColorGroup:
            return [nil, UIColor.systemRed, UIColor.systemYellow, UIColor.systemBlue, .systemGreen, .systemIndigo, UIColor.hexColor("#FF00FF"), UIColor.rgb(234, 114, 238), UIColor.rgb(24, 187, 238), UIColor.rgb(11, 70, 207), UIColor.rgb(236, 77, 37), UIColor.rgb(205, 0, 65), UIColor.rgb(85, 0, 241)].map {
                return $0?.hex16String
            }
        default: return []
        }
    }
}

struct LyricSetCellModel {
    
    /// 区分是哪一组
    var group = LyricSetCellGroup.norFontGroup
    
    /// 头部标题
    var headTitle: String?
    
    /// 底部文字
    var footTitle: String?
    
}

