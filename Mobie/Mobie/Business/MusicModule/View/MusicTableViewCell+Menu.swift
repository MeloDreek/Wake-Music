//
//  MusicTableViewCell+Menu.swift
//  Mobie
//
//  Created by 张文 on 5/12/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

// 1️⃣本地音乐
extension MusicTableViewCell {
    
    func autoTagButton() -> UIButton {
        LocalMusicAccessory.autoTagButton { [weak self] action in
            guard let self, let model = self.musicModel else { return }
            self.delegate?.musicTableCell(cell: self, model: model, action: action)
        }
    }

    func localButton() -> UIButton {
        guard let model = musicModel else { return UIButton(type: .custom) }
        return LocalMusicAccessory.localButton(model: model) { [weak self] action in
            guard let self, let model = self.musicModel else { return }
            self.delegate?.musicTableCell(cell: self, model: model, action: action)
        }
    }
}

/// Shared by local music rows and the compact collection-detail rows.
enum LocalMusicAccessory {
    static func button(model: MusicItemModel, action: @escaping (MusicActionType) -> Void) -> UIButton {
        model.isFullMusicTag() ? localButton(model: model, action: action) : autoTagButton(action: action)
    }

    static func autoTagButton(action: @escaping (MusicActionType) -> Void) -> UIButton {
        let view = UIButton(type: .custom)
        view.size = CGSizeMake(50.ckValue(), 50.ckValue())
        view.setImage(Reasource.systemNamed("touchid", color: appMainColor), for: .normal)
        view.accessibilityLabel = MusicActionType.audioFinger.titleStr()
        view.addAction(UIAction { _ in action(.audioFinger) }, for: .touchUpInside)
        return view
    }

    static func localButton(model: MusicItemModel, action: @escaping (MusicActionType) -> Void) -> UIButton {
        let view = UIButton(type: .custom)
        view.showsMenuAsPrimaryAction = true
        view.menu = localMenu(model: model, action: action)
        view.size = CGSizeMake(45.ckValue(), 45.ckValue())
        view.setImage(MusicCellType.local.iconImage(), for: .normal)
        view.accessibilityLabel = "More".localStr()
        return view
    }
    
    static func localMenu(model: MusicItemModel, action: @escaping (MusicActionType) -> Void) -> UIMenu {
        
        // 音频指纹识别
        let audioFingerAction = UIAction(title: MusicActionType.audioFinger.titleStr(), image: MusicActionType.audioFinger.iconImage()) { _ in
            action(.musictag)
        }
        
        let musictagMenu = UIMenu(title: "", options: .displayInline, children: [audioFingerAction])
        
        // 喜欢
        let likeType = model.isFlagFavorite() ? MusicActionType.removeFavirote : MusicActionType.addFavirote
        let likeItem = UIAction(title: likeType.titleStr(), image: likeType.iconImage()) { _ in
            action(.addFavirote)
        }
        
        // 移动到其他歌单
        let playlistAction = UIAction(title: MusicActionType.addPlaylist.titleStr(), image: MusicActionType.addPlaylist.iconImage()) { _ in
            action(.addPlaylist)
        }
        
        let otherMenu = UIMenu(title: "", options: .displayInline, children: [likeItem, playlistAction])
        
        // 在Finder中显示
        let finderAction = UIAction(title: MusicActionType.showInFinder.titleStr(), image: MusicActionType.showInFinder.iconImage()) { _ in
            action(.showInFinder)
        }
        // 删除
        let deleteAction = UIAction(title: MusicActionType.deleteItem.titleStr(), image: MusicActionType.deleteItem.iconImage(), attributes: .destructive) { _ in
            action(.deleteItem)
        }
        
        let deleteMenu = UIMenu(title: "", options: .displayInline, children: kaka_IsMacOS() ? [finderAction, deleteAction] : [deleteAction])
        
        let menu = UIMenu(title: model.mediaPlayURL.lastPathComponent, image: UIImage(systemName: "ellipsis"), identifier: nil, options: [], children: [musictagMenu, otherMenu, deleteMenu])
        
        return menu
    }
    
}

// 2️⃣下载页面
extension MusicTableViewCell {
    func downloadButton() -> UIButton {
        let view = UIButton(type: .custom)
        view.size = CGSizeMake(45.ckValue(), 45.ckValue())
        view.setImage(MusicCellType.download.iconImage(), for: .normal)
        view.addTarget(self, action: #selector(downloadButtonClick), for: .touchUpInside)
        return view
    }
    
    @objc private func downloadButtonClick() {
        guard let model = self.musicModel else { return }
        self.delegate?.musicTableCell(cell: self, model: model, action: .download)
    }
    
}

// 网盘页面
extension MusicTableViewCell {
    
    func cloudDriveButton() -> UIButton {
        let view = UIButton(type: .custom)
        view.size = CGSizeMake(45.ckValue(), 45.ckValue())
        view.setImage(MusicActionType.download.iconImage(), for: .normal)
        view.accessibilityLabel = MusicActionType.download.titleStr()
        view.accessibilityIdentifier = "music.cloudDrive.download"
        view.addTarget(self, action: #selector(downloadButtonClick), for: .touchUpInside)
        return view
    }
    
}

// 4️⃣一般的大型Navidrome服
extension MusicTableViewCell {
    func largenavBUtton() -> UIButton {
        let view = UIButton(type: .custom)
        view.showsMenuAsPrimaryAction = true
        view.menu = self.largenavMenu()
        view.size = CGSizeMake(45.ckValue(), 45.ckValue())
        view.setImage(MusicCellType.navidromeTrack.iconImage(), for: .normal)
        return view
    }
        
    private func largenavMenu() -> UIMenu {
        
        guard let model = self.musicModel else { return UIMenu() }
        
        // 喜欢/不喜欢
        let likeItem: MusicActionType = model.isFlagFavorite() ? .removeFavirote : .addFavirote
        let likeAction = UIAction(title: likeItem.titleStr(), image: likeItem.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: likeItem)
        }
        
        // 添加到歌单
        let playlistAction = UIAction(title: MusicActionType.addPlaylist.titleStr(), image: MusicActionType.addPlaylist.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .addPlaylist)
        }
        
        let actionMenu = UIMenu(title: "", options: .displayInline, children: [likeAction, playlistAction])
        
        
        // 艺术家
        let artistAction = UIAction(title: MusicActionType.artistDetial.titleStr(), image: MusicActionType.artistDetial.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .artistDetial)
        }
                
        // 专辑
        let albumAction = UIAction(title: MusicActionType.albumDetial.titleStr(), image: MusicActionType.albumDetial.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .albumDetial)
        }
                
        let detialMenu = UIMenu(title: "", options: .displayInline, children: [artistAction, albumAction])

        // 下载
        let downloadAction = UIAction(title: MusicActionType.download.titleStr(), image: MusicActionType.download.iconImage(), attributes: .destructive) { [weak self] (_) in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .download)
        }
        
        let downloadMenu = UIMenu(title: "", options: .displayInline, children: [downloadAction])
        
        let menu = UIMenu(title: self.musicModel.showTitleName(), image: UIImage(systemName: "ellipsis"), identifier: nil, options: [], children: [actionMenu, detialMenu, downloadMenu])
        
        return menu
        
    }
    
}

// 6️⃣艺术家详情页
extension MusicTableViewCell {
    func navartistBUtton() -> UIButton {
        let view = UIButton(type: .custom)
        view.showsMenuAsPrimaryAction = true
        view.menu = self.navartistMenu()
        view.size = CGSizeMake(45.ckValue(), 45.ckValue())
        view.setImage(MusicCellType.navArtistDetial.iconImage(), for: .normal)
        return view
    }
        
    private func navartistMenu() -> UIMenu {
        
        guard let model = self.musicModel else { return UIMenu() }
        
        // 喜欢/不喜欢
        let likeItem: MusicActionType = model.isFlagFavorite() ? .removeFavirote : .addFavirote
        let likeAction = UIAction(title: likeItem.titleStr(), image: likeItem.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: likeItem)
        }
        
        // 添加到歌单
        let playlistAction = UIAction(title: MusicActionType.addPlaylist.titleStr(), image: MusicActionType.addPlaylist.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .addPlaylist)
        }
        
        let actionMenu = UIMenu(title: "", options: .displayInline, children: [likeAction, playlistAction])
        
        
        // 下载
        let downloadAction = UIAction(title: MusicActionType.download.titleStr(), image: MusicActionType.download.iconImage(), attributes: .destructive) { [weak self] (_) in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .download)
        }
        
        let downloadMenu = UIMenu(title: "", options: .displayInline, children: [downloadAction])
        
        let menu = UIMenu(title: self.musicModel.showTitleName(), image: UIImage(systemName: "ellipsis"), identifier: nil, options: [], children: [actionMenu, downloadMenu])
        
        return menu
    }
    
}

// 7️⃣歌单详情页
extension MusicTableViewCell {
    func navplaylistBUtton() -> UIButton {
        let view = UIButton(type: .custom)
        view.showsMenuAsPrimaryAction = true
        view.menu = self.navplaylistMenu()
        view.size = CGSizeMake(45.ckValue(), 45.ckValue())
        view.setImage(MusicCellType.navPlaylistDetial.iconImage(), for: .normal)
        return view
    }
        
    private func navplaylistMenu() -> UIMenu {
        
        guard let model = self.musicModel else { return UIMenu() }
        
        // 喜欢/不喜欢
        let likeItem: MusicActionType = model.isFlagFavorite() ? .removeFavirote : .addFavirote
        let likeAction = UIAction(title: likeItem.titleStr(), image: likeItem.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: likeItem)
        }
        
        // 从歌单中除移
        let playlistAction = UIAction(title: MusicActionType.removePlaylist.titleStr(), image: MusicActionType.removePlaylist.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .removePlaylist)
        }
        
        let actionMenu = UIMenu(title: "", options: .displayInline, children: [likeAction/*, playlistAction*/])
        
        // 艺术家
        let artistAction = UIAction(title: MusicActionType.artistDetial.titleStr(), image: MusicActionType.artistDetial.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .artistDetial)
        }
                
        // 专辑
        let albumAction = UIAction(title: MusicActionType.albumDetial.titleStr(), image: MusicActionType.albumDetial.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .albumDetial)
        }
                
        let detialMenu = UIMenu(title: "", options: .displayInline, children: [artistAction/*, albumAction*/])
        
        // 下载
        let downloadAction = UIAction(title: MusicActionType.download.titleStr(), image: MusicActionType.download.iconImage(), attributes: .destructive) { [weak self] (_) in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .download)
        }
        
        let downloadMenu = UIMenu(title: "", options: .displayInline, children: [downloadAction])
        
        let menu = UIMenu(title: self.musicModel.showTitleName(), image: UIImage(systemName: "ellipsis"), identifier: nil, options: [], children: [actionMenu, detialMenu, downloadMenu])
        
        return menu
    }
    
}
