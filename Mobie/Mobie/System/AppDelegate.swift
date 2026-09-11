//
//  AppDelegate.swift
//  Mobie
//
//  Created by 张文 on 9/22/24.
//

import KakaFoundation
import KakaUIKit
import RevenueCat
import FirebaseCore
import FirebaseCrashlytics
#if canImport(IQKeyboardManagerSwift) && canImport(IQKeyboardToolbarManager)
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager
#endif
import KakaObjcKit
import AppGroupKit
import Toast
import ProgressHUD
import GoogleSignIn
import SwiftyDropbox
import AliyunpanSDK
//import YandexLoginSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // 程序入口
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.readleLastCacheData()
        self.setupAppConfig()
        
        
        
#if targetEnvironment(macCatalyst)
        self.perform(#selector(restartMainWindow), with: nil, afterDelay: 1)
#endif
        
        return true
    }
    
    
    func setupAppConfig() {
        
//        let toolBarAppearance = UIToolbarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
//        toolBarAppearance.configureWithDefaultBackground()
//        UIToolbar.appearance().standardAppearance = toolBarAppearance
//        UIToolbar.appearance().tintColor = appMainColor
        
//        UIView.appearance().tintColor = appMainColor
        
        self.perform(#selector(prefetchSomeTask), with: nil, afterDelay: 1)
        
#if DEBUG
        Purchases.logLevel = .debug
#endif
        
#if !Target_Mobie_Pro
        let userID = UserInfoManager.shared.cloudUserID
        Purchases.configure(withAPIKey: "appl_dzjkbczTtjkzVgFisXfYmRLPXXn", appUserID: userID)
#endif
        
        var toastStyle = ToastManager.shared.style
        toastStyle.cornerRadius = 2.ckValue()
        toastStyle.backgroundColor = UIColor.label
        toastStyle.verticalPadding = 12.ckValue()
        toastStyle.horizontalPadding = 18.ckValue()
        toastStyle.titleFont = UIFontLight(15.ckValue())
        toastStyle.messageFont = UIFontLight(15.ckValue())
        toastStyle.titleAlignment = .center
        toastStyle.messageAlignment = .center
        toastStyle.titleColor = UIColor.systemBackground
        toastStyle.messageColor = UIColor.systemBackground
        ToastManager.shared.position = .center
        ToastManager.shared.style = toastStyle
        
        ProgressHUD.animationType = .circleArcDotSpin
        ProgressHUD.fontStatus = UIFontBold(18.ckValue())
        ProgressHUD.fontBannerTitle = ProgressHUD.fontStatus
        ProgressHUD.fontBannerMessage = ProgressHUD.fontStatus
        ProgressHUD.mediaSize = 100.ckValue()
        ProgressHUD.marginSize = 50.ckValue()
        
#if canImport(IQKeyboardManagerSwift) && canImport(IQKeyboardToolbarManager)
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardToolbarManager.shared.isEnabled = true
#endif
        
        MusicConfigManager.shared.sleepTime = nil
        MusicConfigManager.shared.playRate = 1
        
        self.supportArabic()
        
        AppLocalManager.shared.activateAllBookmarks()
        
        GIDSignIn.sharedInstance.restorePreviousSignIn()
        
        DropboxClientsManager.setupWithAppKey(DropBox_ApiKey)
        
        // pCloud uses per-account clients in PCloudDriveService; no shared SDK client is required.
        
//        do {
//            try YandexLoginSDK.shared.activate(with: Yandex_ClientID, authorizationStrategy: .default)
//            debugPrint("SDK激活成功✅")
//        } catch {
//            debugPrint("❌初始化Yandex失败：\(error.localizedDescription)")
//        }
                
        // 开发阶段不自动上传符号表
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        // 安全设置 Custom Keys，防止 nil 导致字典初始化崩溃
        Crashlytics.crashlytics().setCustomValue(PhoneSetManager.regionCode(), forKey: "region")
        Crashlytics.crashlytics().setCustomValue(PhoneSetManager.langugeCode(), forKey: "language")
        Crashlytics.crashlytics().setCustomValue(kaka_osType().rawValue, forKey: "OS")
        Crashlytics.crashlytics().setCustomValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "", forKey: "app_version")
        
        
    }
    
    // 预加载任务
    @objc func prefetchSomeTask() {
        AppStoreKitManager.shared.refresRemoteProductsPrice()
    }
    
    func supportArabic() {
        let semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? UISemanticContentAttribute.forceRightToLeft : UISemanticContentAttribute.forceLeftToRight
        UIView.appearance().semanticContentAttribute = semanticContentAttribute
        UISearchBar.appearance().semanticContentAttribute = semanticContentAttribute
        
    }
    
    // 重启主窗口
    @objc func restartMainWindow() {
                
        var playerScene: UIScene?
        for scene in UIApplication.shared.connectedScenes {
            if let addScene = scene as? UIWindowScene {
                let configuration = addScene.session.configuration
                if configuration.name == "MusicPlayerViewController" {
                    playerScene = scene
                }
            }
        }
        // 检查是否还有主窗口，没有就重启一个
        let alreadyHasMain = UIApplication.shared.connectedScenes.contains {
            guard let session = $0.session.configuration.name else { return false }
            return session == "MainConfiguration"
        }

        if !alreadyHasMain {
            let userActivity = NSUserActivity(activityType: "MainConfiguration")
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil, errorHandler: { error in
                debugPrint("重新打开主窗口失败：\(error.localizedDescription)")
            })
        }
        
        // 关闭播放窗口
        guard let currentSession = playerScene?.session else { return }
        UIApplication.shared.requestSceneSessionDestruction(currentSession, options: nil, errorHandler: { error in
            debugPrint("关闭主窗口失败: \(error.localizedDescription)")
        })
        
    }

    // MARK:  多窗口的生命周期
    
    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        
        let activityType = options.userActivities.first?.activityType
        if activityType == "MusicPlayerViewController" {
            let htmlConfig = UISceneConfiguration(name: activityType, sessionRole: connectingSceneSession.role)
            return htmlConfig
        } else {
            let defaultConfig = UISceneConfiguration(name: "MainConfiguration", sessionRole: connectingSceneSession.role)
            return defaultConfig
        }
        
    }
    
    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        return false
    }
    
    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        return false
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        debugPrint("⏰即将进入后台")
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // 3D Touch
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        debugPrint("3D touch = \(shortcutItem.localizedTitle)")
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        
        let currentVC = self.currentViewController()
        if (currentVC is MusicPlayerViewController) {
            return .all
        }else{
            return .all
        }
        
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
    }
    
    // 程序即将被关闭
    func applicationWillTerminate(_ application: UIApplication) {
        
        self.saveLastPlayTimeCache()
                
    }
    
    
}
