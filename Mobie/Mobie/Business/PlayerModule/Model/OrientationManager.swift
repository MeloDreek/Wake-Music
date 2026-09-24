//
//  OrientationManager.swift
//  Mobie
//
//  Created by 张文 on 6/6/25.
//

import KakaFoundation
import Combine
import UIKit

/// Separate compact-height phones from roomy windows without identifying a device model.
struct PlayerViewportLayout {
    let isCompactLandscape: Bool
    let usesTwoColumns: Bool

    init(size: CGSize, isPhone: Bool, horizontalIsRegular: Bool, verticalIsCompact: Bool) {
        isCompactLandscape = isPhone && verticalIsCompact && size.height < 500 &&
            size.width > 0 && size.height > 0
        usesTwoColumns = horizontalIsRegular && size.width >= 700 && size.height >= 500
    }
}

/// 监听屏幕旋转
final class OrientationManager: ObservableObject {
    static let shared = OrientationManager()
    
    // Historical name: this now describes the player's available layout, not UIScreen.
    #if targetEnvironment(macCatalyst)
    @Published public var isLandscape: Bool = false
    #else
    @Published private(set) var isLandscape: Bool = false
    #endif
    
    // 是否显示横向大歌词
    @Published public var isShowBigLyric: Bool = false

    private(set) var isCompactLandscape = false
    private(set) var safeAreaInsets: UIEdgeInsets = .zero
        
    // 控制层高度
    public var playerControlHeight: CGFloat {
        get {
            let bottom = safeAreaInsets.bottom
            
            if isCompactLandscape {
                return 50.ckValue() + bottom
            }else{
                return 185.ckValue() + bottom
            }
        }
    }
    
    private init() {}

    /// Re-evaluate after window, safe-area or trait changes (including folding).
    /// An expanded phone has room for both artwork and lyrics, unlike a short phone landscape.
    func updateLayout(in view: UIView) {
        safeAreaInsets = view.safeAreaInsets
#if !targetEnvironment(macCatalyst)
        let size = view.bounds.inset(by: UIEdgeInsets(top: 0, left: safeAreaInsets.left,
                                                    bottom: 0, right: safeAreaInsets.right)).size
        guard size.width > 0, size.height > 0 else { return }
        let layout = PlayerViewportLayout(size: size,
                                          isPhone: view.traitCollection.userInterfaceIdiom == .phone,
                                          horizontalIsRegular: view.traitCollection.horizontalSizeClass == .regular,
                                          verticalIsCompact: view.traitCollection.verticalSizeClass == .compact)
        isCompactLandscape = layout.isCompactLandscape
        let landscapeLayout = layout.isCompactLandscape || layout.usesTwoColumns
        if isLandscape != landscapeLayout { isLandscape = landscapeLayout }
        // Never toggle this on every layout pass: expanding must not hide transport controls.
        if isShowBigLyric != layout.isCompactLandscape { isShowBigLyric = layout.isCompactLandscape }
#endif
    }
    
    // 主动同步（适用于 iOS16+ 手动切换）
    func forceUpdate(to isLandscape: Bool) {
        if self.isLandscape != isLandscape { self.isLandscape = isLandscape }
        if !isLandscape {
            isCompactLandscape = false
            if isShowBigLyric { isShowBigLyric = false }
        }
    }
    
}
