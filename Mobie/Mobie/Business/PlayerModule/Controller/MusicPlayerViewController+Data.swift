//
//  MusicPlayerViewController+Data.swift
//  Mobie
//
//  Created by 张文 on 5/27/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

extension MusicPlayerViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return dataArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let group = dataArray[indexPath.section]
        switch group {
        case .basic:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlayerBasicCollectCell", for: indexPath) as! PlayerBasicCollectCell
            cell.delegate = self
            return cell
        case .tape:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlayerTapeCollectCell", for: indexPath) as! PlayerTapeCollectCell
            cell.tapeView.delegate = self
            cell.delegate = self
            return cell
        case .vinyl:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlayerVinylCollectCell", for: indexPath) as! PlayerVinylCollectCell
            cell.delegate = self
            return cell
        case .listLyric:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlayerLyricCollectCell", for: indexPath) as! PlayerLyricCollectCell
            cell.model = KakaMusicPlayer.shared.playingMusic
            cell.delegate = self
            return cell
        case .bigLyrics:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HorizonLyricsViewCell", for: indexPath) as! HorizonLyricsViewCell
            cell.delegate = self
            return cell
        case .playlist:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlayerQueueCollectCell", for: indexPath) as! PlayerQueueCollectCell
            cell.onClose = { [weak self] in self?.setPlaylistVisible(false) }
            return cell
        case .moreConfig:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlayerMoreConfigCollectCell", for: indexPath) as! PlayerMoreConfigCollectCell
            cell.actionsProvider = { [weak self] in self?.playDefaultControl.moreMenu() }
            cell.refresh()
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
#if !targetEnvironment(macCatalyst)
        if OrientationManager.shared.isLandscape {
            return
        }
        
        let itemType = dataArray[indexPath.section]
        guard itemType != .playlist && itemType != .moreConfig else { return }
        let isShowBigLyric = itemType == .basic || itemType == .tape || itemType == .vinyl
        
        self.lyricCollectionCellClick(isShowBigLyric)
#endif
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return self.flowLayout.minimumInteritemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return self.flowLayout.minimumLineSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return self.flowLayout.itemSize
    }
    
    func lyricCollectionCellClick(_ isShowBigLyric: Bool) {
        if isShowingMoreConfig { setMoreConfigVisible(false) }
        if isShowingPlaylist { setPlaylistVisible(false) }
        
        guard let playingMusic = KakaMusicPlayer.shared.playingMusic else { return }
        let status = KakaMusicPlayer.shared.playbackStatus
                
        if !playingMusic.isLocalFile() && (status == .preparing || status == .buffering || status == .error) {
            self.playDefaultControl.loadingView.kaka_playShakeAnim()
            self.playDefaultControl.playButton.kaka_playShakeAnim()
            
            self.playTapeControl.loadingView.kaka_playShakeAnim()
            self.playTapeControl.playButton.kaka_playShakeAnim()
            return
        }
        
        self.collectionView.contentOffset = CGPoint(x: isShowBigLyric ? self.flowLayout.itemSize.width : 0, y: 0)
        
//        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.01) { [weak self] () in
//            self?.hiddenOrShowBottomControl()
//        }
    }
    
    @objc func hiddenOrShowBottomControl() {
        
//        guard let lyricCell = self.collectionView.cellForItem(at: IndexPath(row: 0, section: 1)) as? PlayerLyricCollectCell else {
//            return
//        }
//
//        let isShowBigLyric = abs(self.collectionView.contentOffset.x - self.flowLayout.itemSize.width) < 10
        
//        lyricCell.isShowControl = !isShowBigLyric
        
//        let style = MusicConfigManager.shared.playerStyle
//        var controlView: UIView?
//        if style.isDefaultStyle() {
//            controlView = self.playDefaultControl
//        }
//        
//        if style.isTapeStyle() {
//            controlView = self.playTapeControl
//        }
//        
//        if style.isVinylStyle() {
//            controlView = self.playVinylControl
//        }
//        
//        controlView?.isHidden = isShowBigLyric
    }
    
}
