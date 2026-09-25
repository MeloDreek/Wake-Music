//
//  AuthBaiduViewController.swift
//  Mobie
//
//  Created by 张文 on 7/3/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import WebKit
import Alamofire
import SmartCodable
import NVActivityIndicatorView

struct BaiduResponseModel: SmartCodableX {
    var request_id: String = ""
    var guid: Int = 0
    var errno: Int = 0
    var guid_info: String = ""
    
    /// 文件列表
    var list: [BaiduDriveFileModel]?
    
    /// token过期，重新授权
    func isTokenInvalid() -> Bool {
        return errno == -6 || errno == 31045
    }
}


/// 百度网盘授权页
class AuthBaiduViewController: SuperViewController, WKNavigationDelegate {

    init(onSuccess: @escaping (ServerConfigModel) -> Void,
         onFailure: @escaping (KakaError) -> Void) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(webView)
        
        contentView.addSubview(loadingView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let navbarHeight = self.navigationController?.navigationBar.height ?? 44
        webView.frame = CGRectMake(0, navbarHeight, contentView.width, contentView.height)
        loadingView.frame = CGRectMake((contentView.width - loadingView.width) / 2, (contentView.height - loadingView.height) / 2, loadingView.width, loadingView.height)
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = ImportFileType.fromBaiduDrive.titleStr()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        self.loadAuthPage()
    
        // 监听网络变化
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilitySwiftChanged, object: reachability)
        
        try? self.reachability.startNotifier()
        
    }
    
    // 网络状态变化了
    @objc func reachabilityChanged(note: Notification) {
        guard let reachability = note.object as? ReachabilitySwift else { return }
        
        debugPrint("当前网络授权状况 = \(reachability.connection.description)")
        
        self.netConnect = reachability.connection
        
        if self.netConnect == .unavailable {
            self.showTwoAlert(message: "Network access is disabled. Enable it for the best experience.".localStr(), confirm: "Settings".localStr(), cancle: "Cancel".localStr()) {
                guard let vURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(vURL)
            }
        }
    }
    
    private func loadAuthPage() {
                
        guard let url = URL(string: BaiduDriveAuthURL) else {
            return
        }
        
        self.loadingView.startAnimating()
        self.webView.load(URLRequest(url: url))
    }
    
    // MARK:  GET && SET
    private let onSuccess: (ServerConfigModel) -> Void
    private let onFailure: (KakaError) -> Void
    
    // MARK:  懒加载
    
    var netConnect: ReachabilitySwift.Connection = .unavailable
    
    lazy var reachability: ReachabilitySwift = {
        return try! ReachabilitySwift()
    }()
    
    lazy var webView: WKWebView = {
        let navbarHeight = self.navigationController?.navigationBar.height ?? 44

        let view = WKWebView()
        view.navigationDelegate = self
        view.scrollView.contentInsetAdjustmentBehavior = .automatic
        view.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: navbarHeight * 2, right: 0)
        return view
    }()
    
    
    lazy var loadingView: NVActivityIndicatorView = {
        let valueSize = 25.ckValue()
        let frame = CGRectMake(0, 0, valueSize, valueSize)
        let view = NVActivityIndicatorView(frame: frame, type: .lineScalePulseOutRapid, color: appMainColor)
        return view
    }()
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.loadingView.stopAnimating()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {


        guard let url = navigationAction.request.url,
              url.absoluteString.contains("login_success#"),
              let fragment = URLComponents(string: url.absoluteString)?.fragment else {
            decisionHandler(.allow)
            return
        }
        
        let urlArray = ["passport/agreement", "policy/children-privacy-policy"]
        if urlArray.contains(url.absoluteString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }

        self.loadingView.stopAnimating()
        let dict = self.parseFragment(fragment)

        guard var model = BaiduDriveUserModel.deserialize(from: dict) else {
            self.loadingView.stopAnimating()
            decisionHandler(.cancel)
            self.onFailure(KakaError.custom(dict.description))
            self.cancelButtonClick()
            return
        }
        
        self.fetchBaiduUserInfo(accessToken: model.access_token) { result in
            switch result {
            case .success(let info):
                decisionHandler(.cancel)
                
                model.uk = info.uk
                model.avatar_url = info.avatar_url
                model.baidu_name = info.baidu_name
                model.netdisk_name = info.netdisk_name
                model.vip_type = info.vip_type
                model.requestTime = Date().timeIntervalSince1970
                
                // 1️⃣添加服务器
                let serverModel = ServerConfigModel(serverType: .fromBaiduDrive, baiduUser: model)
                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: serverModel) {
                    if self.routeImportedServer(serverModel) {
                        NotificationCenter.default.post(name: Notification.Name(kLoginThirdServerKey), object: nil)
                        return
                    }
                    self.onSuccess(serverModel)
                    NotificationCenter.default.post(name: Notification.Name(kLoginThirdServerKey), object: nil)
                    self.cancelButtonClick()
                }
                                
            case .failure(let failure):
                decisionHandler(.cancel)
                self.onFailure(failure)
                self.cancelButtonClick()
            }
        }
        
    }

    public func fetchBaiduUserInfo(accessToken: String, completion: @escaping (Result<BaiduDriveUserModel, KakaError>) -> Void) {
        let url = "https://pan.baidu.com/rest/2.0/xpan/nas"
        
        let parameters: Parameters = [
            "method": "uinfo",
            "access_token": accessToken,
            "vip_version": "v2"
        ]
        
        AF.request(url, method: .get, parameters: parameters).responseString { response in
            switch response.result {
            case .success(let responseString):
                guard let model = BaiduDriveUserModel.deserialize(from: responseString) else {
                    completion(.failure(KakaError.custom(responseString)))
                    return
                }
                
                completion(.success(model))
            case .failure(let error):
                debugPrint("Request failed with error: \(error)")
                completion(.failure(KakaError.custom(error.errorDescription ?? error.localizedDescription)))
            }
        }
    }

    private func parseFragment(_ fragment: String) -> [String: Any] {
        var result: [String: String] = [:]
        let pairs = fragment.components(separatedBy: "&")
        for pair in pairs {
            let components = pair.components(separatedBy: "=")
            if components.count == 2 {
                result[components[0]] = components[1]
            }
        }
        return result
    }
    
}
