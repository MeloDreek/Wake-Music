//
//  AuthWebdavViewController.swift
//  Mobie
//
//  Created by 张文 on 12/28/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import ProgressHUD
import FilesProvider
import SafariServices

/// 登录Webdav
class AuthWebdavViewController: SuperViewController {
    
    init(_ model: WebdavUserModel) {
        super.init(nibName: nil, bundle: nil)
        
#if DEBUG
        let webdavUser = WebdavUserModel(customName: "123的WebDav", hostUrl: "webdav.123pan.cn", path: "webdav", port: nil, netProtocol: .https, username: "19927730016", password: "1wpyy8t1000dc04313u4kok3c402c3s2")
        self.loginModel = webdavUser
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
        self.title = ImportFileType.fromWebDav.titleStr()
        self.navigationItem.largeTitleDisplayMode = .never
        
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        }
        
        let connectItem = UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"), style: .plain, target: self, action: #selector(questionBtnClick))
        self.navigationItem.rightBarButtonItem = connectItem
    }
    
    @objc func questionBtnClick() {
        let searchStr = String(format: SearchEngineType.defaultEngine().searchUrl(), "WebDav")
        guard let vURL = URL(string: searchStr) else { return }
        
        if kaka_IsMacOS() {
            UIApplication.shared.open(vURL)
        }else{
            let webVC = SFSafariViewController(url: vURL)
            webVC.preferredControlTintColor = appMainColor
            self.present(webVC, animated: true)
        }
    }
    
    @objc func doneButtonClick() {
        self.view.endEditing(true)
        
        if self.loginModel.customName.removeSpace().count == 0 {
            self.tableView.cellForRow(at: IndexPath(row: 0, section: 0))?.kaka_playShakeAnim()
            return
        }
        
        if self.loginModel.hostUrl.count < 3 {
            self.tableView.cellForRow(at: IndexPath(row: 1, section: 1))?.kaka_playShakeAnim()
            return
        }
        
        self.handleWithWebDav()
    }
        
    func handleWithWebDav() {
        guard let webdavProvider = self.loginModel.webdavProvider() else {
            
            self.tryCount += 1
            if self.tryCount >= 3 {
                self.view.makeToast("Failed to construct WevDav service".localStr())
            }else{
                self.doneButtonClick()
            }
            
            return
        }
        
        self.tryCount = 0
        
        self.webdavProvider = webdavProvider
        ProgressHUD.animate("Please wait".localStr())
        
        self.webdavProvider?.contentsOfDirectory(path: self.loginModel.path ?? "/") { [weak self] files, error in
            DispatchQueue.main.async {
                guard let wSelf = self else { return }
                
                guard let error = error else {
                    
                    guard let files = files as? [WebDavFileObject] else {
                        ProgressHUD.failed("No data available".localStr())
                        return
                    }
                    
                    wSelf.loginSucces(files)
                    return
                }
                                
                ProgressHUD.dismiss()
                var errorMessage = "Error message".localStr()
                if let webError = error as? FileProviderWebDavError {
                    let errorCode = webError.code
                    errorMessage = errorMessage + "\(errorCode.rawValue)"
                    errorMessage = errorMessage + "\r\n" + webError.localizedDescription
                    
                    if PhoneSetManager.isVPNConnected() {
                        errorMessage = "Please Try switching networks or turning off the VPN (if it's turned on)".localStr()
                        self?.showOneAlert(title: error.localizedDescription, message: errorMessage, confirm: "OK".localStr(), complete: nil)
                    }else{
                        self?.showOneAlert(title: "Reminder".localStr(), message: errorMessage, confirm: "OK".localStr(), complete: nil)
                    }
                    
                }else{
                    if PhoneSetManager.isVPNConnected() {
                        errorMessage = "Please Try switching networks or turning off the VPN (if it's turned on)".localStr()
                        self?.showOneAlert(title: error.localizedDescription, message: errorMessage, confirm: "OK".localStr(), complete: nil)
                    }else{
                        self?.showOneAlert(title: "Reminder".localStr(), message: error.localizedDescription, confirm: "OK".localStr(), complete: nil)
                    }
                }
                
            }
        }
    }
    
    func loginSucces(_ files: [WebDavFileObject]?) {
        
        ProgressHUD.dismiss()
        
        let serverModel = ServerConfigModel(serverType: .fromWebDav, webdavUser: self.loginModel)
        ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: serverModel)
        
        NotificationCenter.default.post(name: Notification.Name(kLoginThirdServerKey), object: nil)

        let musicArray = (files ?? []).map { webdavFile in
            let fileModel = webdavFile.convertFileModel(server: self.loginModel)
            return MusicItemModel(webFileModel: fileModel)
        }
        
        self.onLoginBlock?(serverModel)
        
        self.cancelButtonClick()
//        let listVC = WebdavFileListController(loginModel: self.loginModel, files: musicArray)
//        self.navigationController?.pushViewController(listVC, animated: true)
    }
    
    // MARK:  GET && SET
    
//    var isShowPurchage: Bool = false
    
    var tryCount: Int = 0
    
    var onLoginBlock: ((ServerConfigModel)->Void)?
        
    lazy var dataArray: [LoginGroupModel] = {
        let model1 = LoginGroupModel(group: .titleGroup, headTitle: nil, itemArray: [.title], footTitle: nil)
        let model2 = LoginGroupModel(group: .serverGroup, headTitle: "Server".localStr(), itemArray: [.httpOption, .host, .port, .path], footTitle: nil)
        let model3 = LoginGroupModel(group: .loginGroup, headTitle: "Account".localStr(), itemArray: [.username, .password], footTitle: nil)
        let model4 = LoginGroupModel(group: .buttonGroup, headTitle: nil, itemArray: [.cusButton], footTitle: nil)
        return [model1, model2, model3, model4]
    }()
    
    lazy var loginModel: WebdavUserModel = {
        let model = WebdavUserModel()
        return model
    }()
    
    var btnTincolor: UIColor {
        get {
            if ColorFontManager.shared.accentTyle == .color0 {
                return ColorFontManager.shared.defaultType.color()
            }else{
                return ColorFontManager.shared.accentTyle.color()
            }
        }
    }
    
    var webdavProvider: WebDAVFileProvider?
        
        
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: contentView.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
        view.allowsMultipleSelection = true
        view.allowsMultipleSelectionDuringEditing = true
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + 20.ckValue(), right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(UITableViewCell.self, forCellReuseIdentifier: "OtherTableViewCell")
        let itemArray: [LoginGroupItemType] = [.title, .host, .httpOption, .port, .path, .username, .password, .cusButton]
        for index in 0..<itemArray.count {
            let subItem = itemArray[index]
            view.register(LoginTableViewCell.self, forCellReuseIdentifier: "LoginTableViewCell\(subItem.rawValue)")
        }
        return view
    }()
    
}

extension AuthWebdavViewController: UITableViewDataSource, UITableViewDelegate {
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
        cell.update(itemType: itemType, model: ServerConfigModel(serverType: .fromWebDav, webdavUser: self.loginModel))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.view.endEditing(true)
        
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
    
}

extension AuthWebdavViewController: LoginTableViewCellDelegate {
    
    func loginViewCellDidNetProtocol(cell: LoginTableViewCell, netProtocol: NetworkProtocol) {
        self.loginModel.netProtocol = netProtocol
    }
    
    func loginViewCellDidEndEditing(cell: LoginTableViewCell, itemType: LoginGroupItemType, content: String) {
        
        self.tryCount = 0
        
        switch itemType {
        case .title:
            self.loginModel.customName = content
        case .host:
            self.loginModel.hostUrl = content
        case .path:
            self.loginModel.path = content
        case .port:
            self.loginModel.port = content
        case .username:
            self.loginModel.username = content
        case .password:
            self.loginModel.password = content
        case .httpOption, .otherDav, .cusButton, .serverType:
            break
        }
    }
    
    func loginViewCellDidEndEditing(cell: LoginTableViewCell, itemType: LoginGroupItemType, isEnable: Bool) {
        
    }
    
    
    

    
}
