//
//  KakaOSType+Value.swift
//  AppGroupKit
//
//  Created by Kaka Inc. on 2023/12/12.
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

public let PAD_CK_VALUE: CGFloat = 1.2
 
extension Int {
    public func ckValue(_ iphoneRate: CGFloat = 1, _ ipadRate: CGFloat = PAD_CK_VALUE) -> CGFloat {
        return kaka_IsMacOS() ? CGFloat(self) : (CGFloat(self) * (kaka_IsiPad() ? ipadRate : iphoneRate))
    }
}

extension CGFloat {
    public func ckValue(_ iphoneRate: CGFloat = 1, ipadRate: CGFloat = PAD_CK_VALUE) -> CGFloat {
        return kaka_IsMacOS() ? CGFloat(self) : (self * (kaka_IsiPad() ? ipadRate : iphoneRate))
    }
}

extension Float {
    public func ckValue(_ iphoneRate: CGFloat = 1, ipadRate: CGFloat = PAD_CK_VALUE) -> CGFloat {
        return kaka_IsMacOS() ? CGFloat(self) : (CGFloat(self) * (kaka_IsiPad() ? ipadRate : iphoneRate))
    }
}

extension Double {
    public func ckValue(_ iphoneRate: CGFloat = 1, ipadRate: CGFloat = PAD_CK_VALUE) -> CGFloat {
        return kaka_IsMacOS() ? CGFloat(self) : (CGFloat(self) * (kaka_IsiPad() ? ipadRate : iphoneRate))
    }
}
