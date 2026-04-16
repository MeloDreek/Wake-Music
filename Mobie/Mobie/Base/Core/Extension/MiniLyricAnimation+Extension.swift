//
//  MiniLyricAnimation+Extension.swift
//  Mobie
//
//  Created by 张文 on 6/4/25.
//

import AppGroupKit
import MorphingLabel

extension MiniLyricAnimation {
    func animationType() -> LTMorphingEffect? {
        switch self {
        case .normal:
            return nil
        case .random:
            return LTMorphingEffect.allCases.randomElement() ?? .scale
        case .scale:
            return .scale
        case .evaporate:
            return .evaporate
        case .fall:
            return .fall
        case .pixelate:
            return .pixelate
        case .sparkle:
            return .sparkle
        case .burn:
            return .burn
        case .anvil:
            return .anvil
        }
    }
}
