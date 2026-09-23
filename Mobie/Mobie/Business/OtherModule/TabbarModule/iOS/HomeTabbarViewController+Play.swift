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
        self.toolbarView.isHidden = false

        let player = KakaMusicPlayer.shared
        if player.playingMusic == nil {
            let demoModel = MusicItemModel.demoMusicModel()
            player.playingMusic = demoModel
            player.musicArray = [demoModel]
            player.tempMusicArray = [demoModel]
            
            self.toolbarView.musicModel = demoModel
        } else if let current = player.playingMusic,
                  current.fileSourceType == .demoFile,
                  player.musicArray.isEmpty {
            player.musicArray = [current]
            player.tempMusicArray = [current]
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
            // Remote playback belongs to the shared player, not a legacy
            // controller in Classic's Connect tab.
            KakaMusicPlayer.shared.startPlayMusic(musics: [model], itemIndex: 0)
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
    }
    
}
