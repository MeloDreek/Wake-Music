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
            var name = "repeat"
            if #available(iOS 14.2, *) {
                name = kaka_IsMacOS() ? "repeat.circle.fill" : "repeat"
            }
            return Reasource.systemNamed(name, color: color, config: config).flippedImage()
        case .random:
            var name = "shuffle"
            if #available(iOS 14.2, *) {
                name = kaka_IsMacOS() ? "shuffle.circle.fill" : "shuffle"
            }
            return Reasource.systemNamed(name, color: color, config: config).flippedImage()
        case .single:
            var name = "repeat.1"
            if #available(iOS 14.2, *) {
                name = kaka_IsMacOS() ? "repeat.1.circle.fill" : "repeat.1"
            }
            return Reasource.systemNamed(name, color: color, config: config).flippedImage()
        }
    }
}

extension MusicPlayMode {
    func audioCategory() -> AVAudioSession.Category {
        switch self {
        case .music:
            return .playback
        case .game:
//            return .ambient
            return .playback
        }
    }
    
    func titleStr() -> String {
        switch self {
        case .music:
            return "Music Mode".localStr()
        case .game:
            return "Game Mode".localStr()
        }
    }
    
    func iconImage() -> UIImage? {
        switch self {
        case .music:
            if #available(iOS 14.5, *) {
                return Reasource.systemNamed("hifispeaker.and.homepodmini.fill", color: .white)
            }else{
                return Reasource.systemNamed("airpods", color: .white)
            }
        case .game:
            return Reasource.systemNamed("gamecontroller.fill", color: .white)
        }
    }
    
    func tintColor() -> UIColor {
        switch self {
        case .music:
            return UIColor.green
        case .game:
            return UIColor.rgb(247, 42, 74)
        }
    }
    
    func descStr() -> String {
        switch self {
        case .music:
            return "In music mode, the app's audio output will be assigned as dominant by the system, but can still be mixed with audio from other apps such as map navigation.".localStr()
        case .game:
            return "In game mode, the app's audio will be mixed with other apps' audio, you can freely adjust the volume of each to get the best experience, and play offline music without hogging your game's internet speed.".localStr()
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
