//
//  PlaybackOrderType.swift
//  Mobie
//
//  Created by 张文 on 11/11/24.
//

import KakaFoundation
import AppGroupKit
import AVFoundation

extension PlaybackOrderType {
    public func iconImage(color: UIColor, config: UIImage.SymbolConfiguration?) -> UIImage? {
        switch self {
        case .normal:
            let name = kaka_IsMacOS() ? "repeat.circle.fill" : "repeat"
            return Reasource.systemNamed(name, color: color, config: config).flippedImage()
        case .random:
            let name = kaka_IsMacOS() ? "shuffle.circle.fill" : "shuffle"
            return Reasource.systemNamed(name, color: color, config: config).flippedImage()
        case .single:
            let name = kaka_IsMacOS() ? "repeat.1.circle.fill" : "repeat.1"
            return Reasource.systemNamed(name, color: color, config: config).flippedImage()
        }
    }
}

extension LyricTextAlignment {
    public func textAlignment() -> NSTextAlignment {
        switch self {
        case .center:
            return .center
        case .left:
            return .left
        case .right:
            return .right
        }
    }
    
    public func cellAlignment() -> UIListContentConfiguration.TextProperties.TextAlignment {
        switch self {
        case .center:
            return .center
        case .left:
            return .natural
        case .right:
            return .justified
        }
    }
    
    public func iconImage(_ color: UIColor = .label) -> UIImage {
        switch self {
        case .center:
            return Reasource.systemNamed("text.aligncenter", color: color)
        case .left:
            return Reasource.systemNamed("text.alignleft", color: color)
        case .right:
            return Reasource.systemNamed("text.alignright", color: color)
        }
    }
    
    public func titleStr() -> String {
        switch self {
        case .center:
            return "Center".localStr()
        case .left:
            return "Left".localStr()
        case .right:
            return "Right".localStr()
        }
    }
    
}
