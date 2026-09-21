//
//  SceneDelegate.swift
//  Mobie
//
//  Created by 张文 on 9/22/24.
//

import KakaFoundation
import AppGroupKit
import KakaObjcKit
import KakaTaglibKit
import SwiftyDropbox
import SmartCodable
import AliyunpanSDK

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var modeCoordinator: AppModeCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        self.resetVIPConfig()
                
        self.window = UIWindow(windowScene: windowScene)
        self.window?.backgroundColor = UIColor.systemBackground
        if let window { self.modeCoordinator = AppModeCoordinator(window: window) }
        
#if targetEnvironment(macCatalyst)
        if let titlebar = windowScene.titlebar {
            titlebar.titleVisibility = AppLocalManager.shared.isFirstLaunch ? .hidden : .visible
            titlebar.toolbar = nil
        }
#endif
        
        if AppLocalManager.shared.isFirstLaunch {
            let loginVC = WelcomeViewController()
            self.window?.rootViewController = loginVC
        }else{
            self.window?.rootViewController = modeCoordinator?.restoredRootController()
        }
        
        self.window?.makeKeyAndVisible()
    }
    
    // 重制非VIP的权限
    func resetVIPConfig() {
        
#if DEBUG
        AppLocalManager.reset()
        MusicConfigManager.reset()
        ColorFontManager.reset()
        ConnectConfigManager.reset()
        DownloadManager.reset()
#endif
        
        ConnectConfigManager.updateConnectNewData()
        AppLocalManager.shared.isGuideFiveStar = false
                        
        if UserInfoManager.shared.isVIP() {
            return
        }
        
        // 防止退款后继续白嫖高级功能
        MusicConfigManager.shared.playerEngine = .avPlayer
        MusicConfigManager.shared.isTranscoding = false
        MusicConfigManager.shared.navFormats = .raw
        MusicConfigManager.shared.navMaxBitRate = .bitRate0
        
        let playerStyle = MusicConfigManager.shared.playerStyle
        if playerStyle.isTapeStyle() || playerStyle.isVinylStyle() {
            MusicConfigManager.shared.playerStyle = .defaultRect
        }
        
        var defaultModel = MusicConfigManager.shared.playbackModel
        defaultModel.backgroundType = .defaultType
        MusicConfigManager.shared.playbackModel = defaultModel
                
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        
        guard let firstURL = URLContexts.first?.url else { return }
        if Pan123DriveService.isCallback(firstURL) { return }
        if GuangyaDriveService.isCallback(firstURL) { return }
        if YandexDriveService.shared.handleCallback(firstURL) { return }
        debugPrint("跳转回来的URL = \(firstURL)")
        
        // 1️⃣ 处理 Dropbox 授权回调
        if let scheme = firstURL.scheme, scheme.contains(DropBox_ApiKey) {
            self.handleDropboxAuthCallback(URLContexts)
            return
        }
        
        // 3️⃣ 阿里云盘
        if let scheme = firstURL.scheme, scheme.contains(DropBox_ApiKey.lowercased()) {
            Aliyunpan.handleOpenURL(firstURL)
        }
        
        // 0️⃣ 处理本地文件打开（音乐文件）
        if AudioExtension.audioSuffixs.contains(firstURL.pathExtension.lowercased()) {
            self.handleLocalMusicFiles(URLContexts)
        }
        
    }
    
//    "跳转回来的URL = db-ivt8gleyydx2ghj://2/token?code=bEDM61BaluUAAAAAAAAAIWr9yIJYw3YVVDNRLFNZNdQ&state=6BC0A63B-AB9E-42FB-9DAD-41A71613D135-31164-0000008F09671A44"

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        debugPrint("窗口进入前台")
        self.removePushNotiBadge()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        self.removePushNotiBadge()
        debugPrint("窗口进入后台")
    }
    
    // 清除消息红点
    func removePushNotiBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

}

extension SceneDelegate {
    // MARK: - 处理Dropbox回调
    private func handleDropboxAuthCallback(_ URLContexts: Set<UIOpenURLContext>) {
        
        let oauthCompletion: DropboxOAuthCompletion = {
            if let authResult = $0 {
                switch authResult {
                case .success(let token):
                    if let client = DropboxClientsManager.authorizedClient {
                        client.users.getCurrentAccount().response { response, error in
                            if let account = response {
                                let dropAccount = DropboxAccount(accountId: account.accountId, name: account.name.displayName, email: account.email, emailVerified: account.emailVerified, profilePhotoUrl: account.profilePhotoUrl, disabled: account.disabled)
                                let dropboxUser = DropboxDriveUserModel(userID: token.uid, requestTime: Date().timeIntervalSince1970, accessToken: token.accessToken, refreshToken: token.refreshToken, expiresTime: token.tokenExpirationTimestamp ?? 0, account: dropAccount, path: nil)
                                
                                debugPrint("✅DropBox授权成功 = \(dropboxUser.toJSONString() ?? "")")
                                                        
                                let serverModel = ServerConfigModel(serverType: .fromDropboxDrive, dropboxUser: dropboxUser)
                                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: serverModel)
                                NotificationCenter.default.post(name: Notification.Name(kJumpConnectPageKey), object: serverModel)

                            }else{
                                let description = error?.localizedDescription ?? ""
                                (self.currentViewController()?.view ?? appKeyWindow)?.makeToast(description)
                                debugPrint("获取Dropbox信息❌: \(description)")
                            }
                        }
                    }else{
                        let dropboxUser = DropboxDriveUserModel(userID: token.uid, requestTime: Date().timeIntervalSince1970, accessToken: token.accessToken, refreshToken: token.refreshToken, expiresTime: token.tokenExpirationTimestamp ?? 0, account: nil, path: nil)
                        debugPrint("✅DropBox授权成功 = \(dropboxUser.toJSONString() ?? "")")
                                                
                        let serverModel = ServerConfigModel(serverType: .fromDropboxDrive, dropboxUser: dropboxUser)
                        ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: serverModel)
                        NotificationCenter.default.post(name: Notification.Name(kJumpConnectPageKey), object: serverModel)
                    }
                    break
                case .cancel:
                    debugPrint("Authorization flow was manually canceled by user!")
                    break
                case .error(_, let description):
                    (self.currentViewController()?.view ?? appKeyWindow)?.makeToast(description)
                    debugPrint("授权Dropbox信息❌: \(description ?? "")")
                    break
                }
            }
        }
        
        for context in URLContexts {
            // stop iterating after the first handle-able url
            if DropboxClientsManager.handleRedirectURL(context.url, includeBackgroundClient: false, completion: oauthCompletion) {
                break
            }
        }
        
    }
    
    // MARK: - 本地音乐文件处理
    private func handleLocalMusicFiles(_ URLContexts: Set<UIOpenURLContext>) {
        var tempArray = [MusicItemModel]()
         
        for context in URLContexts {
            let fileURL = context.url
            let metaData = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all)
            
            var newModel = MusicItemModel(fileURL: fileURL, sourceType: .demoFile)
            newModel.coverArt = metaData?.coverArt
            newModel.title = metaData?.title
            newModel.artist = metaData?.artist
            newModel.album = metaData?.album
            newModel.year = Int(metaData?.year ?? UInt(Date().year))
            newModel.durationSeconds = Int(metaData?.durationSeconds ?? 88)
            newModel.track = Int(metaData?.track ?? 1)
            newModel.lyricModel = metaData?.lyricModel?.convertSwiftModel()
            
            tempArray.append(newModel)
        }
        
        KakaMusicPlayer.shared.startPlayMusic(musics: tempArray, itemIndex: 0)
        
    }
}
