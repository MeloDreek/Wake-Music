//
//  ConnectListViewController.swift
//  Mobie
//
//  Created by 张文 on 1/2/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import FilesProvider
import ProgressHUD
import Combine
import GoogleSignIn
import SwiftyDropbox
import AliyunpanSDK
import MessageUI
import SafariServices


// 已添加的服务器列表
class ConnectListViewController: SuperViewController {
    private struct ConnectedEntry {
        let sourceIndex: Int
        let server: ServerConfigModel
    }

    private struct ConnectSection {
        let group: ImportGroupType?
        let availableTypes: [ImportFileType]
        let connectedEntries: [ConnectedEntry]
    }

    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = KakaTabbarType.connect.formatStr()
        self.navigationItem.largeTitleDisplayMode = .never
        
        // 新增了下载文件
        DownloadManager.shared.$taskArray.receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.setupNavigationItem()
            }.store(in: &cancellables)
                
        // 新增\更新服务器
        ConnectConfigManager.shared.$connectedModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] models in
                self?.refreshDataAction()
        }.store(in: &cancellables)
    }
    
    @objc func refreshDataAction() {
        self.connectArray = ConnectConfigManager.shared.connectedModels
                
        self.tableView.reloadData()
        
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.5) { [weak self] () in
            self?.kaka_header.endRefreshing()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupNavigationItem()
    }
    
    @objc func setupNavigationItem() {
        
        self.navigationItem.rightBarButtonItems = kaka_IsMacOS() ? [self.importBarItem()] : [self.downloadBarItem(), self.importBarItem()]
    }
    
    
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()

    var downloadVC: DownloadViewController?
    
    var onSelectBlock: ((ServerConfigModel?)->Void)?
    
    lazy var connectArray: [ServerConfigModel] = {
        return [ServerConfigModel]()
    }()
    
    private lazy var availableServerTypes = ImportFileType.serverDriveArray()
    private lazy var availableCloudTypes = ImportFileType.cloudDriveArray()

    /// Show provider categories only before the first connection. Once connected,
    /// each saved account gets its own section in the persisted order.
    private var connectSections: [ConnectSection] {
        if connectArray.isEmpty {
            return [
                ConnectSection(group: .remoteServerGroup, availableTypes: availableServerTypes, connectedEntries: []),
                ConnectSection(group: .remoteCloudGroup, availableTypes: availableCloudTypes, connectedEntries: [])
            ]
        }

        return connectArray.enumerated().map { index, server in
            ConnectSection(group: nil, availableTypes: [],
                           connectedEntries: [ConnectedEntry(sourceIndex: index, server: server)])
        }
    }
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
        view.allowsMultipleSelection = true
#if !targetEnvironment(macCatalyst)
        view.refreshControl = self.kaka_header
#endif
        view.allowsMultipleSelectionDuringEditing = true
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.tableHeaderView = self.headView
        view.register(ImportTableViewCell.self, forCellReuseIdentifier: "ImportTableViewCell")
        view.register(ConnectListTableCell.self, forCellReuseIdentifier: "ConnectListTableCell")
        return view
    }()
    
    lazy var headView: UITableViewHeaderFooterView = {
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 100
        }
        
        let iconImage = UIImage(systemName: "externaldrive.fill.badge.wifi")
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
        view.top = self.navigationController?.navigationBar.height ?? app_navHeight
        view.size = CGSizeMake(30.ckValue(), 30.ckValue())
        view.tintColor = .label
        view.addTarget(self, action: #selector(refreshDataAction), for: .valueChanged)
        return view
    }()
    
    // 连接更多
    func importBarItem() -> UIBarButtonItem {
        let item = UIBarButtonItem(image: Reasource.systemNamed("plus"), style: .plain, target: self, action: #selector(importMusicClick))
        item.accessibilityLabel = "Import Music".localStr()
        return item
    }
    
    // 下载队列
    func downloadBarItem() -> UIBarButtonItem {
        let item = UIBarButtonItem(image: Reasource.systemNamed("arrow.down.circle"), style: .plain, target: self, action: #selector(downloadQueueAction))
        item.accessibilityLabel = "Download".localStr()
        if #available(iOS 26.0, *) {
            item.badge = self.downloadBadge()
        }
        return item
    }
    
    @available(iOS 26.0, *)
    func downloadBadge() -> UIBarButtonItem.Badge? {
        let taskArray = DownloadManager.shared.taskArray
        
        if taskArray.isEmpty {
            return nil
        }else{
            var badge = UIBarButtonItem.Badge.count(taskArray.count)
            badge.backgroundColor = UIColor.red
            return badge
        }
    }
    
    @objc func downloadQueueAction() {
        let downloadVC = self.downloadVC ?? DownloadViewController()
        self.downloadVC = downloadVC
        
        let navVC = KakaNavigationController(rootViewController: downloadVC)
        navVC.modalPresentationStyle = .automatic
        self.currentViewController()?.present(navVC, animated: true)
    }
    
    @objc func importMusicClick() {
        let importVC = ImportViewController()
        let navVC = KakaNavigationController(rootViewController: importVC)
        navVC.modalPresentationStyle = kaka_IsMacOS() ? .formSheet : .fullScreen
        self.present(navVC, animated: true)
    }
    
}

extension ConnectListViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        connectSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let group = connectSections[section]
        return connectArray.isEmpty ? group.availableTypes.count : group.connectedEntries.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if connectArray.count == 0 {
            let subType = connectSections[indexPath.section].availableTypes[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "ImportTableViewCell", for: indexPath) as! ImportTableViewCell
            cell.updateItemType(itemType: subType)
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConnectListTableCell", for: indexPath) as! ConnectListTableCell
            let server = connectSections[indexPath.section].connectedEntries[indexPath.row].server
            cell.serverModel = server
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        
        if connectArray.count == 0 {
            // 首次连接
            let itemType = connectSections[indexPath.section].availableTypes[indexPath.row]
            self.connectNewServer(itemType)
        }else{
            // 访问网盘
            let entry = connectSections[indexPath.section].connectedEntries[indexPath.row]
            var subModel = entry.server
            subModel.isSelected = true
        
            let tempArray = self.connectArray.enumerated().map { index, server in
                var tempModel = server
                tempModel.isSelected = index == entry.sourceIndex
                return tempModel
            }
            
            ConnectConfigManager.shared.connectedModels = tempArray
            
            self.accessLoginedServer(subModel)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if connectArray.isEmpty && section == connectSections.count - 1 {
            return connectionFeedbackFooter(feedbackAction: #selector(handleWithEmail))
        }else{
            return nil
        }
        
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        connectSections[section].group?.localizedTitle
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return connectArray.count == 0 ? false : true
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if connectArray.count == 0 {
            return nil
        }
        
        let subServer = connectSections[indexPath.section].connectedEntries[indexPath.row].server
        
        // 删除
        let deleteAction = UIContextualAction(style: .normal, title: nil) { [weak self] action, view, finish in
            guard let wSelf = self else { return }
            wSelf.showTwoAlert(message: "Are you sure to delete it?".localStr(), confirm: "Delete".localStr(), cancle: "Cancel".localStr(), style: kaka_IsiPhone() ? .actionSheet : .alert) {
                wSelf.deleteConnectServer(serverModel: subServer)
                finish(true)
            }
        }
        
        deleteAction.image = Reasource.systemNamed("trash", color: .white)
        deleteAction.backgroundColor = UIColor.systemPink
        
        // 重新编辑
        let editAction = UIContextualAction(style: .normal, title: nil) { [weak self] action, view, finish in
            self?.configNavidromeClick(subServer.navUser)
            finish(true)
        }
        
        editAction.image = Reasource.systemNamed("square.and.pencil", color: .white)
        editAction.backgroundColor = UIColor.systemBlue
                
        let actions = subServer.serverType == .fromNavidrome ? [deleteAction, editAction] : [deleteAction]
        return UISwipeActionsConfiguration(actions: actions)
    }
    
    // 编辑配置Nav配置
    func configNavidromeClick(_ navUser: NavidromeUserModel?) {
        guard let navUser = navUser else { return }
        
        let webVC = AuthNavidromeController(navUser)
        webVC.onLoginBlock = { [weak self] (navUser) in
            self?.refreshDataAction()
        }
        
        let navVC = KakaNavigationController(rootViewController: webVC)
        navVC.modalPresentationStyle = kaka_IsMacOS() ? .automatic : .fullScreen
        self.present(navVC, animated: true)
    }
    
    // 删除服务器
    func deleteConnectServer(serverModel: ServerConfigModel) {
        ConnectConfigManager.shared.deleteOneServer(serverModel)
        if let _ = serverModel.googleUser {
            GIDSignIn.sharedInstance.signOut()
        }
        if let _ = serverModel.dropboxUser {
            DropboxClientsManager.unlinkClients()
        }
        if let _ = serverModel.aliyunUser {
            let config = AliyunpanClientConfig(appId: Aliyun_AppID, scope: Aliyun_Scopes)
            let aliyunClient = AliyunpanClient(config)
            aliyunClient.cleanToken()
        }
        
        self.perform(#selector(refreshDataAction), with: nil, afterDelay: 1)
    }
    
}

extension ConnectListViewController: MFMailComposeViewControllerDelegate, SFSafariViewControllerDelegate {
    @objc func handleWithEmail() {
        self.view.endEditing(true)
        
        let subject = "\(kaka_osType().iconStr()) \("Wakemusic".localStr()) Feedback"
        let messageBody = "\r\r\r\r\r-----------------------------" + "\r" + self.getDeviceInformation()
        
        let canOpenMailScheme = UIApplication.shared.canOpenURL(URL(string: "mailto:")!)
        let mailtoURL = URL(string: "mailto:\(companyEmail)?subject=\(subject)&body=\(messageBody)")!
        
        if !MFMailComposeViewController.canSendMail() {
            
            if canOpenMailScheme {
                // 2️⃣ 打开第三方邮件客户端
                UIApplication.shared.open(mailtoURL)
            }else{
                // 3️⃣ 用户没有任何邮件客户端
                if kaka_IsMacOS() {
                    UIApplication.shared.open(FeedbackURL)
                }else{
                    let feedbackVC = SFSafariViewController(url: FeedbackURL)
                    self.present(feedbackVC, animated: true)
                }
            }
            return
        }
        
        // 1️⃣ 优先使用Apple的邮件客户端
        if canOpenMailScheme && kaka_IsMacOS() {
            UIApplication.shared.open(mailtoURL)
        }else{
            let emailVC = MFMailComposeViewController()
            emailVC.mailComposeDelegate = self
            emailVC.setToRecipients([companyEmail])
            emailVC.setSubject(subject)
            emailVC.setMessageBody(messageBody, isHTML: false)
            self.present(emailVC, animated: true, completion: nil)
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
        if result == .sent {
            self.view.makeToast("Thank you for your feedback".localStr())
        }
        
    }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true)
    }
    
    func getDeviceInformation() -> String {
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let model = kaka_IsMacOS() ? "macOS" : device.model
        let appVersion = ((Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String) ?? "") + "_" + "\(UserInfoManager.shared.isVIP() ? "1" : "0")"

        return """
        ServerType: "ConnectList"
        App Name: \("Wakemusic".localStr())
        App Version: \(appVersion)
        Device Model: \(model)
        System Version: \(systemVersion)
        Language: \(PhoneSetManager.languge_region())
        """
    }
}
