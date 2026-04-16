//
//  AppDelegate+Action.swift
//  Mobie
//
//  Created by 张文 on 5/11/25.
//

import KakaFoundation
import AppGroupKit

extension AppDelegate {
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
    
    func setupCrashHandlers() {
        // 捕获 Objective-C 异常
        NSSetUncaughtExceptionHandler { exception in
            let exceptionInfo = """
            Crash Info:
            Name: \(exception.name.rawValue)
            Reason: \(exception.reason ?? "Unknown Reason")
            UserInfo: \(exception.userInfo ?? [:])
            CallStack: \(exception.callStackSymbols.joined(separator: "\n"))
            """
            
            CrashHandler.saveCrashLog(exceptionInfo) // 使用静态函数
        }
        
    }

}

struct CrashHandler {
    static func saveCrashLog(_ log: String) {
                
        let logPath = SandboxFileManager.shared.basePublicFileURL().appendingPathComponent(".app_crash.log")
        do {
            try log.write(to: logPath, atomically: true, encoding: .utf8)
            debugPrint("Crash log saved to: \(logPath)")
        } catch {
            debugPrint("Failed to save crash log: \(error.localizedDescription)")
        }
    }
}
