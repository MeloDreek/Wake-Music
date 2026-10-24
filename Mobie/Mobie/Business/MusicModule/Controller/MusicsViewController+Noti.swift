//
//  MusicsViewController+Noti.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2024/1/27.
//

import KakaFoundation
import AppGroupKit
import Combine

extension MusicsViewController {
    func addNotificationEvent() {
        if self.viewModel.isBaseDoc {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard self?.viewIfLoaded?.window != nil else { return }
                TrackingAuthorizationManager.shared.requestIDFAAuthorization()
            }
        }
        
        // 主题色变化了
        NotificationCenter.default.addObserver(self, selector: #selector(setupNavigationItem), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        
        // 编辑信息通知
        NotificationCenter.default.addObserver(self, selector: #selector(refreshDataAction), name: Notification.Name(kLocalMusicChangedKey), object: nil)
        
        // 购买成功后隐藏高级版入口
        NotificationCenter.default.addObserver(self, selector: #selector(setupNavigationItem), name: Notification.Name(rawValue: kPurchageSuccessKey), object: nil)
                
        
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
    
}
