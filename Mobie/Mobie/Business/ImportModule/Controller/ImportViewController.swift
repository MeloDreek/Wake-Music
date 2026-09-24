//
//  ImportViewController.swift
//  Mobie
//
//  Created by 张文 on 12/16/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import SafariServices
import MessageUI

/*
 1、本地（文件、文件夹、视频转音乐、USB、Wi-Fi）
 2、远程 - NAS & 服务器
 3、远程 - 网盘
 */
class ImportViewController: SuperViewController {
    var isAwaitingDropboxAuthorization = false
    private var isFinishingRemoteAuthorization = false
    private weak var importHostRootController: UIViewController?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // A full-screen authorization page can remove both Import and its
        // presenter's views from the window. Remember the original scene first.
        if let root = view.window?.rootViewController { importHostRootController = root }
    }

    override func preSetupSubViews() {
        super.preSetupSubViews()
        self.title = "Import Music".localStr()
        
        contentView.addSubview(tableView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.navigationItem.leftBarButtonItem = self.cancelItem
        self.navigationItem.rightBarButtonItem = UserInfoManager.shared.isVIP() ? nil : self.premiumItem
        
        NotificationCenter.default.addObserver(self, selector: #selector(selectConnectPageNoti(_:)), name: Notification.Name(kJumpConnectPageKey), object: nil)
    }
    
    // 连接了某个服务器
    @objc func selectConnectPageNoti(_ noti: Notification) {
        guard isAwaitingDropboxAuthorization,
              let serverModel = noti.object as? ServerConfigModel,
              serverModel.dropboxUser != nil else { return }
        isAwaitingDropboxAuthorization = false
        finishRemoteAuthorization(serverModel)
    }
    
    @objc func dismissItemAction() {
        isAwaitingDropboxAuthorization = false
        (self.navigationController ?? self).dismiss(animated: true)
    }

    /// Pass the saved account directly to Connections. A notification alone is lost
    /// when Connections has never loaded (or has not been created on Mac Catalyst).
    func finishRemoteAuthorization(_ server: ServerConfigModel) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.finishRemoteAuthorization(server) }
            return
        }
        guard !isFinishingRemoteAuthorization else { return }
        let importNavigation = navigationController ?? self
        guard let presenter = importNavigation.presentingViewController,
              let root = viewIfLoaded?.window?.rootViewController
                ?? presenter.viewIfLoaded?.window?.rootViewController
                ?? importHostRootController else { return }

        // Resolve this window's destination before dismissing; never use a global
        // key window, which could belong to another scene.
        let showConnection: () -> Void
        if let tabs = root.importDestination(of: HomeTabbarViewController.self),
           let navigation = tabs.children.compactMap({ $0 as? UINavigationController })
            .first(where: { $0.viewControllers.first is ConnectListViewController }),
           let connections = navigation.viewControllers.first as? ConnectListViewController {
            showConnection = {
                tabs.selectedViewController = navigation
                connections.openImportedServer(server)
            }
        } else if let split = root.importDestination(of: MacTabbarViewController.self) {
            showConnection = {
                split.primaryVC.loadViewIfNeeded()
                split.primaryVC.jumpConnectPage()
                let navigation = split.contentDict[PrimaryCellItemType.connect.rawValue]
                let connections = navigation?.viewControllers.first as? ConnectListViewController
                connections?.openImportedServer(server)
            }
        } else {
            return
        }

        isFinishingRemoteAuthorization = true
        isAwaitingDropboxAuthorization = false
        view.endEditing(true)
        let closeImport = { presenter.dismiss(animated: true, completion: showConnection) }
        // Finish a nested Baidu/115 sheet first. Dismissing two full-screen
        // presentations simultaneously causes overlapping appearance transitions.
        if let authorization = importNavigation.presentedViewController {
            authorization.dismiss(animated: false, completion: closeImport)
        } else {
            closeImport()
        }
    }
    
    
    
    // MARK:  GET && SET
    lazy var dataArray: [ImportGroupModel] = {
        
        var tempArray = [ImportGroupModel]()
        var loclArray: [ImportFileType] = [.fromFile, .fromFolder, .fromVideos]
#if !targetEnvironment(macCatalyst)
        loclArray.append(contentsOf: [.fromUSB, .fromWiFi])
#endif
        let localFooter = String(format: "Locally imported songs appear in %@ and %@.".localStr(), KakaTabbarType.musics.formatStr(), KakaTabbarType.collection.formatStr())
        let model1 = ImportGroupModel(group: .localGroup, headTitle: ImportGroupType.localGroup.localizedTitle, itemArray: loclArray, footTitle: localFooter)
        tempArray.append(model1)

        tempArray.append(ImportGroupModel(group: .remoteServerGroup, headTitle: ImportGroupType.remoteServerGroup.localizedTitle, itemArray: ImportFileType.serverDriveArray(), footTitle: nil))
        tempArray.append(ImportGroupModel(group: .remoteCloudGroup, headTitle: ImportGroupType.remoteCloudGroup.localizedTitle, itemArray: ImportFileType.cloudDriveArray(), footTitle: nil))
                
        return tempArray
    }()
    
    // MARK:  懒加载
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + 30.ckValue(), right: 0)
        view.register(ImportTableViewCell.self, forCellReuseIdentifier: "ImportTableViewCell")
        return view
    }()
    
    lazy var cancelItem: UIBarButtonItem = {
        let item = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissItemAction))
        return item
    }()
    
    lazy var premiumItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "crown"), style: .plain, target: self, action: #selector(vipCenterClick))
        return item
    }()
    
    lazy var viewModel: MusicViewModel = {
        let baseFileURL = SandboxFileManager.shared.basePublicFileURL()
        let vm = MusicViewModel(baseFileURL)
        return vm
    }()
    
}

extension UIViewController {
    /// The Import callback owns navigation while its modal flow is visible;
    /// legacy Dropbox notifications must not switch the underlying tab early.
    var isPresentingImportFlow: Bool {
        var modal = presentedViewController
        while let current = modal {
            if current.importDestination(of: ImportViewController.self) != nil { return true }
            modal = current.presentedViewController
        }
        return false
    }

    /// Only new connections originating in Import use this route. Account edits
    /// and reauthorization originating in an existing file list keep their flow.
    @discardableResult
    func routeImportedServer(_ server: ServerConfigModel) -> Bool {
        var controller: UIViewController? = self
        while let current = controller {
            if let importer = current as? ImportViewController {
                importer.finishRemoteAuthorization(server)
                return true
            }
            let navigation = (current as? UINavigationController) ?? current.navigationController
            if let importer = navigation?.viewControllers
                .first(where: { $0 is ImportViewController }) as? ImportViewController {
                importer.finishRemoteAuthorization(server)
                return true
            }
            controller = current.parent ?? current.presentingViewController
        }
        return false
    }

    fileprivate func importDestination<T: UIViewController>(of type: T.Type) -> T? {
        if let destination = self as? T { return destination }
        for child in children {
            if let destination = child.importDestination(of: type) { return destination }
        }
        return nil
    }
}

extension ConnectListViewController {
    fileprivate func openImportedServer(_ server: ServerConfigModel) {
        loadViewIfNeeded()
        refreshDataAction()
        // A previous visit may have left a different cloud's folder on this stack.
        navigationController?.popToRootViewController(animated: false)
        accessLoginedServer(server)
    }
}

extension ImportViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray[section].itemArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ImportTableViewCell", for: indexPath) as! ImportTableViewCell
        let itemType = dataArray[indexPath.section].itemArray[indexPath.row]
        cell.updateItemType(itemType: itemType)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let groupModel = dataArray[indexPath.section]
        let itemType = groupModel.itemArray[indexPath.row]
        
        self.connectNewServer(itemType)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        return groupModel.headTitle
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if dataArray.count - 1 == section {
            return UITableView.automaticDimension
        }else{
            return UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if dataArray.count - 1 == section {
            return connectionFeedbackFooter(feedbackAction: #selector(handleWithEmail))
        }else{
            guard let text = dataArray[section].footTitle, !text.isEmpty else { return nil }
            let footer = UITableViewHeaderFooterView()
            footer.isUserInteractionEnabled = false
            let label = UILabel()
            label.text = text
            label.font = .preferredFont(forTextStyle: .footnote)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            footer.contentView.addSubview(label)
            label.snp.makeConstraints { make in
                make.leading.trailing.equalTo(footer.contentView.layoutMarginsGuide)
                make.top.bottom.equalToSuperview().inset(10.ckValue())
            }
            return footer
        }
        
    }
    
}

extension ImportViewController: MFMailComposeViewControllerDelegate, SFSafariViewControllerDelegate {
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
        ServerType: "Import"
        App Name: \("Wakemusic".localStr())
        App Version: \(appVersion)
        Device Model: \(model)
        System Version: \(systemVersion)
        Language: \(PhoneSetManager.languge_region())
        """
    }
}
