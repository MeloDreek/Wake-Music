//
//  AuthNavidromeController.swift
//  Mobie
//
//  Created by 张文 on 2/19/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import FilesProvider
import SafariServices
import ProgressHUD


/// 登录Navidrome
class AuthNavidromeController: SuperViewController {
    init(_ model: NavidromeUserModel) {
        super.init(nibName: nil, bundle: nil)
        
#if DEBUG
        let navModel = NavidromeUserModel(id: "", customName: "音海的Navidrome", hostUrl: "https://yinhai.aiinyue.com/", isAdmin: false, subsonicSalt: "", subsonicToken: "", lastFMApiKey: "", token: "", isLargeServer: true, username: "wake", password: "wake")
        self.loginModel = navModel
#else
        self.loginModel = model
#endif
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        self.title = ImportFileType.fromNavidrome.titleStr()
        self.navigationItem.largeTitleDisplayMode = .never
        
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        }
        
        let connectItem = UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"), style: .plain, target: self, action: #selector(questionBtnClick))
        self.navigationItem.rightBarButtonItem = connectItem
        
    }
    
    @objc func questionBtnClick() {
        let searchStr = String(format: SearchEngineType.defaultEngine().searchUrl(), "Navidrome")
        guard let vURL = URL(string: searchStr) else { return }
        
        if kaka_IsMacOS() {
            UIApplication.shared.open(vURL)
        }else{
            let webVC = SFSafariViewController(url: vURL)
            webVC.preferredControlTintColor = appMainColor
            self.present(webVC, animated: true)
        }
    }
    
//    var isShowPurchage: Bool = false
    
    var onLoginBlock: ((NavidromeUserModel)->Void)?
    
    
    lazy var dataArray: [LoginGroupModel] = {
        let model1 = LoginGroupModel(group: .serverGroup, headTitle: "Server".localStr(), itemArray: [.title, .host, .serverType], footTitle: nil)
        let model2 = LoginGroupModel(group: .loginGroup, headTitle: "Account".localStr(), itemArray: [.username, .password], footTitle: nil)
        let model3 = LoginGroupModel(group: .buttonGroup, headTitle: nil, itemArray: [.cusButton], footTitle: nil)
        return [model1, model2, model3]
    }()
    
    lazy var loginModel: NavidromeUserModel = {
        let model = NavidromeUserModel()
        return model
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: contentView.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
        view.allowsMultipleSelection = true
        view.allowsMultipleSelectionDuringEditing = true
        view.tableHeaderView = self.headView
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + 20.ckValue(), right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(UITableViewCell.self, forCellReuseIdentifier: "OtherTableViewCell")
        let itemArray: [LoginGroupItemType] = [.title, .host, .serverType, .username, .password, .cusButton]
        for index in 0..<itemArray.count {
            let subItem = itemArray[index]
            view.register(LoginTableViewCell.self, forCellReuseIdentifier: "LoginTableViewCell\(subItem.rawValue)")
        }
        return view
    }()
    
    lazy var headView: UITableViewHeaderFooterView = {
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 150
        }
        
        let iconImage = ImportFileType.fromNavidrome.iconImage()
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


extension AuthNavidromeController: UITableViewDataSource, UITableViewDelegate, LoginTableViewCellDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let groupModel = dataArray[section]
        
        return groupModel.itemArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let groupModel = dataArray[indexPath.section]
        let itemType = groupModel.itemArray[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "LoginTableViewCell\(itemType.rawValue)", for: indexPath) as! LoginTableViewCell
        cell.delegate = self
        cell.update(itemType: itemType, model: ServerConfigModel(serverType: .fromNavidrome, navUser: self.loginModel))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let groupModel = dataArray[indexPath.section]
        let itemType = groupModel.itemArray[indexPath.row]
        self.view.endEditing(true)
        
        if itemType != .cusButton { return }
        
        self.doneButtonClick()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55.ckValue()
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        return groupModel.headTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        return groupModel.group == .serverGroup ? "If your server has more than 10,000 songs, turning this off will show only Artists and Songs. Turning it on may require more requests and memory, and can cause severe performance issues that cannot be resolved.".localStr() : nil
    }
    
    func loginViewCellDidEndEditing(cell: LoginTableViewCell, itemType: LoginGroupItemType, content: String) {
        
        switch itemType {
        case .title:
            self.loginModel.customName = content
            break
        case .host:
            let hostStr = content.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            debugPrint("hostStr1 = \(hostStr)")
            self.loginModel.hostUrl = hostStr
            break
        case .username:
            self.loginModel.username = content
            break
        case .password:
            self.loginModel.password = content
            break
        default: break
        }
    }
    
    func loginViewCellDidEndEditing(cell: LoginTableViewCell, itemType: LoginGroupItemType, isEnable: Bool) {
        self.loginModel.isLargeServer = isEnable
    }
    
    func loginViewCellDidNetProtocol(cell: LoginTableViewCell, netProtocol: NetworkProtocol) {
        
    }
    
    // 登录
    func doneButtonClick() {
        
        if self.loginModel.customName.removeSpace().count < 1 {
            self.tableView.cellForRow(at: IndexPath(row: 0, section: 0))?.kaka_playShakeAnim()
            return
        }
        
        if self.loginModel.hostUrl.count < 3 {
            self.tableView.cellForRow(at: IndexPath(row: 1, section: 0))?.kaka_playShakeAnim()
            return
        }
        
        if self.loginModel.username.removeSpace().isEmpty {
            self.tableView.cellForRow(at: IndexPath(row: 0, section: 1))?.kaka_playShakeAnim()
            return
        }
        
        if self.loginModel.password.removeSpace().isEmpty {
            self.tableView.cellForRow(at: IndexPath(row: 1, section: 1))?.kaka_playShakeAnim()
            return
        }
        
        ProgressHUD.animate("Processing...".localStr())
        
        let hostStr = self.loginModel.hostUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        debugPrint("hostStr2 = \(hostStr)")
        self.loginModel.hostUrl = hostStr
        self.tableView.reloadData()
        
        let isLargeServer = self.loginModel.isLargeServer
        APIManager.shared.loginNavidrome(serverUrl: self.loginModel.hostUrl, isLargeServer: isLargeServer, username: self.loginModel.username, password: self.loginModel.password) { [weak self] result in
            ProgressHUD.dismiss()
            switch result {
            case .success(let model):
                                
                var navModel = model
                navModel.customName = self?.loginModel.customName ?? "My Navidrome".localStr()
                
                let newServerModel = ServerConfigModel(serverType: .fromNavidrome, navUser: navModel)
                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: newServerModel)
                
                NotificationCenter.default.post(name: Notification.Name(kLoginThirdServerKey), object: nil)
                
                self?.onLoginBlock?(navModel)
                self?.cancelButtonClick()
                break
            case .failure(let error):
                self?.showOneAlert(title: "Reminder".localStr(), message: error.errorDescription)
//                var navModel = self!.loginModel
//                navModel.customName = self?.loginModel.customName ?? "My Navidrome".localStr()
//                
//                let newServerModel = ServerConfigModel(serverType: .fromNavidrome, navUser: navModel)
//                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: newServerModel)
//                
//                NotificationCenter.default.post(name: Notification.Name(kLoginThirdServerKey), object: nil)
//                
//                self?.onLoginBlock?(navModel)
//                self?.cancelButtonClick()
                break
            }
        }

    }
    
    
    

    
}

