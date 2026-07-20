//
//  GCDWebServerController.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/3/27.
//

import KakaFoundation
import GCDWebServer
import KakaUIKit
import AppGroupKit
import FLAnimatedImage
import AVKit
import NVActivityIndicatorView
import StoreKit

class GCDWebServerController: SuperViewController {
    
    deinit {
        try? FileManager.default.removeItem(atPath: SandboxType_WifiPC)
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
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        headerView.frame = CGRectMake(0, 0, contentView.width, imageHeight)
        
        tableView.frame = self.view.bounds
        
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = ImportFileType.fromWiFi.titleStr()
        
//#warning("模拟mock数据")
//        for index in 0..<12 {
//            let name = "singer_\(index + 1)@3x.png"
//            var model = MusicItemModel()
//            model.title = name
//            self.dataArray.append(model)
//        }
                
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelBarClick))
        }
        
        let techItem = UIBarButtonItem(image: Reasource.systemNamed("questionmark.video").sfHorizontallyImage(), style: .plain, target: self, action: #selector(supportVideoClick))
        if #available(iOS 26.0, *) {
            techItem.hidesSharedBackground = true
        }
        self.navigationItem.rightBarButtonItem = techItem
        
        self.refreshDataAction()
        
        // 监听网络变化
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilitySwiftChanged, object: reachability)
        
        NotificationCenter.default.addObserver(self, selector: #selector(purchageSuccessNoti(_:)), name: Notification.Name(kPurchageSuccessKey), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(purchageSuccessNoti(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func refreshDataAction() {
        
        if self.webServer.isRunning {
            self.webServer.stop()
        }
        
        // 生成一个随机端口号，范围从 1024 到 65535
        let randomPort = UInt(arc4random_uniform(64512)) + 1024

        self.webServer.start(withPort: randomPort, bonjourName: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] () in
            self?.tableView.reloadData()
            self?.kaka_header.endRefreshing()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        try? self.reachability.startNotifier()
    }
    
    // 网络状态变化了
    @objc func reachabilityChanged(note: Notification) {
        guard let reachability = note.object as? ReachabilitySwift else { return }
                
        self.netConnect = reachability.connection
        
        if reachability.connection == .unavailable {
            
            let alertController: UIAlertController = UIAlertController(title: "Reminder".localStr(), message: "Even though this is an offline music player, we still need your unlimited LAN access. Otherwise, we can't finish importing music files over Wi-Fi!".localStr(), preferredStyle: .alert)
            let action: UIAlertAction = UIAlertAction(title: "Settings".localStr(), style: .default) { (sender) in
                guard let vURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(vURL)
            }
            
            alertController.addAction(action)
            self.present(alertController, animated: true, completion: nil)
            
            self.alertController = alertController
            return
        }
        
        self.alertController?.dismiss(animated: false)
    }
    
    // 监听支付成功，提示配置。
    @objc func purchageSuccessNoti(_ noti: Notification) {
        self.tableView.reloadData()
    }
    
    @objc func supportVideoClick() {
        
        self.changeDeviceOrientation()
        
        let fileURL = URL(fileURLWithPath: Reasource.fullFilePath("sync_wifi_en.mov"))
                
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
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    @objc func cancelBarClick() {
        
        if self.isUploading {
            self.showTwoAlert(title: "Reminder".localStr(), message: "The files are in transit and will not continue when closed. Are you sure to close?".localStr()) { [weak self] () in
                self?.isUploading = false
                self?.cancelBarClick()
            }
            return
        }
        
        DispatchQueue.global().async { [weak self] () in
            self?.webServer.stop()
        }
                
        if self.isPresent() {
            (self.navigationController ?? self)?.dismiss(animated: true)
        }else{
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    // MARK:  GET && SET 
    
    weak var viewModel: MusicViewModel!
        
    var playIndex: Int = -1
        
    var alertController: UIViewController?
        
    lazy var dataArray: [MusicItemModel] = {
        return [MusicItemModel]()
    }()
    
    var netConnect: ReachabilitySwift.Connection = .unavailable
    
    lazy var reachability: ReachabilitySwift = {
        return try! ReachabilitySwift()
    }()
    
    // 正在传输文件
    var isUploading: Bool = false {
        didSet {
            self.headerView.isLoading = isUploading
        }
    }
        
    var imageHeight: CGFloat {
        get {
            let tempView = GCDTableHeadView()
            let sideSpace = kaka_IsiPad() ? 40.ckValue() : 20.ckValue()
            let phoneWidth = kaka_IsiPad() ? 90.ckValue() : 60.ckValue()
            
            let macWidth = self.view.width - phoneWidth - sideSpace * 2 - sideSpace * 4
            let macHeight = macWidth * (tempView.macImgView.image!.size.height / tempView.macImgView.image!.size.width)
            
            return macHeight + sideSpace * 2 + (kaka_IsiPad() ? -50.ckValue() : 10.ckValue())
        }
    }
    
    
    var tmpFolderPath: String {
        get {
            let folderPath = SandboxType_WifiPC

            if !FileManager.default.fileExists(atPath: folderPath) {
                try? FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
            }
            
            debugPrint("🦌文件地址 = \(folderPath)")
            
            return folderPath
        }
    }
    
    
    // MARK:  懒加载 
    lazy var webServer: GCDWebUploader = {
        let auduoTypes: [String] = (["LRC"] + AudioExtension.audioSuffixs).map({ $0.lowercased() })
        
        let appVersion = (Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        let appBuildVersion = Bundle.main.infoDictionary!["CFBundleVersion"] as? String
        
        let server = GCDWebUploader(uploadDirectory: self.tmpFolderPath)
        server.delegate = self
        server.title = "🎵" + "Wake Music".localStr()
        server.footer = "Wake Music".localStr() + " \(appVersion) " + "(\(appBuildVersion ?? "99"))"
        server.prologue = "Drag and drop music files into this window or click the Upload File button. Please keep the screen on while transferring.".localStr()
        server.epilogue = auduoTypes.map({ $0.uppercased() }).joined(separator: ", ") + "..."
        server.allowedFileExtensions = auduoTypes
        server.allowHiddenItems = true
        return server
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
#if !targetEnvironment(macCatalyst)
view.refreshControl = self.kaka_header
#endif
        view.tableHeaderView = self.headerView
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(GCDURLTableViewCell.self, forCellReuseIdentifier: "GCDURLTableViewCell")
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
        view.register(HowtoImportTableCell.self, forCellReuseIdentifier: "HowtoImportTableCell")
        return view
    }()
    
    lazy var kaka_header: UIRefreshControl = {
        let view = UIRefreshControl()
        view.top = self.navigationController?.navigationBar.height ?? app_navHeight
        view.size = CGSizeMake(30.ckValue(), 30.ckValue())
        view.tintColor = .label
        view.addTarget(self, action: #selector(refreshDataAction), for: .valueChanged)
        return view
    }()
    
    lazy var headerView: GCDTableHeadView = {
        let view = GCDTableHeadView(frame: CGRectMake(0, 0, self.view.width, imageHeight))
        return view
    }()
    
}


extension GCDWebServerController: UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : (dataArray.count == 0 ? 1 : dataArray.count)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "GCDURLTableViewCell", for: indexPath) as! GCDURLTableViewCell
            cell.webUrl = self.webServer.serverURL
            return cell
        }else{
            if self.dataArray.count == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "HowtoImportTableCell", for: indexPath) as! HowtoImportTableCell
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
                let model = self.dataArray[indexPath.row]
                cell.update(musicModel: model, cellType: .none)
#warning("模拟mock数据")
//                #if DEBUG
//                cell.nameLabel.text = "Music 00\(indexPath.row + 1).dsd"
//                cell.singerLabel.text = "Wake Music".localStr()
//                let name = "singer_\(indexPath.row + 1)@3x.png"
//                let coverURL = URL(fileURLWithPath: Reasource.fullFilePath(name))
//                cell.coverImgView.kf.setImage(with: coverURL, placeholder: UIImage(named: "music_place"))
//                #endif
                return cell
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            
            tableView.deselectRow(at: indexPath, animated: true)
            
            guard let curCell = tableView.cellForRow(at: indexPath) as? GCDURLTableViewCell else { return }
            guard let serverURL = self.webServer.serverURL else {
                curCell.kaka_playShakeAnim()
                return
            }
            
            curCell.webUrl = serverURL

            let shareVC = UIActivityViewController(activityItems: [serverURL], applicationActivities: nil)
            if !kaka_IsiPhone() {
                shareVC.popoverPresentationController?.sourceView = curCell.contentView
                curCell.copyButton.isSelected = true
            }
            self.present(shareVC, animated: true, completion: nil)
            
            UIPasteboard.general.string = serverURL.absoluteString
            shareVC.view.makeToast("Copied".localStr())
        }else{
            
            if dataArray.count == 0 {
                tableView.deselectRow(at: indexPath, animated: true)
                self.supportVideoClick()
                return
            }
            
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 50.ckValue() : (dataArray.count == 0 ? (kaka_IsiPhone() ? 220.ckValue() : 380.ckValue()) : UITableView.automaticDimension)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return nil
        }else{
            var totalSize: UInt64 = 0
            let _ = self.dataArray.map {
                totalSize += $0.mediaPlayURL.fileSize
            }
            
            let formatSize = URL.formatFileSize(totalSize)
            
            let useStr = String(format: "%d Files Imported".localStr(), dataArray.count) + "  " + formatSize
            return dataArray.count == 0 ? "How to use?".localStr() : useStr
        }
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "Please make sure the current device is connected to the same Wi-Fi as your computer or Android phone, and keep the screen on during transmission❗️".localStr()
        }else{
            return self.webServer.epilogue
        }
    }
    
}

// MARK:  头部 
class GCDTableHeadView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        self.addSubview(macImgView)
        self.addSubview(phoneImgView)
        self.addSubview(lineView)
        self.addSubview(arrowView)
        self.addSubview(loadingView)
    }
    
    private func preSetupContains() {
        let sideSpace = kaka_IsiPad() ? 40.ckValue() : 20.ckValue()
        let phoneWidth = kaka_IsiPad() ? self.width * 0.2 : 60.ckValue()
        let phoneHeight = phoneWidth * (phoneImgView.image!.size.height / phoneImgView.image!.size.width)
        
        let macWidth = self.width - phoneWidth - sideSpace * 2 - sideSpace * 4
        let macHeight = macWidth * (macImgView.image!.size.height / macImgView.image!.size.width)

        macImgView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(sideSpace)
            make.bottom.equalToSuperview().inset(20.ckValue())
            make.width.equalTo(macWidth)
            make.height.equalTo(macHeight)
        }
        
        phoneImgView.snp.makeConstraints { make in
            make.bottom.equalTo(macImgView).offset(-1.ckValue())
            make.trailing.equalToSuperview().inset(sideSpace)
            make.width.equalTo(phoneWidth)
            make.height.equalTo(phoneHeight)
        }
        
        arrowView.snp.makeConstraints { make in
            make.centerY.equalTo(phoneImgView)
            make.trailing.equalTo(phoneImgView.snp.leading)
            make.width.equalTo(12.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        lineView.snp.makeConstraints { make in
            make.leading.equalTo(macImgView.snp.trailing).offset(-15.ckValue())
            make.trailing.equalTo(arrowView.snp.leading).offset(2.ckValue())
            make.centerY.equalTo(arrowView)
            make.height.equalTo(2.ckValue())
        }
        
        loadingView.snp.makeConstraints { make in
            make.centerY.equalTo(lineView)
            make.centerX.equalTo(lineView)
            make.size.equalTo(loadingView.layer.cornerRadius * 2)
        }
    }
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
    }
    
    var isLoading: Bool = false {
        didSet {
            if isLoading {
                loadingView.startAnimating()
            }else{
                loadingView.stopAnimating()
            }
        }
    }
    
    lazy var macImgView: UIImageView = {
        let view = UIImageView(image: Reasource.named("wifi_mac"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var phoneImgView: UIImageView = {
        let view = UIImageView(image: Reasource.named(kaka_IsiPad() ? "wifi_ipad" : "wifi_iphone"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var lineView: KakaHorizontalDashxianView = {
        let view = KakaHorizontalDashxianView(lineColor: UIColor.secondaryLabel, lineLength: 2.ckValue(), lineSpacing: 2.ckValue())
        return view
    }()
    
    lazy var loadingView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.color = .label
        view.backgroundColor = self.backgroundColor
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 10.ckValue()
        return view
    }()
    
    lazy var arrowView: UIImageView = {
        let image = Reasource.systemNamed("chevron.forward.2", color: lineView.lineColor)
        let view = UIImageView(image: image.flippedImage())
        view.contentMode = .scaleAspectFit
        return view
    }()
}


// MARK:  链接 
class GCDURLTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.accessoryType = .disclosureIndicator
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var webUrl: URL? {
        didSet {
            self.accessoryView = self.copyButton
            
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = webUrl?.absoluteString ?? "Please connect to Wi-Fi".localStr()
            cellConfig.textProperties.font = UIFontBold(14.ckValue())
            cellConfig.textProperties.color = webUrl?.absoluteString.count == 0 ? UIColor.orange : UIColor.label
            self.contentConfiguration = cellConfig
        }
    }
    
    lazy var copyButton: UIButton = {
        let view = UIButton()
        view.isUserInteractionEnabled = false
        view.setImage(Reasource.systemNamed("doc.on.doc", color: UIColor.label), for: .normal)
        view.setImage(Reasource.systemNamed("doc.on.doc.fill", color: UIColor.label), for: .selected)
        view.size = CGSize(width: 25.ckValue(), height: 25.ckValue())
        view.imageView?.contentMode = .scaleAspectFit
        return view
    }()
    
}


class HowtoImportTableCell: UITableViewCell {
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
        contentView.addSubview(coverImgView)
        contentView.addSubview(playButton)
    }
    
    private func preSetupContains() {
        coverImgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        playButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(48.ckValue())
        }
    }
    
    
    private func preSetupHandleBuness() {
        self.selectionStyle = .none
        self.accessoryType = .none
    }
    
    // MARK:  GET && SET
    
    // MARK:  懒加载
    lazy var coverImgView: UIImageView = {
        let view = UIImageView(image: Reasource.named("sync_tech_bg"))
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()
    
    lazy var playButton: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(named: "video_play")
        return view
    }()
    
}


class KakaAVPlayerViewController: AVPlayerViewController {
    
    deinit {
        
        debugPrint("### KakaAVPlayerViewController ###")
        
        
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            
#if targetEnvironment(macCatalyst)
//            if let titleBar = windowScene.titlebar,
//               let sizes = windowScene.sizeRestrictions {
//                titleBar.titleVisibility = .visible
//            }
#else
            self.setNeedsUpdateOfSupportedInterfaceOrientations()
            self.navigationController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                debugPrint("切换失败 = \(error.localizedDescription)")
            }
#endif
            
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.overrideUserInterfaceStyle = .dark
        self.view.overrideUserInterfaceStyle = .dark
        
        self.view.tintColor = .white
        
        if KakaMusicPlayer.shared.isPlaying {
            KakaMusicPlayer.shared.pause()
        }
        
        self.player?.play()
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.overrideUserInterfaceStyle == .dark ? .lightContent : .default
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
        
}
