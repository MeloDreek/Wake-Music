//
//  ConfigInfoKey.swift
//  Kaka
//
//  Created by Kaka Inc. on 2022/9/20.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit



// 搜索App Store：https://itunes.apple.com/search?term=关键词&country=CN&media=software
// APP详情：https://itunes.apple.com/lookup?id=6444247541
// APP评论：https://itunes.apple.com/rss/customerreviews/id=6444247541/json


// 联系邮箱
//let companyEmail = "MeloDreek@gmail.com"
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


func kaka_safeAreaInsets() -> UIEdgeInsets {
    let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
    let edgeInsets = windowScene?.windows.first?.safeAreaInsets ?? UIWindow().safeAreaInsets
    return edgeInsets
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
        let isOld = kaka_safeAreaInsets().bottom == 0
        
        return isSE || isOld
    }
    
}
