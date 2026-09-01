//
//  HomeTabbarViewController+Play.swift
//  Wakemusic
//
//  Created by Melo on 9/15/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KSPlayer

extension HomeTabbarViewController: DocumentFolderWatcherDelegate {
    // 新增了文件
    func documentFolderWatcherDidAddFiles(watcher: DocumentFolderWatcher, addFiles: [URL]) {
        DispatchQueue.main.async { [weak self] () in
            self?.localMusicCountChanged()
        }
    }
    
    // 删除了文件
    func documentFolderWatcherDidDeleteFiles(watcher: DocumentFolderWatcher, deleteFiles: [URL]) {
        DispatchQueue.main.async { [weak self] () in
            self?.localMusicCountChanged()
        }
    }
    
    // 本地文件有变化
    @objc func localMusicCountChanged() {
        
        let localMusics = SandboxFileManager.shared.readLocalMusicFiles().filter { $0.isSupportMusicFile(false) || $0.hasDirectoryPath }
        let remoteMusic = ConnectConfigManager.shared.selectFolderArray + ConnectConfigManager.shared.lastPlaylist
        
        let allCount = localMusics.count + remoteMusic.count
        
        let isToolBar = MusicConfigManager.shared.miniPlayerUI == .toolbarUI
        
        self.toolbarView.isHidden = !isToolBar
        self.floatingView.isHidden = isToolBar

        if allCount == 0 {
            let demoModel = MusicItemModel.demoMusicModel()
            KakaMusicPlayer.shared.playingMusic = demoModel
            KakaMusicPlayer.shared.musicArray = [demoModel]
            
            KakaMusicPlayer.shared.tempMusicArray = KakaMusicPlayer.shared.musicArray
            
            self.toolbarView.musicModel = demoModel
            self.floatingView.musicModel = demoModel
        }
    }
}


extension HomeTabbarViewController: PlayingControlViewDelegate {
    
    func configMusicPlsyer() {
        
    }
    
    
    // 点击播放上一次的缓存
    func musicControlViewDidFirstPlay(view: UIView, model: MusicItemModel?) {
        guard let model = model else { return }
        if model.isLocalFile() {
            self.selectedIndex = 0
            if let navVC = self.children[0] as? KakaNavigationController, let musicVC = navVC.viewControllers.first as? MusicsViewController {
                musicVC.playLastMusicCache(model)
            }
        }else{
            self.selectedIndex = 2
            if let navVC = self.children[2] as? KakaNavigationController, let musicVC = navVC.viewControllers.first as? NavidromeViewController {
                musicVC.playLastMusicCache(model)
            }
        }
    }
    
    // 点击进入播放页面
    func musicControlViewDidClick(view: UIView) {
        
        KakaMusicPlayer.presentPlayController(fromVC: self)
    }
    
    //  播放列表 && 音乐标签编辑器
    func musicControlViewDidPlaylistButton(view: UIView, playlistButton: UIButton) {
        
        if KakaMusicPlayer.shared.musicArray.count <= 1 && KakaMusicPlayer.shared.playingMusic?.fileSourceType == .demoFile {
            
            guard let navVC = self.children[selectedIndex] as? KakaNavigationController, let model = KakaMusicPlayer.shared.playingMusic else { return }
            
            if navVC.topViewController is MusicTagEditorController {
                navVC.topViewController?.view.kaka_playShakeAnim()
                return
            }
            
            let tagVC = MusicTagEditorController(model)
            navVC.pushViewController(tagVC, animated: true)
            return
        }
        
        if kaka_IsiPhone() {
            let playlistView = MusicPlaylistView(frame: (appKeyWindow ?? self.view).bounds)
            self.view.addSubview(playlistView)
        }else{
            let playlistVC = MusicPlaylistViewController()
            playlistVC.preferredContentSize = CGSize(width: 400.ckValue(), height: 580.ckValue())
            playlistVC.modalPresentationStyle = .popover
            let popVC = playlistVC.popoverPresentationController
            popVC?.backgroundColor = UIColor.clear
            popVC?.permittedArrowDirections = .any
            popVC?.sourceRect = playlistButton.bounds
            popVC?.sourceView = playlistButton
            self.present(playlistVC, animated: true)
        }
    }
    
    // 长按或双击
    func musicControlViewDidLongDoubleClick(view: UIView) {
        if self.selectedIndex == 0 {
            if let navVC = self.children[0] as? KakaNavigationController, let musicVC = navVC.viewControllers.first as? MusicsViewController {
                musicVC.locationPlayingCell()
            }
        }
        
        if self.selectedIndex == 2 {
            if let navVC = self.children[2] as? KakaNavigationController, let musicVC = navVC.viewControllers.first as? NavidromeViewController {
                musicVC.locationPlayingCell()
            }
        }
    }
    
}
