//
//  WakeMusicPlayer.swift
//  WakeMusicPlayer
//
//  Created by Kaka Inc. on 2024/12/19.
//

import Foundation
import AVFoundation

public class WakeMusicPlayer: NSObject {
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var completionHandler: (() -> Void)?

    /// 播放本地音频文件
    /// - Parameters:
    ///   - url: 本地音频文件的URL
    ///   - onComplete: 播放完成回调
    public func play(url: URL, onComplete: (() -> Void)? = nil) {
        stop() // 先停止之前的播放
        
        self.completionHandler = onComplete
        
        // 初始化播放器
        let item = AVPlayerItem(url: url)
        self.playerItem = item
        self.player = AVPlayer(playerItem: item)
        
        // 添加播放完成的观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        
        // 开始播放
        player?.play()
    }

    /// 停止播放
    public func stop() {
        player?.pause()
        if let item = playerItem {
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: item
            )
        }
        player = nil
        playerItem = nil
        completionHandler = nil
    }

    @objc private func playerDidFinishPlaying() {
        completionHandler?()
        stop()
    }

    deinit {
        stop()
    }
}
