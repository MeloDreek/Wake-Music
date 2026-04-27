//
//  Auth115LifeViewController.swift
//  Mobie
//
//  Created by 张文 on 7/15/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import WebKit
import Alamofire
import SmartCodable
import CommonCrypto
import Kingfisher
import NVActivityIndicatorView
import Photos


struct Response115_LoginModel: SmartCodableX {
    
    /// 轮询接口：0.二维码无效，结束轮询；1.继续轮询；
    var state: Int?
    var code: Int?
    var message: String?
    var error: String?
    var errno: Int?
    
    /// 二维码信息
    var data: Response115_LoginData?
}

struct Response115_LoginData: SmartCodableX {
    
    /// 设备码
    var uid: String = ""
    
    /// 二维码内容，第三方客户端需要根据此内容生成设备二维码，提供给115客户端扫码
    var qrcode: String = ""
    
    /// 校验用的时间戳，轮询设备码状态用到
    var time: Int = 0
    
    /// 校验用的签名，轮询设备码状态用到
    var sign: String = ""
    
    /* 1️⃣以下数据是轮询接口才有的 */
    
    /// 操作提示
    var msg: String?
    /// 版本号
    var version: String?
    /// 二维码状态；1.扫码成功，等待确认；2.确认登录/授权，结束轮询;
    var status: Int?
    
    
    /* 2️⃣以下数据是获取token才有的 */
    
    /// 用于访问资源接口的凭证
    var access_token: String?
    
    /// 用于刷新 access_token，有效期1年
    var refresh_token: String?
    
    /// access_token 有效期，单位秒
    var expires_in: Int?

    
}


// 手机扫码授权PKCE模式
class Auth115LifeViewController: SuperViewController {
    
    init(onSuccess: @escaping (Drive115UserModel) -> Void) {
        self.onSuccess = onSuccess
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(qrcodeImgView)
        contentView.addSubview(loadingView)
        contentView.addSubview(refreshButton)
        contentView.addSubview(messageLabel)
        contentView.addSubview(saveButton)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        loadingView.frame = CGRectMake((contentView.width - loadingView.width) / 2, (contentView.height - loadingView.height) / 2, loadingView.width, loadingView.height)

        qrcodeImgView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(kaka_IsMacOS() ? -30.ckValue() : -contentView.height * 0.15)
            make.size.equalTo(qrcodeImgView.size)
        }
        
        refreshButton.snp.remakeConstraints { make in
            make.edges.equalTo(qrcodeImgView)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(qrcodeImgView.snp.bottom).offset(40.ckValue())
            make.leading.equalTo(20.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        saveButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(messageLabel.snp.bottom).offset(35.ckValue())
            make.width.equalTo(qrcodeImgView.snp.width).multipliedBy(1.2)
            make.height.equalTo(50.ckValue())
        }
        
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        self.title = ImportFileType.from115Drive.titleStr()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        self.refreshAuthQrCode()
        
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
            self.showTwoAlert(title: "Reminder".localStr(), message: "No network access permission, please enable it for the best experience.".localStr(), confirm: "Settings".localStr(), cancle: "Cancel".localStr()) {
                guard let vURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(vURL)
            }
        }
    }
    
    // 1️⃣刷新授权二维码
    @objc func refreshAuthQrCode() {
        let url = "https://passportapi.115.com/open/authDeviceCode"
        
        let headers: HTTPHeaders = ["Content-Type": "application/x-www-form-urlencoded"]
        
        let parameters: Parameters = [
            "client_id": client_id,
            "code_challenge": self.generatePKCE(),
            "code_challenge_method": "sha256"
        ]
        
        debugPrint("1️⃣open/authDeviceCode参数 = \(parameters)")
        
        self.isPolling = false
        self.messageLabel.text = self.message
        self.messageLabel.isHidden = true
        self.saveButton.isHidden = true
        self.qrcodeImgView.isHidden = true
        self.refreshButton.isHidden = true
        self.loadingView.startAnimating()
        
        AF.request(url, method: .post, parameters: parameters, headers: headers).validate().responseString { response in
            self.loadingView.stopAnimating()
            self.messageLabel.isHidden = false
            self.saveButton.isHidden = kaka_IsMacOS()
            self.qrcodeImgView.isHidden = false

            switch response.result {
            case .success(let responseString):
                
                debugPrint("1️⃣open/authDeviceCode/返回 = \(responseString)")

                guard let response = Response115_LoginModel.deserialize(from: responseString)  else {
                    self.showOneAlert(title: "Reminder".localStr(), message: responseString)
                    return
                }
                
                self.pkceModel = response.data
                let logoImage = ImportFileType.from115Drive.iconImage()
                self.qrcodeImgView.image = self.pkceModel?.qrcode.generateQRCode(logoImage)
                
                self.refreshQrCodeStatus()
                                
                break
            case .failure(let error):
                debugPrint("Request failed with error: \(error)")
                self.showOneAlert(title: "Reminder".localStr(), message: error.localizedDescription) {
                    self.cancelButtonClick()
                }
            }
        }
    }
    
    // 2️⃣轮询二维码状态
    @objc func refreshQrCodeStatus() {
                
        guard let pkceModel = self.pkceModel else { return }
        
        let url = "https://qrcodeapi.115.com/get/status/"
                
        let parameters: Parameters = [
            "uid": pkceModel.uid,
            "time": pkceModel.time,
            "sign": pkceModel.sign
        ]
        
        debugPrint("2️⃣get/status/参数 = \(parameters)")
        
        AF.request(url, method: .get, parameters: parameters).validate(statusCode: 200..<500).responseString { response in
            self.loadingView.stopAnimating()

            switch response.result {
            case .success(let responseString):
                debugPrint("2️⃣get/status/返回 = \(responseString)")
                guard let response = Response115_LoginModel.deserialize(from: responseString)  else {
                    self.showOneAlert(title: "Reminder".localStr(), message: responseString)
                    return
                }
                
                if response.state == 0 {
                    // 二维码无效，结束轮询，显示重新刷新二维码按按钮
                    self.messageLabel.text = response.message ?? self.message
                    self.refreshButton.isHidden = false
                    return
                }
                
                if response.state == 1 && !self.isPolling {
                    self.isPolling = true
                    self.refreshQrCodeStatus()
                }
                
                if response.data?.status == -2 {
                    // -2：已取消登录，请刷新重试
                    self.showOneAlert(title: "Reminder".localStr(), message: response.data?.msg ?? "", confirm: "OK".localStr()) {
                        self.refreshAuthQrCode()
                    }
                    return
                }
                
                if response.data?.status == 1 {
                    // 1.扫码成功，等待确认
                    self.messageLabel.text = response.data?.msg ?? self.message
                }
                
                if response.data?.status == 2 {
                    // 2.确认登录/授权，结束轮询
                    self.get115DriveToken()
                }
                
            case .failure(let error):
                self.perform(#selector(self.refreshQrCodeStatus), with: nil, afterDelay: 2)
                debugPrint("Request failed with error1: \(error)")
                break
            }
        }
    }
    
    /// 3️⃣用设备码换取 access_token
    func get115DriveToken() {
        let url = "https://passportapi.115.com/open/deviceCodeToToken/"
        
        let headers: HTTPHeaders = ["Content-Type": "application/x-www-form-urlencoded"]
        
        let parameters: Parameters = [
            "uid": self.pkceModel?.uid ?? "",
            "code_verifier": self.code_verifier ?? ""
        ]
        
        debugPrint("3️⃣open/deviceCodeToToken/参数 = \(parameters)")
        
        AF.request(url, method: .post, parameters: parameters, headers: headers).validate().responseString { response in

            switch response.result {
            case .success(let responseString):
                
                debugPrint("3️⃣open/deviceCodeToToken返回 = \(responseString)")

                guard let response = Response115_LoginModel.deserialize(from: responseString)  else {
                    self.showOneAlert(title: "Reminder".localStr(), message: responseString)
                    return
                }
                
                if response.code == 0 {
                    self.get115UserInfo(access_token: response.data?.access_token ?? "") { model in
                        var userModel = model
                        userModel.access_token = response.data?.access_token ?? ""
                        userModel.refresh_token = response.data?.refresh_token ?? ""
                        userModel.expires_in = response.data?.expires_in ?? 0
                        
                        let serverModel = ServerConfigModel(serverType: .from115Drive, drive115User: userModel)
                        ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: serverModel) {
                            self.onSuccess(userModel)
                            NotificationCenter.default.post(name: Notification.Name(kLoginThirdServerKey), object: nil)
                            self.cancelButtonClick()
                        }
                        
                    }
                }else{
                    self.showOneAlert(title: "Reminder".localStr(), message: response.message ?? "", confirm: "OK".localStr()) {
                        self.cancelButtonClick()
                    }
                }
                                                
                break
            case .failure(let error):
                debugPrint("Request failed with error2: \(error)")
                self.showOneAlert(title: "Reminder".localStr(), message: error.localizedDescription)
            }
        }
    }
    
    /// 4️⃣获取用户信息
    func get115UserInfo(access_token: String, completion: ((Drive115UserModel)->Void)? = nil) {
        
        let url = "https://proapi.115.com/open/user/info"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(access_token)"]
        
        AF.request(url, method: .get, headers: headers).validate().responseData { response in
            switch response.result {
            case .success(let data):
                
                debugPrint("4️⃣open/user/info返回 = \(String(data: data, encoding: .utf8) ?? "")")

                guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let state = dict["state"] as? Bool, state, let dataJson = dict["data"] as? [String: Any], let userModel = Drive115UserModel.deserialize(from: dataJson) else {
                    let errorMsg = String(data: data, encoding: .utf8) ?? ""
                    self.showOneAlert(title: "Reminder".localStr(), message: errorMsg) {
                        self.cancelButtonClick()
                    }
                    return
                }
                                
                completion?(userModel)
                
                break
            case .failure(let afError):
                debugPrint("afError = \(afError.localizedDescription)")
                self.showOneAlert(title: "Reminder".localStr(), message: afError.localizedDescription) {
                    self.cancelButtonClick()
                }
                break
            }
        }
    }
    
    /*
     4️⃣open/user/info返回 = {\"state\":true,\"message\":\"\",\"code\":0,\"data\":{\"user_id\":102561708,\"user_name\":\"102561708\",\"user_face_s\":\"https:\\/\\/avatars.115.com\\/01\\/gb6zzt_s.jpg\",\"user_face_m\":\"https:\\/\\/avatars.115.com\\/01\\/gb6zzt_m.jpg\",\"user_face_l\":\"https:\\/\\/avatars.115.com\\/01\\/gb6zzt_l.jpg\",\"rt_space_info\":{\"all_total\":{\"size\":16106127360,\"size_format\":\"15GB\"},\"all_remain\":{\"size\":13215197196,\"size_format\":\"12.31GB\"},\"all_use\":{\"size\":2890930164,\"size_format\":\"2.69GB\"}},\"vip_info\":{\"expire\":0,\"level_name\":\"\\u539f\\u77f3\\u4f1a\\u5458\",\"tp_rights\":{\"is_tp_rights\":0,\"tp_rights_time\":0}}}}
     */
    
    // MARK:  GET && SET
    let client_id = "100196055"
    
    /// 授权的二维码信息
    var pkceModel: Response115_LoginData?
    
    /// 上一步计算 code_challenge 的原值 code_verifier
    var code_verifier: String?
    
    /// 默认文案
    let message = "Please use the Cloud Storage app to scan this QR code to log in".localStr()
    
    /// 正在轮询
    var isPolling: Bool = false
    
    private let onSuccess: (Drive115UserModel) -> Void
    
    var netConnect: ReachabilitySwift.Connection = .unavailable
    
    lazy var reachability: ReachabilitySwift = {
        return try! ReachabilitySwift()
    }()
    
    var appMainColor: UIColor {
        get {
            if ColorFontManager.shared.accentTyle == .color0 {
                return ColorFontManager.shared.defaultType.color()
            }else{
                return ColorFontManager.shared.accentTyle.color()
            }
        }
    }
    
    // MARK:  懒加载
    lazy var loadingView: NVActivityIndicatorView = {
        let valueSize = 25.ckValue()
        let frame = CGRectMake(0, 0, valueSize, valueSize)
        let view = NVActivityIndicatorView(frame: frame, type: .lineScalePulseOutRapid, color: appMainColor)
        return view
    }()
    
    lazy var qrcodeImgView: UIImageView = {
        var qrcodeWidth = min(contentView.width, contentView.height) * 0.65
        switch kaka_osType() {
        case .iOS: qrcodeWidth = min(contentView.width, contentView.height) * 0.65
        case .macOS: qrcodeWidth = 300.ckValue()
        case .iPadOS: qrcodeWidth = 200.ckValue()
        }
        
        let view = UIImageView(frame: CGRectMake(0, 0, qrcodeWidth, qrcodeWidth))
        view.contentMode = .scaleAspectFill
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var refreshButton: UIButton = {
        let view = UIButton(type: .custom)
        view.isHidden = true
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.setImage(Reasource.systemNamed("arrow.clockwise", color: .white), for: .normal)
        view.addTarget(self, action: #selector(refreshAuthQrCode), for: .touchUpInside)
        return view
    }()
    
    lazy var messageLabel: UILabel = {
        let view = UILabel()
        view.text = self.message
        view.numberOfLines = 0
        view.font = UIFontLight(16.ckValue())
        view.textAlignment = .center
        view.textColor = .label
        return view
    }()
    
    lazy var saveButton: UIButton = {
        let isDark = AppLocalManager.shared.appearanceStyle == .dark || self.overrideUserInterfaceStyle == .dark
        let tintColor = (ColorFontManager.shared.accentTyle == .color0 && isDark) ? UIColor.deAccent : UIColor.white
        
        let view = UIButton(type: .custom)
        view.isHidden = kaka_IsMacOS()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        view.setTitle("Save the QR code".localStr(), for: .normal)
        view.setTitleColor(tintColor, for: .normal)
        view.backgroundColor = appMainColor
        view.titleLabel?.font = UIFontBold(16.ckValue())
        view.addTarget(self, action: #selector(saveButtonClick), for: .touchUpInside)
        return view
    }()
    
}

extension Auth115LifeViewController {
    
    @objc func saveButtonClick() {
        guard let image = self.qrcodeImgView.image else { return }
        
        self.saveImageToPhotos(image: image)
    }
    
    func saveImageToPhotos(image: UIImage) {
        // 请求权限（iOS 14+）
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized:
                // 获取当前照片库
                PHPhotoLibrary.shared().performChanges({
                    // 创建一个保存图片的操作
                    PHAssetCreationRequest.creationRequestForAsset(from: image)
                }, completionHandler: { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.showOneAlert(title: "Reminder".localStr(), message: "The photo has been saved to your album".localStr(), confirm: "Scanning QR code".localStr()) {
                                
                                guard let appURL = URL(string: "oof.disk://") else { return }
                                if UIApplication.shared.canOpenURL(appURL) {
                                    UIApplication.shared.open(appURL)
                                }else{
                                    if let storeURL = URL(string: "https://apps.apple.com/cn/app/id1446829613") {
                                        UIApplication.shared.open(storeURL)
                                    }
                                }
                            }
                        } else {
                            self.view.makeToast(error?.localizedDescription)
                        }
                    }
                })
                break
            case .denied, .restricted, .limited:
                DispatchQueue.main.async {
                    self.showTwoAlert(title: "Reminder".localStr(), message: "You have denied access to the album, please re-enable it.".localStr(), confirm: "Settings".localStr(), cancle: "Cancel".localStr(), style: .alert) {
                        guard let vURL = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(vURL)
                    }
                }
                break
            case .notDetermined:
                // 如果没有权限，提示用户授权
                debugPrint("未决定权限")
                @unknown default: break
            }
        }
    }
    
    // 生成 PKCE 参数
    func generatePKCE() -> String {
        let codeVerifier = generateRandomString(length: Int.random(in: 43...128))
        let verifierData = codeVerifier.data(using: .utf8)!
        let challengeData = sha256(data: verifierData)
        let code_challenge = base64UrlEncode(data: challengeData)
        
        debugPrint("codeVerifier = \(codeVerifier), 长度 = \(codeVerifier.count)")
        self.code_verifier = codeVerifier
        
        return code_challenge
    }
    
    // 生成随机字符串
    func generateRandomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let numbers = "0123456789"
        let allowedCharacters = letters + numbers
        
        var randomString = ""
        
        // 确保字符串以字母开头
        randomString.append(letters.randomElement()!)
        
        // 生成剩余的随机字符
        for _ in 1..<length {
            randomString.append(allowedCharacters.randomElement()!)
        }
        
        return randomString
    }

    // 计算 SHA-256 哈希
    func sha256(data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
    
    // Base64 URL 安全编码
    func base64UrlEncode(data: Data) -> String {
        let base64String = data.base64EncodedString()
        let urlSafeString = base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return urlSafeString
    }
    
}




//class Auth115LifeViewController: SuperViewController {
//    
//    init(onSuccess: @escaping (Drive115UserModel) -> Void) {
//        self.onSuccess = onSuccess
//        super.init(nibName: nil, bundle: nil)
//    }
//    
//    @MainActor public required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    override func preSetupSubViews() {
//        super.preSetupSubViews()
//        
//        contentView.addSubview(webView)
//        contentView.addSubview(loadingView)
//    }
//    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        
//        let navbarHeight = self.navigationController?.navigationBar.height ?? 44
//        webView.frame = CGRectMake(0, navbarHeight, contentView.width, contentView.height)
//        loadingView.frame = CGRectMake((contentView.width - loadingView.width) / 2, (contentView.height - loadingView.height) / 2, loadingView.width, loadingView.height)
//    }
//    
//    override func preSetupHandleBuness() {
//        super.preSetupHandleBuness()
//        
//        self.title = ImportFileType.from115Drive.titleStr()
//        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
//        self.refreshAuthQrCode()
//    }
//    
//    
//    
//    func refreshAuthQrCode() {
//        let url = "https://passportapi.115.com/open/authorize"
//        
//        let parameters: Parameters = [
//            "client_id": client_id,
//            "redirect_uri": Self.drive115RedirectURI,
//            "response_type": "code",
//            "state": Date().convertString()
//        ]
//        
//        self.loadingView.startAnimating()
//        AF.request(url, method: .get, parameters: parameters).validate().responseString { response in
//            switch response.result {
//            case .success(let htmlString):
//                self.webView.loadHTMLString(htmlString, baseURL: URL(string: "https://open.115.com/"))
//            case .failure(let error):
//                debugPrint("Request failed with error: \(error)")
//                self.view.makeToast(error.localizedDescription)
//                self.loadingView.stopAnimating()
//            }
//        }
//    }
//    
//    // MARK:  GET && SET
//    let client_id = "100196055"
//    
//    static let drive115RedirectURI = "passlockapp.com"
//    
//    
//    private let onSuccess: (Drive115UserModel) -> Void
// 
//    // MARK:  懒加载
//    lazy var webView: WKWebView = {
//        let config = WKWebViewConfiguration()
//        let pagePreferences = WKWebpagePreferences()
//        pagePreferences.allowsContentJavaScript = true
//        config.defaultWebpagePreferences = pagePreferences
//        
//        let view = WKWebView(frame: contentView.bounds, configuration: config)
//        view.navigationDelegate = self
//        
//        return view
//    }()
//    
//    
//    lazy var loadingView: NVActivityIndicatorView = {
//        let valueSize = 25.ckValue()
//        let frame = CGRectMake(0, 0, valueSize, valueSize)
//        let view = NVActivityIndicatorView(frame: frame, type: .lineScalePulseOutRapid, color: appMainColor)
//        return view
//    }()
//}
//
//extension Auth115LifeViewController: WKNavigationDelegate {
//    // MARK: - WKNavigationDelegate
//    
//    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//        self.loadingView.stopAnimating()
//    }
//    
//    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
//                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
//
//        debugPrint("⏭️URL = \(navigationAction.request.url?.absoluteString ?? "❌")")
//        self.loadingView.stopAnimating()
//        
//        guard let url = navigationAction.request.url else {
//            decisionHandler(.allow)
//            return
//        }
//        
//        if url.absoluteString == "https://115.com/agreement.html" || url.absoluteString == "https://115.com/privacy.html" {
//            UIApplication.shared.open(url, options: [:], completionHandler: nil)
//        }
//
//        decisionHandler(.allow)
//    }
//
//}


/*
 "⏭️URL = about:blank"
 "⏭️URL = https://passportapi.115.com/bridge_assets.html?cb_key=iframe_cb_key__1752559245514_0&_t1752559245514"
 "⏭️URL = https://115.com/?cid=0&offset=0&mode=wangpan"
 "⏭️URL = http://m.115.com/"
 "⏭️URL = https://m.115.com/"
 */
