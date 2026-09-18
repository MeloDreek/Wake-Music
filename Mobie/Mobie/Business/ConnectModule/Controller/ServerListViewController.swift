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

// 已添加的服务器列表
class ConnectListViewController: SuperViewController {
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
        
        // 新增了服务器
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
    
    @objc func setupNavigationItem() {
        if #available(iOS 26.0, *) {
            self.downloadBarItem.badge = self.downloadBadge()
        }
        
        self.navigationItem.rightBarButtonItems = [self.downloadBarItem, self.importBarItem]
    }
    
    @objc func vipCenterClick() {
        AppStoreKitManager.presentPurcharseVC(self)
    }
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()

    var downloadVC: DownloadViewController?
    
    var onSelectBlock: ((ServerConfigModel?)->Void)?
    
    lazy var connectArray: [ServerConfigModel] = {
        return [ServerConfigModel]()
    }()
    
    lazy var avalibleArray: [ImportFileType] = {
        return ImportFileType.serverDriveArray() + ImportFileType.cloudDriveArray()
    }()
    
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
        view.register(ConnectedSourceTableCell.self, forCellReuseIdentifier: "ConnectedSourceTableCell")
        return view
    }()
    
    lazy var headView: UITableViewHeaderFooterView = {
        let iconImage = UIImage(systemName: "externaldrive.fill.badge.wifi")
        let view = UITableViewHeaderFooterView(frame: CGRectMake(0, 0, self.view.width, kaka_IsiPhone() ? 150.ckValue() : 300.ckValue()))
        view.backgroundColor = .clear
        let faceImgView = UIImageView(image: iconImage)
        faceImgView.contentMode = .scaleAspectFit
        view.contentView.addSubview(faceImgView)
        faceImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(kaka_IsiPhone() ? 0.72 : 0.82)
            make.width.equalTo(faceImgView.snp.height)
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
    lazy var importBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: self, action: #selector(importMusicClick))
        item.accessibilityLabel = "Import Musics".localStr()
        return item
    }()
    
    // 下载队列
    lazy var downloadBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "arrow.down.circle"), style: .plain, target: self, action: #selector(downloadQueueAction))
        item.accessibilityLabel = "Download".localStr()
        if #available(iOS 26.0, *) {
            item.badge = self.downloadBadge()
        }
        return item
    }()
    
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
        
        self.currentViewController()?.present(KakaNavigationController(rootViewController: downloadVC), animated: true)
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
        return connectArray.count == 0 ? self.avalibleArray.count : connectArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if connectArray.count == 0 {
            let subType = self.avalibleArray[indexPath.section]
            let cell = tableView.dequeueReusableCell(withIdentifier: "ImportTableViewCell", for: indexPath) as! ImportTableViewCell
            cell.updateItemType(itemType: subType)
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConnectedSourceTableCell", for: indexPath) as! ConnectedSourceTableCell
            let server = connectArray[indexPath.section]
            cell.serverModel = server
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if connectArray.count == 0 {
            // 首次连接
            let itemType = self.avalibleArray[indexPath.section]
            self.connectNewServer(itemType)
        }else{
            // 访问网盘
            var subModel = self.connectArray[indexPath.section]
            subModel.isSelected = true
        
            let tempArray = self.connectArray.map {
                var tempModel = $0
                tempModel.isSelected = $0 == subModel ? true : false
                return tempModel
            }
            
            ConnectConfigManager.shared.connectedModels = tempArray
            
            self.accessLoginedServer(subModel)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if connectArray.count == 0 {
            return UITableView.automaticDimension
        }else{
            return UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return connectArray.count == 0 ? false : true
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if connectArray.count == 0 {
            return nil
        }
        
        // 删除
        let deleteAction = UIContextualAction(style: .normal, title: nil) { [weak self] action, view, finish in
            guard let wSelf = self else { return }
            wSelf.showTwoAlert(title: "Reminder".localStr(), message: "Are you sure to delete it?".localStr(), confirm: "Delete".localStr(), cancle: "Cancel".localStr(), style: kaka_IsiPhone() ? .actionSheet : .alert) {
                let model = wSelf.connectArray[indexPath.section]
                self?.deleteConnectServer(serverModel: model)
            }
        }
        deleteAction.image = Reasource.systemNamed("trash", color: .white)
        deleteAction.backgroundColor = UIColor.systemPink
                
        let actions = [deleteAction]
        return UISwipeActionsConfiguration(actions: actions)
    }
    
    // 删除服务器
    func deleteConnectServer(serverModel: ServerConfigModel) {
        ConnectConfigManager.shared.deleteOneServer(serverModel)
        self.perform(#selector(refreshDataAction), with: nil, afterDelay: 1)
    }
    
}
