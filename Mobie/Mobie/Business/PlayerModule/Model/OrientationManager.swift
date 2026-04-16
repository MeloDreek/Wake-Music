//
//  OrientationManager.swift
//  Mobie
//
//  Created by 张文 on 6/6/25.
//

import KakaFoundation
import Combine

/// 监听屏幕旋转
final class OrientationManager: ObservableObject {
    static let shared = OrientationManager()
    
    // 屏幕朝向
    #if targetEnvironment(macCatalyst)
    @Published public var isLandscape: Bool = false
    #else
    @Published private(set) var isLandscape: Bool = UIScreen.main.bounds.width > UIScreen.main.bounds.height
    #endif
    
    // 是否显示横向大歌词
    @Published public var isShowBigLyric: Bool = false
        
    // 控制层高度
    public var playerControlHeight: CGFloat {
        get {
            let isPhoneLandscape = kaka_IsiPhone() && self.isLandscape
            let bottom = kaka_safeAreaInsets().bottom
            
            if isPhoneLandscape {
                return 50.ckValue() + bottom
            }else{
                return 185.ckValue() + bottom
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()

#if targetEnvironment(macCatalyst)
    private init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        NotificationCenter.default
            .publisher(for: UIDevice.orientationDidChangeNotification)
            .compactMap { _ in
                let orientation = UIDevice.current.orientation
                debugPrint("屏幕发生变化啦 = \(orientation)")
                return orientation.isValidInterfaceOrientation ? orientation.isLandscape : nil
            }
            .removeDuplicates()
            .assign(to: &$isLandscape)
    }
#endif
    
    // 主动同步（适用于 iOS16+ 手动切换）
    func forceUpdate(to isLandscape: Bool) {
        let orientation = UIDevice.current.orientation
        debugPrint("屏幕发生变化啦22 = \(orientation)")
        self.isLandscape = isLandscape
        
        if !isLandscape && self.isShowBigLyric {
            self.isShowBigLyric = false
        }else{
            self.isShowBigLyric = true
        }
    }
    
}
