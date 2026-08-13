//
//  MusicConfigManager+Action.swift
//  Mobie
//
//  Created by kaka on 2026/8/13.
//

import AppGroupKit

extension MusicConfigManager {
    
    /// 封面占位图
    public var musicPlaceImage: UIImage {
        get {
            guard let cacheImage = (objc_getAssociatedObject(self, &ConfigKeys.kPlaceImgKey) as? UIImage) else {
                let defaultImage = UIImage(named: "music_place")!
                objc_setAssociatedObject(self, &ConfigKeys.kPlaceImgKey, defaultImage, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return defaultImage
            }
            
            return cacheImage
        }
        set {
            objc_setAssociatedObject(self, &ConfigKeys.kPlaceImgKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private struct ConfigKeys {
        static var kPlaceImgKey: Void?
    }
}

