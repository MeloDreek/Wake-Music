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
        let view = UIButton(type: .custom)
        view.size = CGSizeMake(50.ckValue(), 50.ckValue())
        view.setImage(Reasource.systemNamed("touchid", color: .systemBlue), for: .normal)
        view.addTarget(self, action: #selector(autoTagButtonClick), for: .touchUpInside)
        return view
    }
    
    @objc private func autoTagButtonClick() {
        guard let model = self.musicModel else { return }
        self.delegate?.musicTableCell(cell: self, model: model, action: .autoRecognize)
    }
    
    func localButton() -> UIButton {
        let view = UIButton(type: .custom)
        view.showsMenuAsPrimaryAction = true
        view.menu = self.localMenu()
        view.size = CGSizeMake(45.ckValue(), 45.ckValue())
        view.setImage(MusicCellType.local.iconImage(), for: .normal)
        return view
    }
    
    private func localMenu() -> UIMenu {
        
        guard let model = self.musicModel else { return UIMenu() }
        
        // AI搜索封面
        let aiCoverAction = UIAction(title: MusicActionType.searchCoverAI.formatStr(), image: MusicActionType.searchCoverAI.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .searchCoverAI)
        }
        // AI搜索歌词
        let aiLyricAction = UIAction(title: MusicActionType.searchLyricAI.formatStr(), image: MusicActionType.searchLyricAI.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .searchLyricAI)
        }
        // 音乐标签编辑器
        let musictagAction = UIAction(title: "Music Tag Editor".localStr(), image: MusicActionType.musictag.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .musictag)
        }
        
        let musictagMenu = UIMenu(title: "", options: .displayInline, children: [aiCoverAction, aiLyricAction, musictagAction])
        
        // 喜欢
        let likeType = model.isFlagFavorite() ? MusicActionType.removeFavirote : MusicActionType.addFavirote
        let likeItem = UIAction(title: likeType.formatStr(), image: likeType.iconImage()) { [weak self] (_) in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .addFavirote)
        }
        
        // 移动到其他歌单
        let playlistAction = UIAction(title: MusicActionType.addPlaylist.formatStr(), image: MusicActionType.addPlaylist.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .addPlaylist)
        }
        
        let otherMenu = UIMenu(title: "", options: .displayInline, children: [likeItem, playlistAction])
        
        // 在Finder中显示
        let finderAction = UIAction(title: MusicActionType.showInFinder.formatStr(), image: MusicActionType.showInFinder.iconImage()) { [weak self] (_) in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .showInFinder)
        }
        // 删除
        let deleteAction = UIAction(title: MusicActionType.deleteItem.formatStr(), image: MusicActionType.deleteItem.iconImage(), attributes: .destructive) { [weak self] (_) in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .deleteItem)
        }
        
        let deleteMenu = UIMenu(title: "", options: .displayInline, children: kaka_IsMacOS() ? [finderAction, deleteAction] : [deleteAction])
        
        let menu = UIMenu(title: self.musicModel.showTitleName(), image: UIImage(systemName: "ellipsis"), identifier: nil, options: [], children: [musictagMenu, otherMenu, deleteMenu])
        
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
        view.showsMenuAsPrimaryAction = true
        view.menu = self.cloudDriveMenu()
        view.size = CGSizeMake(45.ckValue(), 45.ckValue())
        view.setImage(MusicCellType.cloudDrive.iconImage(), for: .normal)
        return view
    }
        
    private func cloudDriveMenu() -> UIMenu {
        var actionArray = [UIAction]()
        let typeArray: [MusicActionType] = [.play, .musictag, .download]
        
        for subType in typeArray {
            let isRed = subType == .download || subType == .deleteItem
            let subMemu = UIAction(title: subType.formatStr(), image: subType.iconImage(), identifier: nil, discoverabilityTitle: nil, attributes: isRed ? [.destructive] : [], state: .off, handler: { [weak self] _ in
                guard let wSelf = self, let model = wSelf.musicModel else { return }
                wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: subType)
            })
            actionArray.append(subMemu)
        }
        
        let menu = UIMenu(title: self.musicModel.showTitleName(), image: UIImage(systemName: "ellipsis"), identifier: nil, options: [], children: actionArray)
        return menu
    }
    
}


// 4️⃣小型Navidrome服
extension MusicTableViewCell {
    func smallnavButton() -> UIButton {
        let view = UIButton(type: .custom)
        view.showsMenuAsPrimaryAction = true
        view.menu = self.smallnavMenu()
        view.size = CGSizeMake(45.ckValue(), 45.ckValue())
        view.setImage(MusicCellType.navSmallServer.iconImage(), for: .normal)
        return view
    }
        
    private func smallnavMenu() -> UIMenu {
        var actionArray = [UIAction]()
        let typeArray: [MusicActionType] = [.artistDetial, /*.albumDetial,*/ .download]
        
        for subType in typeArray {
            let isRed = subType == .download || subType == .deleteItem
            let subMemu = UIAction(title: subType.formatStr(), image: subType.iconImage(), identifier: nil, discoverabilityTitle: nil, attributes: isRed ? [.destructive] : [], state: .off, handler: { [weak self] _ in
                guard let wSelf = self, let model = wSelf.musicModel else { return }
                wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: subType)
            })
            actionArray.append(subMemu)
        }
        
        let menu = UIMenu(title: self.musicModel.showTitleName(), image: UIImage(systemName: "ellipsis"), identifier: nil, options: [], children: actionArray)
        return menu
    }
    
}

// 5️⃣一般的大型Navidrome服
extension MusicTableViewCell {
    func largenavBUtton() -> UIButton {
        let view = UIButton(type: .custom)
        view.showsMenuAsPrimaryAction = true
        view.menu = self.largenavMenu()
        view.size = CGSizeMake(45.ckValue(), 45.ckValue())
        view.setImage(MusicCellType.navLargeServer.iconImage(), for: .normal)
        return view
    }
        
    private func largenavMenu() -> UIMenu {
        
        guard let model = self.musicModel else { return UIMenu() }
        
        // 喜欢/不喜欢
        let likeItem: MusicActionType = model.isFlagFavorite() ? .removeFavirote : .addFavirote
        let likeAction = UIAction(title: likeItem.formatStr(), image: likeItem.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: likeItem)
        }
        
        // 添加到歌单
        let playlistAction = UIAction(title: MusicActionType.addPlaylist.formatStr(), image: MusicActionType.addPlaylist.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .addPlaylist)
        }
        
        let actionMenu = UIMenu(title: "", options: .displayInline, children: [likeAction, playlistAction])
        
        
        // 艺术家
        let artistAction = UIAction(title: MusicActionType.artistDetial.formatStr(), image: MusicActionType.artistDetial.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .artistDetial)
        }
                
        // 专辑
        let albumAction = UIAction(title: MusicActionType.albumDetial.formatStr(), image: MusicActionType.albumDetial.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .albumDetial)
        }
                
        let detialMenu = UIMenu(title: "", options: .displayInline, children: [artistAction/*, albumAction*/])

        // 下载
        let downloadAction = UIAction(title: MusicActionType.download.formatStr(), image: MusicActionType.download.iconImage(), attributes: .destructive) { [weak self] (_) in
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
        let likeAction = UIAction(title: likeItem.formatStr(), image: likeItem.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: likeItem)
        }
        
        // 添加到歌单
        let playlistAction = UIAction(title: MusicActionType.addPlaylist.formatStr(), image: MusicActionType.addPlaylist.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .addPlaylist)
        }
        
        let actionMenu = UIMenu(title: "", options: .displayInline, children: [likeAction, playlistAction])
        
        
        // 下载
        let downloadAction = UIAction(title: MusicActionType.download.formatStr(), image: MusicActionType.download.iconImage(), attributes: .destructive) { [weak self] (_) in
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
        let likeAction = UIAction(title: likeItem.formatStr(), image: likeItem.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: likeItem)
        }
        
        // 从歌单中除移
        let playlistAction = UIAction(title: MusicActionType.removePlaylist.formatStr(), image: MusicActionType.removePlaylist.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .removePlaylist)
        }
        
        let actionMenu = UIMenu(title: "", options: .displayInline, children: [likeAction/*, playlistAction*/])
        
        // 艺术家
        let artistAction = UIAction(title: MusicActionType.artistDetial.formatStr(), image: MusicActionType.artistDetial.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .artistDetial)
        }
                
        // 专辑
        let albumAction = UIAction(title: MusicActionType.albumDetial.formatStr(), image: MusicActionType.albumDetial.iconImage()) { [weak self] _ in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .albumDetial)
        }
                
        let detialMenu = UIMenu(title: "", options: .displayInline, children: [artistAction/*, albumAction*/])
        
        // 下载
        let downloadAction = UIAction(title: MusicActionType.download.formatStr(), image: MusicActionType.download.iconImage(), attributes: .destructive) { [weak self] (_) in
            guard let wSelf = self, let model = wSelf.musicModel else { return }
            wSelf.delegate?.musicTableCell(cell: wSelf, model: model, action: .download)
        }
        
        let downloadMenu = UIMenu(title: "", options: .displayInline, children: [downloadAction])
        
        let menu = UIMenu(title: self.musicModel.showTitleName(), image: UIImage(systemName: "ellipsis"), identifier: nil, options: [], children: [actionMenu, detialMenu, downloadMenu])
        
        return menu
    }
    
}

