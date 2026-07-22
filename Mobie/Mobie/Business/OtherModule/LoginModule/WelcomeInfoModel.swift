//
//  WelcomeInfoModel.swift
//  AppLock
//
//  Created by Kaka Inc. on 2024/1/2.
//

import KakaFoundation
import AppGroupKit

struct WelcomeInfoModel {
    
    /// 首次展示磁带样式
    var isTapeStyle: Bool = false
    
    /// 是否付款页面
    var isPurchase: Bool = false
    
    /// 标题
    var title: String = ""
    
    /// 描述
    var descStr: String = ""
    
    /// 图标名称
    var iconName: String = ""
    
    /// 背景色
    var backColor: UIColor = UIColor.white
    
    
    // 数据源
    static func welcomeDataArray() -> [WelcomeInfoModel] {
        
        let model0 = WelcomeInfoModel(isTapeStyle: true, title: "", descStr: "", iconName: "", backColor: .clear)
        
        let fileStr = AudioExtension.audioSuffixs.map { $0.uppercased() }.joined(separator: ", ")
        let model1 = WelcomeInfoModel(title: "Support All Formats".localStr(), descStr: fileStr + "...", iconName: "welcome_music", backColor: UIColor.rgb(172, 162, 239))
        
        let model2 = WelcomeInfoModel(title: "Audio Fingerprint".localStr(), descStr: "Identify songs instantly via advanced audio fingerprinting. Embed metadata permanently into your tracks.".localStr(), iconName: "welcome_mp3tag", backColor: UIColor.rgb(176,196,255))
        
        let importArray: [ImportFileType] = ImportFileType.welcomeArray()
        let connectStr = importArray.map { $0.titleStr() }.joined(separator: " & ")
        let model3 = WelcomeInfoModel(title: "Connect Your Music".localStr(), descStr: connectStr, iconName: "welcome_drive", backColor: UIColor.rgb(164, 225, 174))
        
        let model4 = WelcomeInfoModel(isPurchase: true, backColor: UIColor.rgb(195, 217, 230))
                
#if Target_Mobie_Pro
        return [model1, model2, model3]
#else
        return UserInfoManager.shared.isVIP() ? [model0, model1, model2, model3] : [model0, model1, model2, model3, model4]
//        return [model1, model2, model3, model4]
#endif
    }
    
}
