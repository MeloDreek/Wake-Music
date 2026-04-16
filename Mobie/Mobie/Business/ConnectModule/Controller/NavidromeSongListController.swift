//
//  NavidromeSongListController.swift
//  Mobie
//
//  Created by 张文 on 3/4/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import Kingfisher
import KakaPhotoBrowser
import NVActivityIndicatorView
import ProgressHUD
import Combine

enum NavSongListType: Int {
    case allSong = 0
    case favorite = 1
    case playlist = 2
    
    func cellType() -> MusicCellType {
        switch self {
        case .allSong:
            return .navLargeServer
        case .favorite:
            return .navLargeServer
        case .playlist:
            return .navPlaylistDetial
        }
    }
}

/// 歌曲列表
class NavidromeSongListController: SuperViewController {
    
    deinit {
        APIManager.shared.frontSession.cancelAllRequests()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        ImageCache.default.clearMemoryCache()
    }
    
    init(listType: NavSongListType, songs: ([NavidromeSong], NavidromePlaylist?)) {
        super.init(nibName: nil, bundle: nil)
        self.listType = listType
        self.songArray = songs.0
        self.playlist = songs.1
        self.navUser = songs.0.first?.navUser ?? songs.1?.navUser
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
        contentView.addSubview(loadingView)
        
        let size = loadingView.size.width
        loadingView.frame = CGRectMake((contentView.width - size) / 2, (contentView.height - size) / 2, size, size)
        
        if self.listType == .playlist {
            self.headView.addSubview(coverImgView)
            coverImgView.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.centerY.equalToSuperview()
                make.size.equalTo(coverImgView.layer.cornerRadius * 2)
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
        
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        switch self.listType {
        case .allSong:
            self.title = "All Songs".localStr()
        case .favorite:
            self.title = "Favourite Songs".localStr()
        case .playlist:
            self.title = self.playlist?.name ?? "Playlist".localStr()
        }
        
        self.configSearchBar()
                
        NotificationCenter.default.addObserver(self, selector: #selector(refreshDataAction), name: Notification.Name(kRemoteMusicChangedKey), object: nil)
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.perform(#selector(self?.playingMusicChanged), with: nil, afterDelay: 0.2)
            }.store(in: &cancellables)
        
        self.refreshDataAction()
    }
    
    @objc func playingMusicChanged() {
        self.tableView.reloadData()
    }
    
    @objc func refreshDataAction() {
        switch self.listType {
        case .allSong:
            self.perform(#selector(refreshAllSongs), with: nil, afterDelay: 0.1)
        case .favorite:
            self.refreshStarredSongs()
        case .playlist:
            self.refreshPlaylistSongs()
        }
    }
    
    @objc func refreshAllSongs() {
        self.loadingView.startAnimating()
        
        self.searchController.searchBar.isUserInteractionEnabled = false
        let params: [String: Any] = ["_sort": "play_count", "_order": "ASC"]
        APIManager.shared.requestNavidrome(navUser: self.navUser, endpoint: API.Navidrome.getSong, parameters: params) { [weak self] data in
            
            guard let self = self else { return }
            
            guard let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String : Any]], jsonArray.count > 0 else {
                let jsonStr = String(data: data, encoding: .utf8) ?? ""
                self.view.makeToast(jsonStr)
                return
            }
            
            self.searchController.searchBar.isUserInteractionEnabled = true
            self.kaka_header.endRefreshing()
            self.loadingView.stopAnimating()
            self.tableView.isHidden = false
            
            let tempArray = [NavidromeSong].deserialize(from: jsonArray) ?? []
            
            let songArray = tempArray.map {
                var newModel = $0
                newModel.navUser = self.navUser
                return newModel
            }
            
            self.songArray = songArray
            self.originArray = songArray
            self.tableView.reloadData()
            
        } fail: { [weak self] error in
            guard let self = self else { return }
            self.searchController.searchBar.isUserInteractionEnabled = true
            self.kaka_header.endRefreshing()
            self.loadingView.stopAnimating()
            self.tableView.isHidden = false
            self.view.makeToast(error.localizedDescription)
        }
    }
    
    func refreshPlaylistSongs() {
        guard let playlist = self.playlist else { return }
        
        if !self.tableView.isDragging {
            self.loadingView.startAnimating()
        }
        
        self.searchController.searchBar.isUserInteractionEnabled = false
        let param = ["id": playlist.id]
        APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: API.Subsonic.playlistDetial, parameters: param) { [weak self] response in
            
            guard let self = self else { return }
            
            if var playlist = response.playlist {
                
                playlist.navUser = self.navUser
                
                self.playlist = playlist
                var tempArray = ConnectConfigManager.shared.playlists
                if let index = tempArray.firstIndex(where: { $0.id == playlist.id }) {
                    tempArray[index] = playlist
                    ConnectConfigManager.shared.playlists = tempArray
                }
            }
            
            self.searchController.searchBar.isUserInteractionEnabled = true
            self.kaka_header.endRefreshing()
            self.loadingView.stopAnimating()
            self.tableView.isHidden = false
            
            let tempArray = response.playlist?.songArray() ?? []
            
            let songArray = tempArray.map {
                var newModel = $0
                newModel.navUser = self.navUser
                return newModel
            }
            
            self.songArray = songArray
            self.originArray = songArray
            self.tableView.reloadData()
        } fail: { [weak self] error in
            guard let self = self else { return }
            self.searchController.searchBar.isUserInteractionEnabled = true
            self.kaka_header.endRefreshing()
            self.loadingView.stopAnimating()
            self.tableView.isHidden = false
            self.view.makeToast(error.localizedDescription)
        }
        
    }
    
    
    func refreshStarredSongs() {
        if !self.tableView.isDragging {
            self.loadingView.startAnimating()
        }
        
        self.searchController.searchBar.isUserInteractionEnabled = false
        let params1: [String: Any] = ["_start": 0, "_end": 0, "_order": "ASC", "_sort": "play_count"]
        APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: API.Subsonic.getStarred, method: .get, parameters: params1) { [weak self] subsonicModel in
                        
            guard let self = self else { return }
            
            var starredModel = subsonicModel.starred
            
            let tempSongs = starredModel?.song ?? []
            starredModel?.song = tempSongs.map({
                var tempModel = $0
                tempModel.navUser = self.navUser
                tempModel.starred = true
                return tempModel
            })
            
            self.searchController.searchBar.isUserInteractionEnabled = true
            
            let tempArray = starredModel?.song ?? []
            let songArray = tempArray.map {
                var newModel = $0
                newModel.navUser = self.navUser
                return newModel
            }
            
            self.songArray = songArray
            self.originArray = songArray
            self.kaka_header.endRefreshing()
            self.loadingView.stopAnimating()
            self.tableView.isHidden = false
            self.tableView.reloadData()
            
        } fail: { [weak self] error in
            guard let self = self else { return }
            self.searchController.searchBar.isUserInteractionEnabled = true
            self.kaka_header.endRefreshing()
            self.loadingView.stopAnimating()
            self.tableView.isHidden = false
            self.view.makeToast(error.localizedDescription)
        }
    }
    
    // MARK:  GET && SET
    
    var listType: NavSongListType = .allSong
    
    var searchKey: String?
    
    var cancellables = Set<AnyCancellable>()
        
    public var navUser: NavidromeUserModel?
    
    var playlist: NavidromePlaylist?
    
    var originArray: [NavidromeSong] = []
    
    lazy var songArray: [NavidromeSong] = {
        return [NavidromeSong]()
    }()
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: kaka_IsMacOS() ? .insetGrouped : .plain)
        view.delegate = self
        view.dataSource = self
        view.isHidden = true
        view.tableHeaderView = self.headView
#if !targetEnvironment(macCatalyst)
view.refreshControl = self.kaka_header
#endif
        view.rowHeight = UITableView.automaticDimension
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + playingHeight, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
        return view
    }()
    
    lazy var coverImgView: UIImageView = {
        
        let view = UIImageView()
        view.isUserInteractionEnabled = true
        view.layer.masksToBounds = true
        view.layer.cornerRadius = self.headView.height * 0.75 / 2
        view.contentMode = .scaleAspectFill
        view.kf.setImage(with: self.playlist?.coverImgURL(), placeholder: UIImage(named: "music_place"))
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
        var iconImage: UIImage?
        switch self.listType {
        case .allSong:
            iconImage = ImportFileType.fromNavidrome.iconImage()
        case .favorite:
            iconImage = UIImage(systemName: "heart.fill")
        case .playlist:
            iconImage = nil
        }
        
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 150
        }
        
        let view = UITableViewHeaderFooterView(frame: CGRectMake(0, 0, self.view.width, height * 1.5))
        view.backgroundColor = .clear
        let faceImgView = UIImageView(image: iconImage)
        faceImgView.contentMode = .scaleAspectFit
        view.contentView.addSubview(faceImgView)
        faceImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(height)
        }
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
    
    lazy var searchController: UISearchController = {
        let searchVC = UISearchController()
        searchVC.searchBar.delegate = self
        return searchVC
    }()
}

extension NavidromeSongListController: UITableViewDataSource, UITableViewDelegate, MusicTableViewCellDelegate {
    
    // 点击cell更多
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
        
        if action == .removePlaylist {
            if let navSong = model.navidromeSong {
                self.navidromeRemovePlaylist(navSong: navSong)
            }
        }
        
        if action == .download {
            if let navSong = model.navidromeSong {
                self.navidromeSearchDidDownload(cell: cell, navSong: navSong)
            }
        }
        
        if action == .artistDetial {
            if let navSong = model.navidromeSong, let navUser = navSong.navUser {
                var navArtist = NavidromeArtist()
                navArtist.id = navSong.artistId ?? ""
                navArtist.name = navSong.artist
                navArtist.navUser = navSong.navUser
                let artistVC = NavidromeArtistDetialController(navUser: navUser, model: navArtist)
                self.navigationController?.pushViewController(artistVC, animated: true)
            }
        }
        
        if action == .albumDetial {
            
        }
        
    }
    
    func navidromeSearchDidAddLike(navSong: AppGroupKit.NavidromeSong) {
        let params: [String: Any] = ["id": navSong.id]
        APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: API.Subsonic.unstar, parameters: params) { [weak self] response in
            var newSong = navSong
            newSong.starred.toggle()
            
            let index = self?.songArray.firstIndex { $0.id == newSong.id }
            guard let index = index else { return }
            
            self?.songArray.remove(at: index)
            self?.tableView.reloadData()
            self?.view.makeToast("Successful".localStr())
            NotificationCenter.default.post(name: Notification.Name(kRemoteMusicChangedKey), object: nil)
            
        } fail: { [weak self] error in
            self?.view.makeToast(error.localizedDescription)
        }
    }
    
    func navidromeSearchDidAddPlaylist(navSong: AppGroupKit.NavidromeSong) {
        let serverModel = ServerConfigModel(serverType: .fromNavidrome, navUser: self.navUser)
        let playlist = SelectPlaylistController(isLocal: false, serverModel: serverModel)
        playlist.onRemoteBlock = { [weak self] (playlist) in
            let params = ["playlistId": playlist.id, "songIdToAdd": navSong.id]
            APIManager.shared.requestSubsonic(navUser: self?.navUser, endpoint: API.Subsonic.updatePlaylist, parameters: params) { response in
                self?.view.makeToast("Successful".localStr())
                NotificationCenter.default.post(name: Notification.Name(kRemoteMusicChangedKey), object: nil)
            } fail: { error in
                self?.view.makeToast(error.localizedDescription)
            }
        }
        
        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
    }
    
    // https://baigao.serect.top:14533/rest/updatePlaylist?u=serect&t=8dd15512609bb94b03331b7787f90126&s=5edcc5&v=1.16.1&c=Wake_Music&f=json&songIndexToRemove=e0b0aa4c0960fa993e12d37b3439e126&playlistId=f8480726-d0d6-44ef-8d49-43773b4ab552
    // 从歌单中除移
    func navidromeRemovePlaylist(navSong: AppGroupKit.NavidromeSong) {
        let params = ["playlistId": self.playlist?.id ?? "", "songIndexToRemove": navSong.id]
        APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: API.Subsonic.updatePlaylist, method: .delete, parameters: params) { [weak self] response in
            self?.view.makeToast("Successful".localStr())
            
            debugPrint("response = \(response)")
            
            if let index = self?.songArray.firstIndex(where: { $0.id == navSong.id }) {
                self?.songArray.remove(at: index)
                self?.tableView.reloadData()
            }
        } fail: { [weak self] error in
            self?.view.makeToast(error.localizedDescription)
        }
    }
    
    func navidromeSearchDidDownload(cell: MusicTableViewCell, navSong: AppGroupKit.NavidromeSong) {
        
        let playlist = SelectPlaylistController(isLocal: true, serverModel: nil)
        playlist.onLocalBlock = { [weak self] (folderURL) in
            var musicModel = MusicItemModel(navSong: navSong)
            musicModel.downloadFolderName = folderURL.lastPathComponent
            DownloadManager.shared.addMusicModel([musicModel])
            self?.view.makeToast("Added to download queue".localStr())
        }
        
        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
    }
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.songArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
        let navModel = MusicItemModel(navSong: self.songArray[indexPath.row])
        cell.update(musicModel: navModel, cellType: self.listType.cellType())
        cell.delegate = self
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let musicArray = self.songArray.map { return MusicItemModel(navSong: $0) }
        
        let playModel = musicArray[indexPath.row]
        
        let isPlaying: Bool = KakaMusicPlayer.shared.playingMusic == playModel
        
        if isPlaying {
            KakaMusicPlayer.presentPlayController(fromVC: self)
        }else{
            ConnectConfigManager.shared.lastPlaylist = musicArray
            KakaMusicPlayer.shared.startPlayMusic(musics: musicArray, itemIndex: indexPath.row)
            
            tableView.reloadData()
        }
    }
    
}
