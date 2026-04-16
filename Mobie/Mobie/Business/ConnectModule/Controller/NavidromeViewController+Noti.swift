//
//  NavidromeViewController+Noti.swift
//  Mobie
//
//  Created by 张文 on 1/2/25.
//

import KakaFoundation
import FilesProvider
import AppGroupKit
import ProgressHUD

extension NavidromeViewController {
    
    // 添加监听方式
    func addNotificationEvent() {
                
        // 主题色变化了
        NotificationCenter.default.addObserver(self, selector: #selector(setupNavigationItem), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        
        // 远程资源变化了
        NotificationCenter.default.addObserver(self, selector: #selector(refreshMyNavidrome), name: Notification.Name(kRemoteMusicChangedKey), object: nil)
                
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.perform(#selector(self?.needReloadTableView), with: nil, afterDelay: 0.2)
            }.store(in: &cancellables)
        
    }
    
    // 需要刷新页面
    @objc func needReloadTableView() {
        self.tableView.reloadData()
    }
    
}
