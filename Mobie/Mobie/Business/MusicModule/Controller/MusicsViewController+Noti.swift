//
//  MusicsViewController+Noti.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/27.
//

import KakaFoundation
import AppGroupKit
import AdSupport
import Combine
import AppTrackingTransparency

extension MusicsViewController {
    func addNotificationEvent() {
        
        self.perform(#selector(requestIDFAString), with: nil, afterDelay: 5)
        
        // 主题色变化了
        NotificationCenter.default.addObserver(self, selector: #selector(setupNavigationItem), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        
        // 编辑信息通知
        NotificationCenter.default.addObserver(self, selector: #selector(refreshDataAction), name: Notification.Name(kLocalMusicChangedKey), object: nil)
        
        // 开始折扣倒计时
        NotificationCenter.default.addObserver(self, selector: #selector(setupNavigationItem), name: Notification.Name(rawValue: kStartDiscountPriceKey), object: nil)
                
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.perform(#selector(self?.needReloadTableView), with: nil, afterDelay: 0.2)
            }.store(in: &cancellables)
        
        // 显示缺失的音乐标签
        MusicConfigManager.shared.$isShowMissTag
            .receive(on: DispatchQueue.main)
            .sink { [weak self] engine in
                self?.needReloadTableView()
            }.store(in: &cancellables)
        
    }
    
    // 立马刷新页面
    @objc func needReloadTableView() {
        self.tableView.reloadData()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.tableView.reloadData()
    }
    
    // 播放上一次缓存的歌曲
    func playLastMusicCache(_ music: MusicItemModel?) {
        guard let model = music else { return }
        
        let index = self.viewModel.playingMusicIndex(model)
        self.clickMusicItem(index)
    }
    
    // 获取IDFA
    @objc func requestIDFAString() {
        ATTrackingManager.requestTrackingAuthorization { status in
            if status == .authorized {
                let idfaStr = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                debugPrint("IDFA = \(idfaStr)")
            }else{
                debugPrint("请在设置-隐私-跟踪中允许App请求跟踪: \(status)")
            }
        }
    }

}

