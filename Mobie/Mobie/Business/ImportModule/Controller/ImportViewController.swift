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

/*
 1、本地（文件、文件夹、视频转音乐）
 2、计算机（USB、Wi-Fi）
 3、连接（Webdav、Navidrome、网盘）
 */
class ImportViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        self.title = "Import Musics".localStr()
        
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
        let model1 = ImportGroupModel(group: .localGroup, headTitle: "Local".localStr(), itemArray: [.fromFile, .fromFolder, .fromVideos, .fromApple], footTitle: nil)
        tempArray.append(model1)
        
#if !targetEnvironment(macCatalyst)
        let model2 = ImportGroupModel(group: .computerGroup, headTitle: "Computer".localStr(), itemArray: [.fromUSB, .fromWiFi], footTitle: nil)
        tempArray.append(model2)
#endif
                
        let model3 = ImportGroupModel(group: .serverGroup, headTitle: "Server".localStr(), itemArray: ImportFileType.serverDriveArray(), footTitle: nil)
        tempArray.append(model3)
        
        let footArray: [ImportFileType] = [.fromYandexDrive, .fromBoxDrive, .fromePCloud]
        var footStr = "Coming Soon".localStr() + "\r\n" + footArray.map { $0.titleStr() }.joined(separator: " & ") + "..."
        if UserInfoManager.shared.isVIP() {
            footStr = ""
        }
        let model4 = ImportGroupModel(group: .driveGroup, headTitle: "Cloud Drive".localStr(), itemArray: ImportFileType.cloudDriveArray(), footTitle: footStr)
        tempArray.append(model4)
                
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
        let item = UIBarButtonItem(image: UIImage(systemName: "crown"), style: .done, target: self, action: #selector(vipCenterClick))
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
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        return groupModel.footTitle
    }
    
    
    
}

