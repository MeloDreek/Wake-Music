//
//  NavidromeSearchViewController.swift
//  Mobie
//
//  Created by 张文 on 3/4/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import ProgressHUD
import SafariServices
import Combine


/// Navidrome搜索页面
class NavidromeSearchViewController: UISearchController, MusicTableViewCellDelegate {
    
    func musicTableCell(cell: MusicTableViewCell, model: MusicItemModel, action: MusicActionType) {
        if action == .addFavirote || action == .removeFavirote {
            if let navSong = model.navidromeSong {
                self.navidromeSearchDidAddLike(navSong: navSong)
            }
            
            if let webFileModel = model.webFileModel, webFileModel.fileSize > 0 {
                ConnectConfigManager.shared.likeOrDislikeOneMusic(model)
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
        
        if action == .artistDetial {
            if let navSong = model.navidromeSong {
                var navArtist = NavidromeArtist()
                navArtist.id = navSong.artistId ?? ""
                navArtist.name = navSong.artist
                navArtist.navUser = navSong.navUser
                let artistVC = NavidromeArtistDetialController(navUser: self.navUser, model: navArtist)
                self.naviController?.pushViewController(artistVC, animated: true)
            }
        }
        
        if action == .albumDetial {
            
        }
    }
    
    // 喜欢
    func navidromeSearchDidAddLike(navSong: AppGroupKit.NavidromeSong) {
        let params: [String: Any] = ["id": navSong.id]
        APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: API.Subsonic.star, parameters: params) { [weak self] response in
            var newSong = navSong
            newSong.starred.toggle()
            
            let index = self?.searchModel.song?.firstIndex { $0.id == newSong.id }
            guard let index = index else { return }
            
            
            self?.searchModel.song?[index] = newSong
            self?.tableView.reloadData()
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
    func navidromeSearchDidDownload(cell: MusicTableViewCell, navSong: NavidromeSong) {
        guard UserInfoManager.shared.isVIP() else {
            self.vipCenterClick()
            return
        }
        
        let playlist = SelectPlaylistController(isLocal: true, serverModel: nil)
        playlist.onLocalBlock = { [weak self] (folderURL) in
            var musicModel = MusicItemModel(navSong: navSong)
            musicModel.downloadFolderName = folderURL.lastPathComponent
            DownloadManager.shared.addMusicModel([musicModel])
            self?.view.makeToast("Added to Downloads".localStr())
        }

        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
    }
    
    func webdavSearchDidDownload(cell: MusicTableViewCell, webFileModel: AppGroupKit.WebdavFileModel) {
        guard UserInfoManager.shared.isVIP() else {
            self.vipCenterClick()
            return
        }
        
        let playlist = SelectPlaylistController(isLocal: true, serverModel: nil)
        playlist.onLocalBlock = { [weak self] (folderURL) in
            var musicModel = MusicItemModel(webFileModel: webFileModel)
            musicModel.downloadFolderName = folderURL.lastPathComponent
            DownloadManager.shared.addMusicModel([musicModel])
            self?.view.makeToast("Added to Downloads".localStr())
        }
        
        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preSetupSubViews()
        self.preSetupHandleBuness()
    }
    
    private func preSetupSubViews() {
        self.view.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = self.view.bounds
    }
    
    private func preSetupHandleBuness() {
        
        let insertView = UIView(frame: CGRectMake(0, 0, self.view.width, kStatusBarHeight))
        insertView.backgroundColor = .clear
        self.view.addSubview(insertView)
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.perform(#selector(self?.playingMusicChanged), with: nil, afterDelay: 0.2)
            }.store(in: &cancellables)
    }
    
    
    @objc func vipCenterClick() {
        if !DiscountIAPManager.shared.isShowDiscount() {
            DiscountIAPManager.reset()
        }
        
        AppStoreKitManager.presentPurcharseVC(self)
    }

    
    @objc func playingMusicChanged() {
        self.tableView.reloadData()
    }
    
    
    // MARK:  GET && SET
    
    // 正在搜索词
    var isTypingKey: Bool = true
    
    var cancellables = Set<AnyCancellable>()
        
    lazy var searchModel: NaviArAlSongModel = {
        return NaviArAlSongModel()
    }()
    
    var navUser: NavidromeUserModel!
    
    weak var naviController: UINavigationController?
    
    // 开始搜索
    func startSearchAction(_ searchKey: String) {
        debugPrint("开始搜索 = \(searchKey)")
        
        var tempArray = ConnectConfigManager.shared.navSearchArray
        let firstIndex = tempArray.firstIndex { $0 == searchKey }
        if let firstIndex = firstIndex {
            tempArray.remove(at: firstIndex)
            tempArray.insert(searchKey, at: 0)
        }else{
            tempArray.insert(searchKey, at: 0)
        }
        
        ConnectConfigManager.shared.navSearchArray = tempArray
        
        // Navidrome
        let param = ["query": searchKey]
        APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: API.Subsonic.search, parameters: param) { response in
            self.isTypingKey = false
            if let searchResult2 = response.searchResult2 {
                self.searchModel = searchResult2.update(self.navUser)
            }
            self.tableView.reloadData()
        } fail: { error in
            self.view.makeToast(error.localizedDescription)
        }
        
    }
    
    // 结束搜索：清空关键词
    func stopSearchAction() {
        debugPrint("清空关键词")
        self.isTypingKey = true
        self.tableView.reloadData()
    }
    
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: kaka_IsMacOS() ? .insetGrouped : .plain)
        view.delegate = self
        view.dataSource = self
        view.separatorStyle = .none
        view.rowHeight = UITableView.automaticDimension
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + playingHeight, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(SearchKeyTableCell.self, forCellReuseIdentifier: "SearchKeyTableCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "EmptyTableViewCell")
        view.register(EmptyDataTableCell.self, forCellReuseIdentifier: "EmptyDataTableCell")
        view.register(SearchArtistTableCell.self, forCellReuseIdentifier: "SearchArtistTableCell")
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
        return view
    }()
    
    
}

extension NavidromeSearchViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if isTypingKey {
            return 1
        }else{
            return 2
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isTypingKey {
            return ConnectConfigManager.shared.navSearchArray.count
        }else{
            if section == 0 {
                return 1
            }else{
                if let songs = self.searchModel.song, songs.count > 0 {
                    return songs.count
                }else{
                    return 1
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isTypingKey {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SearchKeyTableCell", for: indexPath) as! SearchKeyTableCell
            let searchKey = ConnectConfigManager.shared.navSearchArray[indexPath.row]
            cell.searchKey = searchKey
            cell.onDeleteBlock = { [weak self] (deleteKey) in
                var tempArray = ConnectConfigManager.shared.navSearchArray
                let firstIndex = tempArray.firstIndex { $0 == searchKey }
                if let firstIndex = firstIndex {
                    tempArray.remove(at: firstIndex)
                }
                
                ConnectConfigManager.shared.navSearchArray = tempArray
                self?.tableView.reloadData()
            }
            return cell
        }else{
            
            if indexPath.section == 0 {
                if let artists = self.searchModel.artist, artists.count > 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "SearchArtistTableCell", for: indexPath) as! SearchArtistTableCell
                    cell.artistArray = self.searchModel.artist ?? []
                    cell.onClickBlock = { [weak self] (navArtist) in
                        guard let wSelf = self else { return }
                        let artistVC = NavidromeArtistDetialController(navUser: wSelf.navUser, model: navArtist)
                        self?.naviController?.pushViewController(artistVC, animated: true)
                    }
                    return cell
                }else{
                    let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyDataTableCell", for: indexPath) as! EmptyDataTableCell
                    cell.updateMessage()
                    cell.selectionStyle = .none
                    return cell
                }
            }else{
                if let songs = self.searchModel.song, songs.count > 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
                    let songModel = songs[indexPath.row]
                    let musicModel = MusicItemModel(navSong: songModel)
                    let cellType: MusicCellType = self.navUser.isLargeServer ? .navLargeServer : .navSmallServer
                    cell.update(musicModel: musicModel, cellType: cellType)
                    cell.delegate = self
                    return cell
                }else{
                    let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyDataTableCell", for: indexPath) as! EmptyDataTableCell
                    cell.updateMessage()
                    cell.selectionStyle = .none
                    return cell
                }
            }
            
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.view.endEditing(true)
        
        if isTypingKey {
            let searchKey = ConnectConfigManager.shared.navSearchArray[indexPath.row]
            self.searchBar.text = searchKey
            self.view.endEditing(true)
            self.searchBar.endEditing(true)
            self.startSearchAction(searchKey)
        }else{
            if indexPath.section == 1 {
                guard let songs = self.searchModel.song, songs.count > 0 else { return }
                
                let musicArray = songs.map { return MusicItemModel(navSong: $0) }
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
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if isTypingKey {
            return nil
        }else{
            if section == 0 {
                return "Artist".localStr()
            }else{
                return "Songs".localStr()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if isTypingKey {
            return UITableView.automaticDimension
        }else{
            if indexPath.section == 0 {
                if let artists = self.searchModel.artist, artists.count > 0 {
                    let cellHeight = SearchArtistTableCell.headHeight()
                    return kaka_IsMacOS() ? cellHeight + 30 : cellHeight
                }else{
                    return UITableView.automaticDimension
                }
            }else{
                return UITableView.automaticDimension
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
}

// 历史搜索记录
class SearchKeyTableCell: UITableViewCell {
    
    var onDeleteBlock: ((String)->Void)?
    
    var searchKey: String = "" {
        didSet {
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = searchKey
            cellConfig.textProperties.font = UIFontLight(16.ckValue())
            cellConfig.textProperties.numberOfLines = 1
            cellConfig.imageProperties.maximumSize = CGSizeMake(18.ckValue(), 18.ckValue())
            cellConfig.image = Reasource.systemNamed("clock", color: .secondaryLabel)
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            
            self.accessoryView = self.deleteButton
            self.contentConfiguration = cellConfig
        }
    }
    
    lazy var deleteButton: UIButton = {
        let config = UIImage.SymbolConfiguration(pointSize: 12.ckValue(), weight: .light)
        
        let view = UIButton(type: .custom)
        view.frame = CGRectMake(0, 0, 20.ckValue(), 20.ckValue())
        view.setImage(Reasource.systemNamed("xmark", color: .label, config: config), for: .normal)
        view.addTarget(self, action: #selector(deleteButtonClick), for: .touchUpInside)
        return view
    }()
    
    
    @objc func deleteButtonClick() {
        self.onDeleteBlock?(self.searchKey)
    }
    
}


