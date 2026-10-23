//
//  ConfigInfoKey.swift
//  Kaka
//
//  Created by Kaka Inc. on 2022/9/20.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit



// 联系邮箱
let companyEmail = "support@kakainc.com"
let emailAppURL = kaka_IsMacOS() ? "https://mail.google.com/" : "https://apps.apple.com/app/id1108187098"
let FeedbackURL = URL(string: "https://tally.so/r/jaqN96")!


// 隐私政策
var kPrivacyUrl = "https://kakainc.com/en/wakemusic/legal/app-store/privacy/".localStr()

// 服务协议
var kUseItemUrl = "https://kakainc.com/en/wakemusic/legal/app-store/terms/".localStr()


let avatarImage = Reasource.named(avatarDefaultName)


/// 紫色渐变色
let graderLayerColors = [UIColor.systemBlue.cgColor, UIColor.rgb(219, 0, 242).cgColor]



func UIFontBold(_ value: CGFloat) -> UIFont {
    return UIFont.init(name: "Arial Rounded MT Bold Regular", size: value) ?? UIFont.boldSystemFont(ofSize: value)
}

func UIFontLight(_ value: CGFloat) -> UIFont {
    return UIFont.init(name: "Arial Regular", size: value) ?? UIFont.systemFont(ofSize: value)
}

func UIFontNumber(_ value: CGFloat) -> UIFont {
    return UIFont.init(name: "Arial Rounded MT Bold", size: value) ?? UIFont.systemFont(ofSize: value)
}


/// Prefer the caller's window. The first connected scene may be a background window.
func kaka_layoutWindow(for view: UIView? = nil) -> UIWindow? {
    if let window = view?.window { return window }
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let active = scenes.filter { $0.activationState == .foregroundActive }
    let visible = active.isEmpty ? scenes.filter { $0.activationState == .foregroundInactive } : active
    let windows = visible.flatMap(\.windows)
    return windows.first(where: \.isKeyWindow)
        ?? windows.first(where: { !$0.isHidden && $0.windowLevel == .normal })
}

func kaka_safeAreaInsets(in view: UIView? = nil) -> UIEdgeInsets {
    if let view { return view.safeAreaInsets }
    return kaka_layoutWindow()?.safeAreaInsets ?? .zero
}

extension UIDevice {
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    public func isSmalliPhone() -> Bool {
        let deviceModel = getDeviceModel()
        let iPhoneSEModels = [
            "iPhone8,4",  // iPhone SE (1st gen)
            "iPhone12,8", // iPhone SE (2nd gen)
            "iPhone14,6"  // iPhone SE (3rd gen)
        ]
        let isSE = iPhoneSEModels.contains(deviceModel)
        // A zero bottom inset also occurs on large/folded displays and is not a
        // reliable indication of an older, small iPhone.
        guard userInterfaceIdiom == .phone else { return false }
        let size = kaka_layoutWindow()?.bounds.size ?? .zero
        let isCompactScreen = size.width > 0 && size.height > 0
            && min(size.width, size.height) <= 375 && max(size.width, size.height) <= 667
        return isSE || isCompactScreen
    }
    
}
