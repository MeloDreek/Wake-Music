//
//  NavidromeArtistDetialController.swift
//  Mobie
//
//  Created by 张文 on 3/2/25.
//

import KakaFoundation
import AppGroupKit
import Kingfisher
import KakaPhotoBrowser
import NVActivityIndicatorView
import ProgressHUD
import Combine

/// 歌手详情页
class NavidromeArtistDetialController: SuperViewController {
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        ImageCache.default.clearMemoryCache()
    }
    
    init(navUser: NavidromeUserModel, model: NavidromeArtist) {
        super.init(nibName: nil, bundle: nil)
        self.navUser = navUser
        self.navArtist = model
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
        contentView.addSubview(loadingView)
        
        self.headView.addSubview(coverImgView)
        coverImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(coverImgView.layer.cornerRadius * 2)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = contentView.bounds
        
        let size = loadingView.size.width
        loadingView.frame = CGRectMake((contentView.width - size) / 2, (contentView.height - size) / 2, size, size)
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = self.navArtist.name
        
        self.navigationItem.rightBarButtonItem = self.navArtist.starred ? self.starredItem : self.unstarredItem
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.perform(#selector(self?.playingMusicChanged), with: nil, afterDelay: 0.2)
            }.store(in: &cancellables)

        self.loadingView.startAnimating()
        self.refreshDataAction()
    }
    
    @objc func refreshDataAction() {
        
        let taskGroup = DispatchGroup()
        
        // 歌手详情和相似歌手
        taskGroup.enter()
        let params1 = ["id": self.navArtist.id]
        APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: API.Subsonic.artistInfo, parameters: params1) { response in
            guard var artistInfo2 = response.artistInfo2 else { return }
            artistInfo2.navUser = self.navArtist.navUser
            
            self.navArtist = self.navArtist.mergeArtistModel(artistInfo2)
            let tempArray = artistInfo2.similarArtist ?? []
            self.similarArtist = tempArray.map {
                var newModel = $0
                newModel.navUser = self.navArtist.navUser
                return newModel
            }
            
            self.coverImgView.kf.setImage(with: self.navArtist.artistAvatarURL(), placeholder: UIImage(named: "music_place"))
            self.tableView.reloadData()
            taskGroup.leave()
        } fail: { error in
            taskGroup.leave()
            self.view.makeToast(error.localizedDescription)
        }
        
        // 所有歌曲
        taskGroup.enter()
        let params3: [String: Any] = ["artist_id": self.navArtist.id, "_sort": "play_count"]
        APIManager.shared.requestNavidrome(navUser: self.navUser, endpoint: API.Navidrome.getSong, parameters: params3) { data in
            guard let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String : Any]], jsonArray.count > 0 else {
                let jsonStr = String(data: data, encoding: .utf8) ?? ""
                self.view.makeToast(jsonStr)
                taskGroup.leave()
                return
            }
            
            let tempArray = [NavidromeSong].deserialize(from: jsonArray) ?? []
            let songArray = tempArray.map {
                var newModel = $0
                newModel.navUser = self.navArtist.navUser
                return newModel
            }
            self.songArray = songArray.map({ return MusicItemModel(navSong: $0) })
            self.tableView.reloadData()
            taskGroup.leave()
            
        } fail: { error in
            taskGroup.leave()
            self.view.makeToast(error.localizedDescription)
        }
        
        taskGroup.notify(queue: .main) { [weak self] () in
            self?.tableView.isHidden = false
            self?.loadingView.stopAnimating()
            self?.tableView.reloadData()
            self?.kaka_header.endRefreshing()
        }
        
    }
    
    @objc func starredItemClick() {
        let params: [String: Any] = ["artistId": self.navArtist.id]
        APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: navArtist.starred ? API.Subsonic.unstar : API.Subsonic.star, parameters: params) { subsonic in
            
            self.navArtist.starred.toggle()
            
            self.navigationItem.rightBarButtonItem = self.navArtist.starred ? self.starredItem : self.unstarredItem
            NotificationCenter.default.post(name: Notification.Name(kRemoteMusicChangedKey), object: nil)
            
        } fail: { error in
            self.view.makeToast(error.localizedDescription)
        }
    }
    
    @objc func playingMusicChanged() {
        self.tableView.reloadData()
    }
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()
    
    var originOverrideStyle = UIUserInterfaceStyle.unspecified
    
    var navUser: NavidromeUserModel!
    var navArtist: NavidromeArtist!
    
    lazy var songArray: [MusicItemModel] = {
        return [MusicItemModel]()
    }()
    
    lazy var similarArtist: [NavidromeArtist] = {
        return [NavidromeArtist]()
    }()
    
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: kaka_IsMacOS() ? .insetGrouped : .plain)
        view.delegate = self
        view.dataSource = self
        view.isHidden = true
        view.tableHeaderView = self.headView
        view.separatorStyle = .singleLine
#if !targetEnvironment(macCatalyst)
view.refreshControl = self.kaka_header
#endif
        view.rowHeight = UITableView.automaticDimension
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + playingHeight, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(SearchArtistTableCell.self, forCellReuseIdentifier: "SearchArtistTableCell")
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
        return view
    }()
    
    lazy var coverImgView: UIImageView = {
        
        let view = UIImageView()
        view.isUserInteractionEnabled = true
        view.layer.masksToBounds = true
        view.layer.cornerRadius = self.headView.height * 0.75 / 2
        view.contentMode = .scaleAspectFill
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(coverImgViewClick(_:)))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    @objc func coverImgViewClick(_ sender: UITapGestureRecognizer) {
        if kaka_IsMacOS() { return }
        guard let coverView = sender.view as? UIImageView else { return }
        let photoItem = KakaPhotoItem(sourceView: coverView, image: coverView.image)
        let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
        photoBrowser.backgroundStyle = .blurPhoto
        photoBrowser.show(from: self)
    }
        
    lazy var headView: UITableViewHeaderFooterView = {
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 150
        }
        
        let view = UITableViewHeaderFooterView(frame: CGRectMake(0, 0, self.view.width, height * 1.5))
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var kaka_header: UIRefreshControl = {
        let view = UIRefreshControl()
        view.size = CGSizeMake(30.ckValue(), 30.ckValue())
        view.tintColor = .label
        view.addTarget(self, action: #selector(refreshDataAction), for: .valueChanged)
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 30.ckValue(), 30.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: AppLocalManager.shared.playAnimation.nvType(), color: appMainColor)
        return view
    }()
    
    lazy var starredItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "heart.fill"), style: .plain, target: self, action: #selector(starredItemClick))
        return item
    }()
    
    lazy var unstarredItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "heart"), style: .plain, target: self, action: #selector(starredItemClick))
        return item
    }()
}

extension NavidromeArtistDetialController: UITableViewDataSource, UITableViewDelegate, MusicTableViewCellDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? self.songArray.count : 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
            let model = self.songArray[indexPath.row]
            cell.update(musicModel: model, cellType: .navArtistDetial)
            cell.delegate = self
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "SearchArtistTableCell", for: indexPath) as! SearchArtistTableCell
            cell.artistArray = self.similarArtist
            cell.onClickBlock = { [weak self] (navArtist) in
                guard let wSelf = self else { return }
                let artistVC = NavidromeArtistDetialController(navUser: wSelf.navUser, model: navArtist)
                self?.navigationController?.pushViewController(artistVC, animated: true)
            }
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let model = self.songArray[indexPath.row]
        if KakaMusicPlayer.shared.playingMusic == model {
            KakaMusicPlayer.presentPlayController(fromVC: self)
        }else{
            ConnectConfigManager.shared.lastPlaylist = self.songArray
            KakaMusicPlayer.shared.startPlayMusic(musics: self.songArray, itemIndex: indexPath.row)
        }        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return nil
        }else{
            return "Similar Singers".localStr()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return UITableView.automaticDimension
        }else{
            return SearchArtistTableCell.headHeight()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    // 点击更多
    func musicTableCell(cell: MusicTableViewCell, model: MusicItemModel, action: MusicActionType) {
        if action == .addFavirote || action == .removeFavirote {
            if let navSong = model.navidromeSong {
                self.navidromeSearchDidAddLike(navSong: navSong)
            }
        }
        
        if action == .addPlaylist {
            if let navSong = model.navidromeSong {
                self.navidromeSearchDidAddPlaylist(navSong: navSong)
            }
        }
        
        if action == .download {
            if let navSong = model.navidromeSong {
                self.navidromeSearchDidDownload(cell: cell, navSong: navSong)
            }
        }
        
        
        
        if action == .albumDetial {
            
        }
    }
    
    // 喜欢
    func navidromeSearchDidAddLike(navSong: AppGroupKit.NavidromeSong) {
        let params: [String: Any] = ["id": navSong.id]
        APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: API.Subsonic.star, parameters: params) { [weak self] response in
            self?.view.makeToast("Successful".localStr())
            NotificationCenter.default.post(name: Notification.Name(kRemoteMusicChangedKey), object: nil)
        } fail: { [weak self] error in
            self?.view.makeToast(error.localizedDescription)
        }
    }
    
    // 添加到歌单
    func navidromeSearchDidAddPlaylist(navSong: AppGroupKit.NavidromeSong) {
        let serverModel = ServerConfigModel(serverType: .fromNavidrome, navUser: self.navUser)
        let playlist = SelectPlaylistController(isLocal: false, serverModel: serverModel)
        playlist.onRemoteBlock = { [weak self] (playlist) in
            guard let wSelf = self else { return }
            let params = ["playlistId": playlist.id, "songIdToAdd": navSong.id]
            APIManager.shared.requestSubsonic(navUser: wSelf.navUser, endpoint: API.Subsonic.updatePlaylist, parameters: params) { response in
                self?.view.makeToast("Successful".localStr())
                NotificationCenter.default.post(name: Notification.Name(kRemoteMusicChangedKey), object: nil)
            } fail: { error in
                self?.view.makeToast(error.localizedDescription)
            }

        }

        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
    }
    
    // 下载
    func navidromeSearchDidDownload(cell: MusicTableViewCell, navSong: AppGroupKit.NavidromeSong) {
                
        let playlist = SelectPlaylistController(isLocal: true, serverModel: nil)
        playlist.onLocalBlock = { [weak self] (folderURL) in
            var musicModel = MusicItemModel(navSong: navSong)
            musicModel.downloadFolderName = folderURL.lastPathComponent
            DownloadManager.shared.addMusicModel([musicModel])
            self?.view.makeToast("Added to Downloads".localStr())
        }

        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
        
    }
    
}
