//
//  PlayerSceneDelegate.swift
//  Mobie
//
//  Created by 张文 on 5/18/25.
//

import KakaFoundation
import AppGroupKit

class PlayerSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        self.window = UIWindow(windowScene: windowScene)
        self.window?.backgroundColor = UIColor.systemBackground
        self.window?.rootViewController = MusicPlayerViewController()
        self.window?.makeKeyAndVisible()
        
        #if targetEnvironment(macCatalyst)
        if let titlebar = windowScene.titlebar {
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
        }
//        if let sizeRestrictions = windowScene.sizeRestrictions {
//            sizeRestrictions.minimumSize = CGSize(width: 800, height: 600) // 最小尺寸
//        }
        #endif
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        debugPrint("播放器窗口被关闭")
        
        self.saveLastPlayTimeCache()
        
        self.restartMainWindow()
    }

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
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        debugPrint("窗口进入后台")
    }
    
    // 重启主窗口
    func restartMainWindow() {
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
    }
    
}



extension PlayerSceneDelegate {
    
    // 读取上次缓存的时间，含沙盒
    func readleLastCacheData() {
        
        if !MusicConfigManager.shared.isLastCache { return }
        
        guard let cacheData = try? Data(contentsOf: self.playbackInfoFilePath()) else { return }
        let model = MusicConfigManager.deserialize(from: cacheData)
        
        MusicConfigManager.shared.lastPlayTime = model?.lastPlayTime ?? 0
        MusicConfigManager.shared.lastTotalTime = model?.lastTotalTime ?? 0

        debugPrint("⌚️上次播放进度 = \(MusicConfigManager.shared.lastPlayTime)  :  \(MusicConfigManager.shared.lastTotalTime)")
        
        try? FileManager.default.removeItem(at: self.playbackInfoFilePath())
    }
    
    func saveLastPlayTimeCache() {
        
        if !MusicConfigManager.shared.isLastCache { return }
        
        let currentTime = KakaMusicPlayer.shared.currentTime
        let totalTime = KakaMusicPlayer.shared.totalTime
        
        MusicConfigManager.shared.lastPlayTime = currentTime
        MusicConfigManager.shared.lastTotalTime = totalTime
        
        let configModel = MusicConfigManager.shared

        let jsonData = configModel.toJSONString() ?? ""
        do {
            try jsonData.write(to: self.playbackInfoFilePath(), atomically: true, encoding: .utf8)
            debugPrint("写入成功 = \(self.playbackInfoFilePath().path)")
        } catch {
            debugPrint("写入失败 = \(error.localizedDescription)")
        }
    }

    private func playbackInfoFilePath() -> URL {
        let cachePath = SandboxFileManager.shared.preDownloadURL()
        return cachePath.appendingPathComponent(".last_playback.json")
    }
    
}
