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
 1、本地（文件、文件夹、视频转音乐）
 2、计算机（USB、Wi-Fi）
 3、连接（Webdav、Navidrome、网盘）
 */
class ImportViewController: SuperViewController {
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
        guard let serverModel = noti.object as? ServerConfigModel else { return }
        
        if let dropboxUser = serverModel.dropboxUser {
            let googleVC = DropboxDriveFileListController(loginModel: dropboxUser)
            self.navigationController?.pushViewController(googleVC, animated: true)
        }
        
    }
    
    @objc func dismissItemAction() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    
    
    // MARK:  GET && SET
    lazy var dataArray: [ImportGroupModel] = {
        
        var tempArray = [ImportGroupModel]()
        var loclArray: [ImportFileType] = [.fromFile, .fromFolder, .fromVideos]
#if !targetEnvironment(macCatalyst)
        loclArray.append(contentsOf: [.fromUSB, .fromWiFi])
#endif
        let model1 = ImportGroupModel(group: .localGroup, headTitle: "Local".localStr(), itemArray: loclArray, footTitle: nil)
        tempArray.append(model1)
                
        let model3 = ImportGroupModel(group: .serverGroup, headTitle: "Remote".localStr(), itemArray: ImportFileType.serverDriveArray() + ImportFileType.cloudDriveArray(), footTitle: nil)
        tempArray.append(model3)
                
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
            return 120.ckValue()
        }else{
            return UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if dataArray.count - 1 == section {
            let attbuteStr = NSAttributedString(string: "Don't see your connection method? Tell us!".localStr(), attributes: [.font: UIFontLight(13.ckValue()), .foregroundColor: UIColor.systemBlue, .underlineStyle: 1])
            
            let footView = UITableViewHeaderFooterView()
            let footButton = UIButton()
            footButton.addTarget(self, action: #selector(handleWithEmail), for: .touchUpInside)
            footButton.setAttributedTitle(attbuteStr, for: .normal)
            footView.contentView.addSubview(footButton)
            footButton.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(10.ckValue())
                make.top.equalTo(15.ckValue())
                make.centerX.equalToSuperview()
                make.height.greaterThanOrEqualTo(0)
            }
            return footView
        }else{
            return nil
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
        ServerType: "ImportViewController"
        App Name: \("Wakemusic".localStr())
        App Version: \(appVersion)
        Device Model: \(model)
        System Version: \(systemVersion)
        Language: \(PhoneSetManager.languge_region())
        """
    }
}
