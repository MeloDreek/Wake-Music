//
//  MacTabbarViewController+Play.swift
//  Mobie
//
//  Created by 张文 on 5/8/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KSPlayer

extension MacTabbarViewController: DocumentFolderWatcherDelegate {
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

        if allCount == 0 {
            let demoModel = MusicItemModel.demoMusicModel()
            KakaMusicPlayer.shared.playingMusic = demoModel
            KakaMusicPlayer.shared.musicArray = [demoModel]
            
            KakaMusicPlayer.shared.tempMusicArray = KakaMusicPlayer.shared.musicArray
            
            self.toolbarView.musicModel = demoModel
        }
    }
}


extension MacTabbarViewController: PlayingControlViewDelegate, UIPopoverPresentationControllerDelegate {
    
    func configMusicPlsyer() {
        
    }
    
    // 点击播放上一次的缓存
    func musicControlViewDidFirstPlay(view: UIView, model: MusicItemModel?) {
        guard let model = model else { return }
        if model.isLocalFile() {
            if let navVC = self.children[0] as? KakaNavigationController, let musicVC = navVC.viewControllers.first as? MusicsViewController {
                musicVC.playLastMusicCache(model)
            }
        }else{
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
            guard let model = KakaMusicPlayer.shared.playingMusic else { return }
            let tagVC = MusicTagEditorController(model)
            self.contentDict[self.selectItemType.rawValue]?.pushViewController(tagVC, animated: true)
            return
        }
        
        if kaka_IsiPhone() {
            let playlistView = MusicPlaylistView(frame: self.view.bounds)
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
        if self.selectItemType == .allMusics {
            if let navVC = self.children[0] as? KakaNavigationController, let musicVC = navVC.viewControllers.first as? MusicsViewController {
                musicVC.locationPlayingCell()
            }
        }
                
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
}

