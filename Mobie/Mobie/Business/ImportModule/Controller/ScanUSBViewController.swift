//
//  ScanUSBViewController.swift
//  Mobie
//
//  Created by 张文 on 10/16/24.
//

import KakaFoundation
import AppGroupKit
import KakaObjcKit
import SafariServices
import StoreKit
import KakaTaglibKit
import AVFoundation

enum iTunesChannel: Int {
    case iTunes = 0
    case iMazing = 1
    case iTool4 = 4
    
    func formatStr() -> String {
        switch self {
        case .iTunes:
            return "iTunes"
        case .iMazing:
            return "iMazing"
        case .iTool4:
            return PhoneSetManager.formatLanguage() == .chinese_simplified ? "爱思助手" : "iTools"
        }
    }
    
    func iconImage() -> UIImage? {
        switch self {
        case .iTunes:
            return Reasource.systemNamed("applelogo", color: .label)
        case .iMazing:
            return Reasource.systemNamed("hand.thumbsup.fill", color: .systemRed)
        case .iTool4:
            return Reasource.systemNamed("u.circle", color: UIColor.systemBlue)
        }
    }
    
    func websiteURL() -> URL? {
        switch self {
        case .iMazing:
            let languages = ["en", "zh", "de", "fr", "es", "it", "pt", "uk", "ru", "ar", "ja", "ko"]
            let myLanguage = PhoneSetManager.formatLanguage()
            let language = languages.filter { myLanguage.rawValue.contains($0) }.first ?? ""
            
            return URL(string: "https://imazing.com/\(language)")
        case .iTunes:
            return URL(string: "https://support.apple.com/guide/itunes/wi-fi-syncing-itns3751d862/12.13/windows/10")
            
        case .iTool4:
            return URL(string: StringEncoder.itoolsURL())
        }
    }
}

class ScanUSBViewController: SuperViewController {
    
    deinit {
        self.folderWatcher.stopWatching()
    }
    
    init(_ viewModel: MusicViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        self.title = ImportFileType.fromUSB.titleStr()
        
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = self.view.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelBarClick))
        }
        
        self.folderWatcher.startWatching()
        
        self.navigationItem.rightBarButtonItem = self.videoBarItem

#warning("模拟mock数据")
//        self.navigationController?.overrideUserInterfaceStyle = .light
//        self.overrideUserInterfaceStyle = .light
//        self.tableView.overrideUserInterfaceStyle = .light
        
    }
    
    @objc func cancelBarClick() {
        self.navigationController?.dismiss(animated: true)
    }
    
    // MARK:  GET && SET
    
    var isUploading: Bool = false
    
    let videoURL = Reasource.fullFilePath("sync_usb_en.mp4")
        
    weak var viewModel: MusicViewModel!
    
    lazy var folderWatcher: DocumentFolderWatcher = {
        let baseFileURL = SandboxFileManager.shared.basePublicFileURL()
        let watcher = DocumentFolderWatcher(baseFileURL)
        watcher.delegate = self
        return watcher
    }()
    
    // MARK:  懒加载
    lazy var dataArray: [iTunesChannel] = {
        return PhoneSetManager.formatLanguage() == .chinese_simplified ? [.iTunes, .iMazing, .iTool4] : [.iTunes, .iMazing]
    }()
    
    lazy var fileArray: [URL] = {
        return [URL]()
    }()
    
    lazy var videoBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: Reasource.systemNamed("questionmark.video").sfHorizontallyImage(), style: .plain, target: self, action: #selector(supportVideoClick))
        if #available(iOS 26.0, *) {
            item.hidesSharedBackground = true
        }
        return item
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(HowtoImportTableCell.self, forCellReuseIdentifier: "HowtoImportTableCell")
        view.register(ScaniTunesHeadViewCell.self, forCellReuseIdentifier: "ScaniTunesHeadViewCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "LocalDocTableViewCell")
        return view
    }()
    
}

extension ScanUSBViewController: UITableViewDataSource, UITableViewDelegate, DocumentFolderWatcherDelegate {
    
    func documentFolderWatcherDidAddFiles(watcher: DocumentFolderWatcher, addFiles: [URL]) {
        DispatchQueue.main.async {
            self.fileArray.append(contentsOf: addFiles)
            let countStr = "\(self.fileArray.count)"
            self.view.makeToast(countStr)
        }
    }
    
    func documentFolderWatcherDidDeleteFiles(watcher: DocumentFolderWatcher, deleteFiles: [URL]) {
        DispatchQueue.main.async {
            for subURL in deleteFiles {
                if let index = self.fileArray.firstIndex(where: { $0 == subURL }) {
                    self.fileArray.remove(at: index)
                }
            }
            
            let countStr = "\(self.fileArray.count)"
            self.view.makeToast(countStr)
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 1 ? dataArray.count : 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ScaniTunesHeadViewCell", for: indexPath)
            return cell
        }else if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LocalDocTableViewCell", for: indexPath)
            let subChannel = dataArray[indexPath.row]
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.image = subChannel.iconImage()
            cellConfig.text = subChannel.formatStr()
            cellConfig.textProperties.color = .label
            cellConfig.imageProperties.maximumSize = CGSizeMake(30.ckValue(), 30.ckValue())
            cell.contentConfiguration = cellConfig
            cell.accessoryType = .disclosureIndicator
            cell.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 25, leading: 15, bottom: 25, trailing: 15)
            return cell
            
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "HowtoImportTableCell", for: indexPath) as! HowtoImportTableCell
            cell.coverImgView.image = URL(fileURLWithPath: self.videoURL).getVideoThumbnail()
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 1 {
            let subChannel = dataArray[indexPath.row]
            guard let vURL = subChannel.websiteURL() else { return }
            let webVC = SFSafariViewController(url: vURL)
            webVC.preferredControlTintColor = appMainColor
            self.present(webVC, animated: true)
        }
        
        if indexPath.section == 2 {
            if let _ = tableView.cellForRow(at: indexPath) as? HowtoImportTableCell {
                self.supportVideoClick()
            }
        }
    }
    
    @objc func supportVideoClick() {
        
        self.changeDeviceOrientation()
        
        let fileURL = URL(fileURLWithPath: self.videoURL)
                
        let player = AVPlayer(url: fileURL)
        let playerViewController = KakaAVPlayerViewController()
        playerViewController.player = player
        playerViewController.entersFullScreenWhenPlaybackBegins = true
        playerViewController.exitsFullScreenWhenPlaybackEnds = true
        self.present(playerViewController, animated: true)
        
    }
    
    // 设置横竖屏
    func changeDeviceOrientation() {
        
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

            #if targetEnvironment(macCatalyst)
            if let titleBar = windowScene.titlebar,
               let sizes = windowScene.sizeRestrictions {
                titleBar.titleVisibility = .hidden
                titleBar.toolbar = nil
                sizes.minimumSize = windowScene.screen.bounds.size
                sizes.maximumSize = windowScene.screen.bounds.size
            }
            #else
            self.setNeedsUpdateOfSupportedInterfaceOrientations()
            self.navigationController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { error in
                debugPrint("切换失败 = \(error.localizedDescription)")
            }
            #endif
            
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
        
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return UITableView.automaticDimension
        }else if indexPath.section == 1 {
            return 60.ckValue()
        }else{
            return (kaka_IsiPhone() ? 220 : 400)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return nil
        }else{
            return section == 1 ? "Recommended Tools".localStr() : "How to use?".localStr()
        }
    }
    
}

class ScaniTunesHeadViewCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        contentView.addSubview(starImgView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descLabel)
    }
    
    private func preSetupContains() {
        descLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.greaterThanOrEqualTo(0)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.bottom.equalTo(descLabel.snp.top).offset(-6.ckValue())
            make.leading.equalToSuperview()
            make.height.greaterThanOrEqualTo(0)
            make.centerX.equalToSuperview()
        }
        
        starImgView.snp.makeConstraints { make in
            make.bottom.equalTo(titleLabel.snp.top).offset(-15.ckValue())
            make.centerX.equalToSuperview()
            make.size.equalTo(kaka_IsiPhone() ? 120.ckValue() : 280.ckValue())
            make.top.equalToSuperview()
        }
    }
    
    
    private func preSetupHandleBuness() {
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        
    }
    
    // MARK:  GET && SET
    
    // MARK:  懒加载
    lazy var starImgView: UIImageView = {
        let view = UIImageView(image: ImportFileType.fromUSB.iconImage())
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.text = "Fastest way to import".localStr()
        view.font = UIFontBold(20.ckValue())
        view.numberOfLines = 0
        view.textAlignment = .center
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textColor = .label
        view.text = "Connect your Mac or Windows computer via USB and with the help of our recommended tools (iTunes, iMazing), quickly import your files to a folder within the application".localStr()
        view.font = UIFontLight(14.ckValue())
        view.textAlignment = .center
        return view
    }()
    
}

