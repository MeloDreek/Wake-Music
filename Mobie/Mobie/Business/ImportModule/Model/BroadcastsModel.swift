//
//  BroadcastsModel.swift
//  Wake Music
//
//  Created by Melo on 8/1/24.
//

import AppGroupKit

public enum BroadcastsType: Int {
    case fm7 = 1  // 周日
    case fm1 = 2  // 周一
    case fm2 = 3  // 周二
    case fm3 = 4  // 周三
    case fm4 = 5  // 周四
    case fm5 = 6  // 周五
    case fm6 = 7  // 周六
    
    public static func allChannel() -> [BroadcastsType] {
        return [.fm7, .fm1, .fm2, .fm3, .fm4, .fm5, .fm6]
    }
    
    public func titleStr() -> String {
        switch self {
        case .fm7:
            return "Freedom Radio".localStr()
        case .fm1:
            return "Pop & Rock Radio".localStr()
        case .fm2:
            return "Classic Radio".localStr()
        case .fm3:
            return "Lonely Radio".localStr()
        case .fm4:
            return "Deep Sleep Radio".localStr()
        case .fm5:
            return "1980s Radio".localStr()
        case .fm6:
            return "Pre-1970s Radio".localStr()
        }

    }
    
    public func linkUrl() -> URL {
        let bitValue = UserInfoManager.shared.isVIP() ? 128 : 64
        switch self {
        case .fm7:
            return URL(string: "http://ice5.somafm.com/groovesalad-\(bitValue)-aac")!
        case .fm1:
            return URL(string: "http://ice5.somafm.com/indiepop-\(bitValue)-aac")!
        case .fm2:
            return URL(string: "http://ice5.somafm.com/gsclassic-\(bitValue)-aac")!
        case .fm3:
            return URL(string: "http://ice5.somafm.com/dronezone-\(bitValue)-aac")!
        case .fm4:
            return URL(string: "http://ice5.somafm.com/deepspaceone-\(bitValue)-aac")!
        case .fm5:
            return URL(string: "http://ice5.somafm.com/u80s-\(bitValue)-aac")!
        case .fm6:
            return URL(string: "http://ice5.somafm.com/seventies-\(bitValue)-aac")!
        }
    }
    
    
    public func coverImage() -> UIImage {
        switch self {
        case .fm7:
            return Reasource.named("fm_bg_1")
        case .fm1:
            return Reasource.named("fm_bg_2")
        case .fm2:
            return Reasource.named("fm_bg_3")
        case .fm3:
            return Reasource.named("fm_bg_4")
        case .fm4:
            return Reasource.named("fm_bg_5")
        case .fm5:
            return Reasource.named("fm_bg_6")
        case .fm6:
            return Reasource.named("fm_bg_7")
        }
    }
    
}
