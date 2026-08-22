//
//  CloudMusicTagViewController.swift
//  Mobie
//
//  Created by 张文 on 10/24/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import NVActivityIndicatorView
import KSPlayer
import KakaTaglibKit

/// 解析远程音乐的音乐标签
class CloudMusicTagViewController: SuperViewController {
    
    init(_ model: MusicItemModel) {
        super.init(nibName: nil, bundle: nil)
        self.musicModel = model
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
        
        contentView.addSubview(loadingView)
        contentView.addSubview(loadingLabel)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = contentView.bounds
        
        loadingView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-4.ckValue())
            make.size.equalTo(loadingView.size)
        }
        
        loadingLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(loadingView.snp.bottom).offset(8.ckValue())
            make.width.equalToSuperview().multipliedBy(0.8)
            make.height.greaterThanOrEqualTo(0)
        }
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = MusicActionType.musictag.formatStr()
        self.navigationItem.leftBarButtonItem = self.cancelBarItem
        
        self.refreshDataAction()
    }
    
    func refreshDataAction() {
        
        self.startLoadingAction()
        
        // 1️⃣ 百度网盘
        if let baiduFile = self.musicModel.baiduFileModel, let baiduUser = baiduFile.baiduUser {
            KakaMusicPlayer.shared.fetchBaiduDownloadURL(accessToken: baiduUser.access_token, fileModel: baiduFile) { result in
                switch result {
                case .success(let downloadURL):
                    self.ffmpegGetMetadata(downloadURL)
                    break
                case .failure(let failure):
                    self.view.makeToast(failure.errorDescription)
                    self.stopLoadingAction()
                    break
                }
            }
        }
        
        // 2️⃣ Webdav
        if let webFileModel = self.musicModel.webFileModel, let downloadURL = webFileModel.mediaPlayURL {
            self.ffmpegGetMetadata(downloadURL)
        }
        
        // 3️⃣ 阿里云盘
        if let aliFileModel = self.musicModel.aliFileModel {
            KakaMusicPlayer.shared.fetchAliyunDownloadURL(fileModel: aliFileModel) { result in
                switch result {
                case .success(let downloadURL):
                    self.ffmpegGetMetadata(downloadURL)
                    break
                case .failure(let failure):
                    self.view.makeToast(failure.errorDescription)
                    self.stopLoadingAction()
                    break
                }
            }
        }
        
        // 3️⃣ 115网盘
        if let drive115Model = self.musicModel.drive115Model {
            KakaMusicPlayer.shared.fetch115DownloadPlayURL(file115: drive115Model) { result in
                switch result {
                case .success(let downloadURL):
                    self.ffmpegGetMetadata(downloadURL)
                    break
                case .failure(let failure):
                    self.view.makeToast(failure.errorDescription)
                    self.stopLoadingAction()
                    break
                }
            }
        }
        
        // 4️⃣ 谷歌网盘
        if let googleFile = self.musicModel.googleFile {
            let downloadURL = googleFile.mediaPlayURL()
            debugPrint("downloadURL = \(downloadURL)")
            self.ffmpegGetMetadata(downloadURL)
        }
        
        // 5️⃣ OneDrive
        if let onedriveFile = self.musicModel.onedriveFile {
            let downloadUrl = onedriveFile.mediaPlayURL()
            self.ffmpegGetMetadata(downloadUrl)
        }
        
        // 6️⃣ Dropbox
        if let dropboxFile = musicModel.dropboxFile {
            KakaMusicPlayer.shared.fetchDropboxDownloadPlayURL(dropboxFile: dropboxFile) { result in
                switch result {
                case .success(let downloadURL):
                    self.ffmpegGetMetadata(downloadURL)
                    break
                case .failure(let failure):
                    self.view.makeToast(failure.errorDescription)
                    self.stopLoadingAction()
                    break
                }
            }
        }
    }
    
    func ffmpegGetMetadata(_ downloadURL: URL) {
        
        DispatchQueue.main.async {
            let currentOption = KakaMusicPlayer.shared.audioOption(self.musicModel)
            KSOptions.firstPlayerType = KSMEPlayer.self
            currentOption.playerTypes = [KSMEPlayer.self]
            
            DispatchQueue.global().async {
                do {
                    let metadata = try FFmpegUtility.getMetadata(for: downloadURL, options: currentOption)
                    debugPrint("ffmpeg元数据 = \(metadata.metadata), 封面宽 = \(metadata.coverImage?.width ?? 0)")
                    DispatchQueue.main.async {
                        self.handleAudioMetadata(metadata)
                        if let cgImage = metadata.coverImage {
                            self.coverImage = UIImage(cgImage: cgImage)
                            self.stopLoadingAction()
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.showOneAlert(message: error.localizedDescription)
                        self.stopLoadingAction()
                    }
                }
            }
        }
    }
    
    // 处理内嵌元数据
    @MainActor func handleAudioMetadata(_ infoModel: VideoInfo) {
        guard var playingMusic = self.musicModel else { return }
        
        self.footStr = infoModel.metadata
            .sorted { ($0.key + $0.value).count < ($1.key + $1.value).count }
            .map { "▶️\($0.key): \($0.value)" }
            .joined(separator: "\n")
                
        let titleKeys = ["title", "TITLE", "Title"]
        let artistKeys = ["artist", "ARTIST", "Artist"]
        let albumKeys = ["album", "ALBUM", "Album", "album_artist", "album_name"]
        let yearKeys = ["date", "Date", "DATE", "year", "Year", "YEAR", "release_year", "ReleaseYear", "releaseYear"]
        let genreKeys = ["genre", "Genre", "GENRE", "style", "Style", "STYLE", "music_genre", "MusicGenre", "genre_type", "GenreType"]
        let trackKeys = ["track", "Track", "TRACK", "track_number", "TrackNumber"]
        let lyricKeys = ["lyrics", "Lyrics", "LYRICS", "©lyr", "uslt", "lyric", "LYRIC", "Lyric", "lyrics-XXX"]
        
        
        // 歌词
        if playingMusic.lyricModel == nil {
            for (key, value) in infoModel.metadata {
                // 忽略大小写匹配
                if lyricKeys.contains(where: { key.localizedCaseInsensitiveContains($0) }) {
                    let ocModel = TaglibMetadataParser.parseSynchronizedLyrics(value)
                    playingMusic.lyricModel = ocModel?.convertSwiftModel()
                    break
                }
            }
        }
        
        // 标题
        if playingMusic.title == nil {
            for key in titleKeys {
                if let title = infoModel.metadata[key] {
                    playingMusic.title = title
                    break // 找到后立即退出循环
                }
            }
        }
        
        // 艺术家
        if playingMusic.artist == nil {
            for key in artistKeys {
                if let artist = infoModel.metadata[key] {
                    playingMusic.artist = artist
                    break // 找到后立即退出循环
                }
            }
        }
        
        // 专辑
        if playingMusic.album == nil {
            for key in albumKeys {
                if let album = infoModel.metadata[key] {
                    playingMusic.album = album
                    break
                }
            }
        }
        
        // 流派
        if playingMusic.genre == nil {
            for key in genreKeys {
                if let genre = infoModel.metadata[key] {
                    playingMusic.genre = genre
                    break
                }
            }
        }
        
        // 音轨号
        if playingMusic.track == nil {
            for key in trackKeys {
                if let track = infoModel.metadata[key] {
                    playingMusic.track = Int(track)
                    break
                }
            }
        }
        
        // 年代
        if playingMusic.year == nil {
            for key in yearKeys {
                if let year = infoModel.metadata[key] {
                    if year.count > 4 {
                        let yearString = year.prefix(4)
                        playingMusic.year = Int(yearString)
                    }else{
                        playingMusic.year = Int(year)
                    }
                    break
                }
            }
        }
        
        // 注释
        if playingMusic.comment == nil {
            playingMusic.comment = infoModel.metadata["comment"]
        }
        
        
        
        // 比特率
        if playingMusic.bitrate == nil || playingMusic.bitrate == 0 {
            if let bitRate = infoModel.assetTracks.first?.bitRate, bitRate > 0 {
                playingMusic.bitrate = Int(bitRate)
                debugPrint("比特率 = \(bitRate)")
            }
        }
        
        // 采样率
        if playingMusic.sampleRate == nil || playingMusic.sampleRate == 0 {
            if let audioStream = infoModel.assetTracks.first?.audioStreamBasicDescription, audioStream.mSampleRate > 0 {
                playingMusic.sampleRate = Int(audioStream.mSampleRate)
                debugPrint("采样率 = \(audioStream.mSampleRate)")
            }
        }
        
        // 位深度
        if playingMusic.bitDepth == nil || playingMusic.bitDepth == 0 {
            if let bitDepth = infoModel.assetTracks.first?.bitDepth, bitDepth > 0 {
                playingMusic.bitDepth = Int(bitDepth)
                debugPrint("位深度 = \(bitDepth)")
            }
        }
        
        self.musicModel = playingMusic
        
        self.stopLoadingAction()
    }
    
    func startLoadingAction() {
        self.loadingView.startAnimating()
        self.loadingLabel.isHidden = false
        self.tableView.isHidden = true
        
        self.tableView.reloadData()
    }
    
    func stopLoadingAction() {
        self.loadingView.stopAnimating()
        self.loadingLabel.isHidden = true
        self.tableView.isHidden = false
        
        self.tableView.reloadData()
    }
    
    // MARK:  GET && SET
    var musicModel: MusicItemModel!
    
    var coverImage: UIImage?
    
    var footStr: String?
    
    
    // MARK:  懒加载
    lazy var cancelBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        return item
    }()
    
    lazy var dataArray: [MeteDataGroupCellModel] = {
        let model1 = MeteDataGroupCellModel(group: .headGroup, headTitle: nil, itemArray: [.headerTag], footTitle: nil)
        let model2 = MeteDataGroupCellModel(group: .basicGroup, headTitle: "*" + "Basic".localStr(), itemArray: [.title, .artist, .album, .coverImage, .lyrics], footTitle: nil)
        
        let model3 = MeteDataGroupCellModel(group: .otherGroup, headTitle: "Others".localStr(), itemArray: [.year, .genre, .trackNumber, .comment, .channel], footTitle: nil)
                        
        return [model1, model2, model3]
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.contentView.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.isHidden = true
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: kaka_IsMacOS() ? 15 : 0, left: 0, bottom: kaka_safeAreaInsets().bottom + playingHeight, right: 0)
        view.register(MusicTagHeadCell.self, forCellReuseIdentifier: "MusicTagHeadCell")
        view.register(MeteDataDetialViewCell.self, forCellReuseIdentifier: "MeteDataDetialViewCell")
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 25.ckValue(), 25.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: .lineScalePulseOutRapid, color: appMainColor)
        return view
    }()
    
    lazy var loadingLabel: UILabel = {
        let view = UILabel()
        view.isHidden = false
        view.text = "Parsing music tags...".localStr()
        view.font = UIFontLight(13.ckValue())
        view.textColor = appMainColor
        view.textAlignment = .center
        view.numberOfLines = 0
        return view
    }()
}

extension CloudMusicTagViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray[section].itemArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let groupModel = dataArray[indexPath.section]
        let itemType = groupModel.itemArray[indexPath.row]
        
        if groupModel.group == .headGroup {
            let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTagHeadCell", for: indexPath) as! MusicTagHeadCell
            return cell
        } else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "MeteDataDetialViewCell", for: indexPath) as! MeteDataDetialViewCell
            cell.update(model: self.musicModel, itemType: itemType, coverImage: self.coverImage, fileSize: "")
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let groupModel = dataArray[indexPath.section]
        if groupModel.group == .headGroup { return }
        
        self.showOneAlert(message: "Download the file before editing its embedded tags.".localStr())
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let groupModel = dataArray[indexPath.section]
        let itemType = groupModel.itemArray[indexPath.row]
        
        return itemType == .coverImage ? 100.ckValue() : UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        return groupModel.headTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        return groupModel.group == .otherGroup ? self.footStr : groupModel.footTitle
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
}

