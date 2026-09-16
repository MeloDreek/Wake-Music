//
//  MusicPlayerViewController+Action.swift
//  Wakemusic
//
//  Created by Melo on 9/1/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaPhotoBrowser
import ZLImageEditor
import KakaTaglibKit
import Kingfisher
import StoreKit
import KSPlayer

extension MusicPlayerViewController {
    func hiddenNavgationUI() {
        if let navigationBar = self.navigationController?.navigationBar {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.tintColor = UIColor.white
            navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        }
    }
    
    func configMusicPlayer() {
        // 播放器样式
        MusicConfigManager.shared.$playerStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                self?.refreshUIViewAction()
            }.store(in: &cancellables)
        
        // 进入横向大歌词
        OrientationManager.shared.$isShowBigLyric
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isShowBigLyric in
                self?.deviceOrienChanged()
            }
            .store(in: &cancellables)
        
        // 屏幕朝向变化了
        OrientationManager.shared.$isLandscape
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLandscape in
                self?.grayView.isHidden = (isLandscape && kaka_IsiPhone()) || kaka_IsMacOS()
                self?.deviceOrienChanged()
            }
            .store(in: &cancellables)
        
        // 当前播放的音乐
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.perform(#selector(self?.playingMusicChanged), with: nil, afterDelay: 0.2)
            }.store(in: &cancellables)

    }
    
    @objc func deviceOrienChanged() {
        self.collectionView.collectionViewLayout.invalidateLayout()
        self.viewDidLayoutSubviews()
        self.refreshUIViewAction()
#if !targetEnvironment(macCatalyst)
        self.panModalSetNeedsLayoutUpdate()
#endif
    }
    
    // 当前音乐模型变化了
    @objc func playingMusicChanged() {
        guard let model = KakaMusicPlayer.shared.playingMusic else { return }
                
        self.serverModel = nil
        
        if let webdavUser = model.webFileModel?.webdavUser {
            self.serverModel = ServerConfigModel(serverType: .fromWebDAV, webdavUser: webdavUser)
        }
        
        if let navUser = model.navidromeSong?.navUser {
            self.serverModel = ServerConfigModel(serverType: model.fileSourceType, navUser: navUser)
        }
        
        if let baiduUser = model.baiduFileModel?.baiduUser {
            self.serverModel = ServerConfigModel(serverType: model.fileSourceType, baiduUser: baiduUser)
        }
        
        self.playDefaultControl.moreButton.menu = self.playTapeControl.moreMenu()
        self.playTapeControl.moreButton.menu = self.playTapeControl.moreMenu()
    }
    
    // 布局变化了
    func refreshUIViewAction() {
        
        let isFullScreen = OrientationManager.shared.isLandscape
        let isShowBigLyric = OrientationManager.shared.isShowBigLyric
        let style = MusicConfigManager.shared.playerStyle
        
        if isShowingPlaylist {
            // Keep the queue above the existing left-hand transport in split layouts.
            self.dataArray = isFullScreen ? [.playlist, .listLyric] : [.playlist]
            self.flowLayout.itemSize = CGSizeMake(contentView.width / (isFullScreen ? 2 : 1), contentView.height)
            self.playDefaultControl.isHidden = false
            self.playTapeControl.isHidden = true
        } else if isShowBigLyric && !kaka_IsMacOS() {
            self.dataArray = [.bigLyrics]
            self.flowLayout.itemSize = CGSizeMake(contentView.width, contentView.height)
            
            self.playDefaultControl.isHidden = true
            self.playTapeControl.isHidden = true
//            self.playVinylControl.isHidden = true
        }else{
            if style.isVinylStyle() {
                self.dataArray = [.vinyl, .listLyric]
                self.flowLayout.itemSize = CGSizeMake(contentView.width / (isFullScreen ? 2 : 1), contentView.height)
            }
            
            if style.isTapeStyle() {
                self.dataArray = [.tape, .listLyric]
                self.flowLayout.itemSize = CGSizeMake(contentView.width / (isFullScreen ? 2 : 1), contentView.height)
            }
            
            if style.isDefaultStyle() {
                self.dataArray = [.basic, .listLyric]
                self.flowLayout.itemSize = CGSizeMake(contentView.width / (isFullScreen ? 2 : 1), contentView.height)
            }
            
            self.playDefaultControl.isHidden = style.isTapeStyle()
            self.playTapeControl.isHidden = !style.isTapeStyle()
//            self.playVinylControl.isHidden = !style.isVinylStyle()
        }
        
        self.collectionView.reloadData()
        if isShowingPlaylist { self.collectionView.contentOffset = .zero }
        let queueButton = self.playDefaultControl.playlistButton
        queueButton.tintColor = .white
        queueButton.backgroundColor = isShowingPlaylist ? UIColor.white.withAlphaComponent(0.18) : .clear
        queueButton.layer.cornerRadius = queueButton.bounds.height / 2
        queueButton.accessibilityLabel = "Queue.Title".localStr()
        queueButton.accessibilityTraits = isShowingPlaylist ? [.button, .selected] : .button
        queueButton.setImage(UIImage(systemName: isShowingPlaylist ? "list.bullet" : "list.triangle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 21, weight: .medium)), for: .normal)
        
#if !targetEnvironment(macCatalyst)
        self.panModalSetNeedsLayoutUpdate()
#endif
    }

    func setPlaylistVisible(_ visible: Bool) {
        guard visible != isShowingPlaylist else { return }
        if visible {
            returnToLyricsAfterQueue = !OrientationManager.shared.isLandscape &&
                abs(collectionView.contentOffset.x - flowLayout.itemSize.width) < 10
        }
        isShowingPlaylist = visible
        refreshUIViewAction()
        collectionView.layoutIfNeeded()
        if !visible {
            collectionView.contentOffset = CGPoint(x: returnToLyricsAfterQueue && !OrientationManager.shared.isLandscape && dataArray.contains(.listLyric) ? flowLayout.itemSize.width : 0, y: 0)
        }
    }
    
    // 睡眠计时器
    @objc func setupSleepTimer() {
        let timerVC = PlayerTimerViewController()
        if kaka_IsiPhone() {
            self.presentPanModal(timerVC)
        }else{
            self.present(timerVC, animated: true)
        }
    }
    
    // 自定义铃声
    @objc func setupAudioRing() {
        guard let musicModel = KakaMusicPlayer.shared.playingMusic else { return }
        let timerVC = PlayerRingViewController(musicModel)
        if kaka_IsiPhone() {
            self.presentPanModal(timerVC)
        }else{
            self.present(timerVC, animated: true)
        }
    }
    
    // 声道支持页面
    @objc func setupAudioChannel() {
        let timerVC = AudioChannelViewController()
        if kaka_IsiPhone() {
            self.presentPanModal(timerVC)
        }else{
            self.present(timerVC, animated: true)
        }
    }
    
    // 歌词字体设置
    @objc func lyricSetButtonClick() {
        let timerVC = LyricSetViewController()
        let navVC = KakaNavigationController(rootViewController: timerVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    // 播放器引擎
    func presentPlayerEngine() {
        let engingVC = PlayerEngineViewController()
        let navVC = KakaNavigationController(rootViewController: engingVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    // 播放器样式
    func presentPlayerStyle() {
        let engingVC = PlayerStyleViewController()
        let navVC = KakaNavigationController(rootViewController: engingVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
//#warning("模拟mock数据")
//#if DEBUG
//        navVC.modalPresentationStyle = .fullScreen
//#endif
        self.present(navVC, animated: true)
    }
    
    // 播放器背景
    func presentPlayerBackground() {
        let engingVC = PlayBackgroundListController()
        let navVC = KakaNavigationController(rootViewController: engingVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
//#warning("模拟mock数据")
//#if DEBUG
//        navVC.modalPresentationStyle = .fullScreen
//#endif
        self.present(navVC, animated: true)
    }
    
    // 设置横竖屏
    @objc func forceSetDeviceOrientation() {
        
#if !targetEnvironment(macCatalyst)
        let isLandscape = OrientationManager.shared.isLandscape

        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            
            let targetScape = isLandscape ? UIInterfaceOrientationMask.portrait : UIInterfaceOrientationMask.landscape
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: targetScape)) { error in
                debugPrint("切换失败: \(error.localizedDescription)")
                self.view.makeToast(error.localizedDescription)
                if !kaka_IsiPad() {
                    OrientationManager.shared.forceUpdate(to: false)
                    OrientationManager.shared.isShowBigLyric = false
                }
            }
            
            self.setNeedsUpdateOfSupportedInterfaceOrientations()
            self.navigationController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                        
        } else {
            let targetOrientation = isLandscape ? UIInterfaceOrientation.portrait : UIInterfaceOrientation.landscapeRight
            UIDevice.current.setValue(targetOrientation.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
            UINavigationController.attemptRotationToDeviceOrientation()
        }
#endif
    }
    
    // 前往音乐标签编辑器
    @objc func presentMusicTagController() {
        guard var model = KakaMusicPlayer.shared.playingMusic else { return }
        
        if let cacheURL = SandboxFileManager.shared.getDownloadPlayURL(model) {
            model.mediaPlayURL = cacheURL
        }
        
        if model.fileSourceType == .demoFile {
            self.view.kaka_playShakeAnim()
            return
        }
        
        if !model.mediaPlayURL.isFileURL {
            self.showTwoAlert(message: "Only available for offline music. Download to local storage and edit?".localStr(), confirm: "Download".localStr()) {
                DownloadManager.shared.addMusicModel([model])
                self.view.makeToast("Added to Downloads".localStr())
            }
            return
        }

        let tagVC = MusicTagEditorController(model)
        tagVC.onEditCallback = { [weak self] (editModel) in
            KakaMusicPlayer.shared.playingMusic = editModel
            KakaMusicPlayer.shared.updateNowPlayingInfo(musicModel: editModel)
            self?.refreshUIViewAction()
        }
        let navVC = KakaNavigationController(rootViewController: tagVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    // 添加到歌单
    @objc func addToLocalPlaylist() {
        guard let model = KakaMusicPlayer.shared.playingMusic else { return }
        
        if model.fileSourceType == .demoFile {
            self.view.kaka_playShakeAnim()
            return
        }
        
        if !model.mediaPlayURL.isFileURL {
            self.showTwoAlert(message: "Only available for offline music. Download to local storage and edit?".localStr(), confirm: "Download".localStr()) {
                DownloadManager.shared.addMusicModel([model])
                self.view.makeToast("Added to Downloads".localStr())
            }
            return
        }
        
        let playlist = SelectPlaylistController(selectType: .selectPlaylist)
        playlist.onLocalBlock = { [weak self] (folderURL) in
            guard let wSelf = self else { return }
            do {
                let downloadName = model.filePathName() + model.addPathExtension()
                
                let targetURL = folderURL.appendingPathComponent(downloadName)
                try FileManager.default.moveItem(at: model.mediaPlayURL, to: targetURL)
                self?.view.makeToast("Successful".localStr())
            } catch {
                wSelf.view.makeToast(error.localizedDescription)
            }
        }
        
        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
        
    }
    
    // 写入歌词
    func setLyricContent(model: MusicItemModel, content: String) {
                
        if model.mediaPlayURL.isFileURL {
            let success = TaglibMetadataParser.setLyris(content, toFileURL: model.mediaPlayURL)
            if success {
//                appKeyWindow?.makeToast("Embedded Success".localStr())
                var newModel = model
                newModel.lyricModel = TaglibMetadataParser.parseSynchronizedLyrics(content).convertSwiftModel()
                SandboxFileManager.shared.writeMusicLRCLyric(model: newModel, lyricStr: content) { vURL in
                    KakaMusicPlayer.shared.playingMusic = newModel
                    self.guideFiveStarRating()
                } fail: { [weak self] error in
                    self?.view.makeToast(error.localizedDescription)
                }
                
            }else{
                self.perform(#selector(showEmbeddedFailed), with: nil, afterDelay: 1.5)
            }
            
            debugPrint("写入歌词 = \(success)")
        }else{
            var newModel = model
            newModel.lyricModel = TaglibMetadataParser.parseSynchronizedLyrics(content).convertSwiftModel()
            SandboxFileManager.shared.writeMusicLRCLyric(model: newModel, lyricStr: content) { vURL in
                KakaMusicPlayer.shared.playingMusic = newModel
            } fail: { [weak self] error in
                self?.view.makeToast(error.localizedDescription)
            }
        }
        
    }
    
    // 引导好评
    @objc func guideFiveStarRating() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
    
    @objc func showEmbeddedFailed() {
        self.showOneAlert(title: "Embedded Failed".localStr(), message: "This format does not support embedded music metadata. We recommend using common audio formats such as MP3, FLAC, M4A, or WAV.".localStr(), confirm: "OK".localStr())
    }
}
