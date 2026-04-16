//
//  VideoConverterViewController.swift
//  Wake Music
//
//  Created by Melo on 9/10/24.
//

import KakaFoundation
import AppGroupKit
import CoreServices
import AVFoundation
import AVKit
import KakaPhotoBrowser
import SafariServices


/// 视频封面，音乐名称、
class VideoConverterViewController: SuperViewController {
    
    deinit {
        SandboxFileManager.shared.deleteOtherTempFiles()
    }
    
    init(viewModel: MusicViewModel!) {
        super.init(nibName: nil, bundle: nil)
        self.viewModel = viewModel
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
#warning("模拟mock数据")
//        self.navigationController?.overrideUserInterfaceStyle = .light
//        self.overrideUserInterfaceStyle = .light
//        self.tableView.overrideUserInterfaceStyle = .light
        
        super.preSetupSubViews()
        
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = self.view.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.navigationItem.largeTitleDisplayMode = .never
        self.title = ImportFileType.fromVideos.titleStr()
                
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelBarClick))
        }
    }
    
    @objc func cancelBarClick() {
        
        if self.videoCell?.loadingView.isAnimating ?? false {
            self.showTwoAlert(title: "Reminder".localStr(), message: "The files are in transit and will not continue when closed. Are you sure to close?".localStr()) { [weak self] () in
                self?.videoCell?.stopLoading()
                self?.cancelBarClick()
            }
            return
        }
        
        if self.isPresent() {
            (self.navigationController ?? self)?.dismiss(animated: true)
        }else{
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }
    
    
    

    
    // MARK:  GET && SET
    var videoCell: VideoImporterViewCell? {
        get {
            return self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? VideoImporterViewCell
        }
    }
    
    var videoURL: URL?
    
    var coverImage: UIImage?
    
    var musicModel: MusicItemModel?
    
    weak var viewModel: MusicViewModel!
        
    // 是否自动裁剪最后3秒钟
    var isAutoCropAudio:Bool {
        get {
            if !UserInfoManager.shared.isVIP() {
                return false
            }else{
                return MusicConfigManager.shared.isAutoCrop
            }
        }
    }
    
    let audioType = AudioFormatEnum.alac
    
    lazy var dataArray: [[VideoAudioInfoType]] = {
        let model1: [VideoAudioInfoType] = [.selectVideo, .selectSuffix, .autoCropAudio]
        let model2: [VideoAudioInfoType] = [.musicName, .singerName, .albumName, .coverImage, .fileSize]
        return [model1, model2]
    }()
    
    // MARK:  懒加载
    
    var audioSeccsion: AVAssetExportSession?
    
    lazy var timer: KakaTimer = {
        return KakaTimer()
    }()
    
    var audioOutputURL: URL?
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: contentView.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.separatorStyle = .singleLine
        view.tableHeaderView = self.headView
        view.register(AudioSuffixViewCell.self, forCellReuseIdentifier: "AudioSuffixViewCell")
        view.register(VideoImporterViewCell.self, forCellReuseIdentifier: "VideoImporterViewCell")
        view.register(VideoAudioInfoViewCell.self, forCellReuseIdentifier: "VideoAudioInfoViewCell")
        return view
    }()
    
    lazy var headView: UITableViewHeaderFooterView = {
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 150
        }
        
        var iconImage: UIImage?
        if #available(iOS 17.0, *) {
            iconImage = UIImage(systemName: "video.badge.waveform.fill")
        }else{
            iconImage = UIImage(systemName: "arrow.up.right.video")
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
    
}

extension VideoConverterViewController: UITableViewDataSource, UITableViewDelegate, AudioSuffixViewCellDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.musicModel == nil ? 1 : dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let action = dataArray[indexPath.section][indexPath.row]
        
        if action == .selectVideo {
            let cell = tableView.dequeueReusableCell(withIdentifier: "VideoImporterViewCell", for: indexPath) as! VideoImporterViewCell
            cell.fileURL = self.videoURL
            return cell
        }else if action == .selectSuffix || action == .autoCropAudio {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AudioSuffixViewCell", for: indexPath) as! AudioSuffixViewCell
            cell.delegate = self
            cell.update(cellType: action, audioType: audioType, isCrop: isAutoCropAudio)
            cell.accessoryView?.isUserInteractionEnabled = self.videoURL == nil
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "VideoAudioInfoViewCell", for: indexPath) as! VideoAudioInfoViewCell
            cell.update(type: action, model: self.musicModel, coverImage: self.coverImage)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let action = dataArray[indexPath.section][indexPath.row]
        
        if action == .selectVideo {
            guard let _ = self.musicModel, let videoURL = self.videoURL else {
                self.selectVideoAction()
                return
            }
            
            self.clickVideoCell(videoURL)
        }
        
        if action == .autoCropAudio {
            if UserInfoManager.shared.isVIP() {
                if self.videoURL != nil {
                    self.view.makeToast("Please set before selecting the video".localStr())
                }
            }else{
                self.vipCenterClick()
            }
        }
        
        if action == .selectSuffix {
            self.showOneAlert(title: "Reminder".localStr(), message: "M4A(Alac) is Apple's own lossless audio format, and you'll get an M4A audio with minimal size but minimal audio loss, which is the same lossless audio format used by Apple Music.".localStr(), confirm: "OK".localStr())
        }
        
        if action == .musicName {
            self.handleEditMusic(.title)
        }
        
        if action == .albumName {
            self.handleEditMusic(.album)
        }
        
        if action == .singerName {
            self.handleEditMusic(.artist)
        }
        
        if action == .coverImage {
            if kaka_IsMacOS() { return }
            guard let coverCell = tableView.cellForRow(at: indexPath) as? VideoAudioInfoViewCell else { return }
            let photoItem = KakaPhotoItem(sourceView: coverCell.coverImgView, image: coverCell.coverImgView.image)
            let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
            photoBrowser.backgroundStyle = .blurPhoto
            photoBrowser.show(from: self)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let action = dataArray[indexPath.section][indexPath.row]

        if action == .selectVideo {
            return kaka_IsiPhone() ? 160.ckValue() : 200.ckValue()
        }else if action == .pcmUI {
            return 100.ckValue()
        }else if action == .coverImage {
            return 80.ckValue()
        }else{
            return 50.ckValue()
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return "Edit".localStr()
        }else{
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "Turn off this switch if the last 3 seconds of the original video do not contain the advertisement sound".localStr()
        }else{
            return nil
        }
    }
    
    // 配置开关
    func audioSuffixSelected(cell: AudioSuffixViewCell, audioType: AudioFormatEnum) {
        if UserInfoManager.shared.isVIP() {
            MusicConfigManager.shared.lastAudioFormat = audioType
            self.tableView.reloadData()
        }else{
            if audioType == .mp3 || audioType == .aac {
                MusicConfigManager.shared.lastAudioFormat = audioType
                self.tableView.reloadData()
            }else{
                self.vipCenterClick()
            }
        }
        
    }
    
    func audioSuffixAutoCrop(cell: AudioSuffixViewCell, isCrop: Bool) {
        MusicConfigManager.shared.isAutoCrop = isCrop
    }
}

