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


/// Default: official web authorization. QR / PKCE remains available in the same sheet.
class Auth115LifeViewController: SuperViewController {
    private enum Mode { case web, qr }
    private var mode = Mode.web
    private var attempt = UUID()
    private var request: DataRequest?
    private var pollWork: DispatchWorkItem?
    private var webState: String?
    private var isExchanging = false
    private var didFinish = false
    private var pkceModel: Response115_LoginData?
    private var code_verifier: String?
    private let onSuccess: (Drive115UserModel) -> Void

    init(onSuccess: @escaping (Drive115UserModel) -> Void) {
        self.onSuccess = onSuccess
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        request?.cancel()
        pollWork?.cancel()
    }

    override func preSetupSubViews() {
        super.preSetupSubViews()
        [webView, qrcodeImgView, refreshButton, messageLabel, saveButton, loadingView].forEach { contentView.addSubview($0) }
    }

    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        title = ImportFileType.from115Drive.titleStr()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        startWebLogin()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        webView.frame = contentView.bounds
        let width = min(280, max(100, contentView.bounds.width - 48), contentView.bounds.height * 0.43)
        qrcodeImgView.frame = CGRect(x: (contentView.bounds.width - width) / 2, y: max(view.safeAreaInsets.top + 24, contentView.bounds.height * 0.10), width: width, height: width)
        refreshButton.frame = qrcodeImgView.frame
        messageLabel.frame = CGRect(x: 24, y: qrcodeImgView.frame.maxY + 24, width: contentView.bounds.width - 48, height: 80)
        saveButton.frame = CGRect(x: (contentView.bounds.width - width) / 2, y: messageLabel.frame.maxY + 16, width: width, height: 48)
        loadingView.center = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Interactive sheet dismissal must not leave QR polling or token requests alive.
        if isBeingDismissed || navigationController?.isBeingDismissed == true || isMovingFromParent {
            stopAuthorization()
        }
    }

    @objc override func cancelButtonClick() {
        stopAuthorization()
        super.cancelButtonClick()
    }

    private func stopAuthorization() {
        attempt = UUID()
        request?.cancel()
        request = nil
        pollWork?.cancel()
        pollWork = nil
        webView.stopLoading()
        webState = nil
        isExchanging = false
        pkceModel = nil
        code_verifier = nil
        loadingView.stopAnimating()
    }

    private func setMode(_ newMode: Mode) {
        stopAuthorization()
        mode = newMode
        didFinish = false
        webView.isHidden = newMode != .web
        [qrcodeImgView, refreshButton, messageLabel, saveButton].forEach { $0.isHidden = true }
        let title = (newMode == .web ? "Scan QR Code" : "Sign In").localStr()
        let button = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(switchLoginMode))
        button.image = UIImage(systemName: newMode == .web ? "qrcode" : "globe")
        button.accessibilityLabel = title
        navigationItem.rightBarButtonItem = button
    }

    @objc private func switchLoginMode() {
        if mode == .web { refreshAuthQrCode() } else { startWebLogin() }
    }

    private func startWebLogin() {
        setMode(.web)
        let state = generateRandomString(length: 48)
        webState = state
        guard let url = Drive115WebOAuth.authorizationURL(clientID: Drive115_ClientID, redirectURI: Drive115_RedirectURL, state: state) else {
            failAuthorization()
            return
        }
        loadingView.startAnimating()
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
    }

    private func failAuthorization(code: Int? = nil) {
        guard !didFinish else { return }
        stopAuthorization()
        let message = "Authentication Failed".localStr() + (code.map { " (\($0))" } ?? "")
        // Do not show raw HTTP responses, request URLs, codes, secrets or tokens.
        showTwoAlert(message: message, confirm: "Retry".localStr(), cancle: "Cancel".localStr()) { [weak self] in
            guard let self else { return }
            if self.mode == .web { self.startWebLogin() } else { self.refreshAuthQrCode() }
        }
    }

    // QR fallback uses the original official PKCE endpoints, with cancellable polling.
    @objc func refreshAuthQrCode() {
        setMode(.qr)
        let id = attempt
        messageLabel.text = "Please use the Cloud Storage app to scan this QR code to log in".localStr()
        loadingView.startAnimating()
        let parameters: Parameters = [
            "client_id": Drive115_ClientID,
            "code_challenge": generatePKCE(),
            "code_challenge_method": "sha256"
        ]
        request = AF.request("https://passportapi.115.com/open/authDeviceCode", method: .post,
                             parameters: parameters, encoding: URLEncoding.httpBody)
            .redirect(using: Redirector(behavior: .doNotFollow))
            .validate(statusCode: 200..<300).responseData { [weak self] result in
                guard let self, self.attempt == id, self.mode == .qr else { return }
                guard let bytes = result.data, result.error == nil,
                      let response = Response115_LoginModel.deserialize(from: String(data: bytes, encoding: .utf8)),
                      let qr = response.data, !qr.uid.isEmpty, !qr.qrcode.isEmpty else {
                    self.failAuthorization()
                    return
                }
                self.pkceModel = qr
                self.qrcodeImgView.image = qr.qrcode.generateQRCode(ImportFileType.from115Drive.iconImage())
                self.qrcodeImgView.isHidden = false
                self.messageLabel.isHidden = false
                self.saveButton.isHidden = kaka_IsMacOS()
                self.loadingView.stopAnimating()
                self.pollQRCode(id: id)
            }
    }

    private func schedulePoll(id: UUID) {
        pollWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.pollQRCode(id: id) }
        pollWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func pollQRCode(id: UUID) {
        guard attempt == id, mode == .qr, !isExchanging, let qr = pkceModel else { return }
        let parameters: Parameters = ["uid": qr.uid, "time": qr.time, "sign": qr.sign]
        request = AF.request("https://qrcodeapi.115.com/get/status/", parameters: parameters,
                             requestModifier: { $0.timeoutInterval = 30 })
            .redirect(using: Redirector(behavior: .doNotFollow))
            .validate(statusCode: 200..<300).responseData { [weak self] result in
                guard let self, self.attempt == id, self.mode == .qr else { return }
                guard result.error == nil, let bytes = result.data,
                      let response = Response115_LoginModel.deserialize(from: String(data: bytes, encoding: .utf8)) else {
                    self.schedulePoll(id: id)
                    return
                }
                if response.state == 0 || response.data?.status == -1 || response.data?.status == -2 {
                    self.refreshButton.isHidden = false
                    return
                }
                if response.data?.status == 2 {
                    guard let verifier = self.code_verifier else { self.failAuthorization(); return }
                    self.exchangeToken(url: "https://passportapi.115.com/open/deviceCodeToToken/",
                                       parameters: ["uid": qr.uid, "code_verifier": verifier], id: id)
                } else {
                    self.schedulePoll(id: id)
                }
            }
    }

    private func exchangeToken(url: String, parameters: Parameters, id: UUID) {
        guard attempt == id, !isExchanging, !didFinish else { return }
        isExchanging = true
        pollWork?.cancel()
        loadingView.startAnimating()
        request = AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.httpBody,
                             requestModifier: { $0.timeoutInterval = 30 })
            .redirect(using: Redirector(behavior: .doNotFollow))
            .validate(statusCode: 200..<300).responseData { [weak self] result in
                guard let self, self.attempt == id, !self.didFinish else { return }
                guard result.error == nil, let bytes = result.data,
                      let response = Response115_LoginModel.deserialize(from: String(data: bytes, encoding: .utf8)) else {
                    self.failAuthorization()
                    return
                }
                guard response.code == 0, let token = response.data,
                      let access = token.access_token, !access.isEmpty,
                      let refresh = token.refresh_token, !refresh.isEmpty else {
                    self.failAuthorization(code: response.code)
                    return
                }
                self.fetchUser(token: token, id: id)
            }
    }

    private func fetchUser(token: Response115_LoginData, id: UUID) {
        guard attempt == id, let access = token.access_token else { return }
        request = AF.request("https://proapi.115.com/open/user/info",
                             headers: ["Authorization": "Bearer \(access)"],
                             requestModifier: { $0.timeoutInterval = 30 })
            .redirect(using: Redirector(behavior: .doNotFollow))
            .validate(statusCode: 200..<300).responseData { [weak self] result in
                guard let self, self.attempt == id, !self.didFinish else { return }
                guard result.error == nil, let bytes = result.data,
                      let json = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                      (json["state"] as? NSNumber)?.boolValue == true,
                      let data = json["data"] as? [String: Any],
                      var user = Drive115UserModel.deserialize(from: data), !user.user_id.isEmpty else {
                    self.failAuthorization()
                    return
                }
                user.access_token = token.access_token ?? ""
                user.refresh_token = token.refresh_token ?? ""
                user.expires_in = token.expires_in ?? 0
                self.didFinish = true
                self.loadingView.stopAnimating()
                let server = ServerConfigModel(serverType: .from115Drive, drive115User: user)
                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: server) { [weak self] in
                    guard let self, self.attempt == id else { return }
                    self.stopAuthorization()
                    if self.routeImportedServer(server) {
                        NotificationCenter.default.post(name: Notification.Name(kLoginThirdServerKey), object: nil)
                        return
                    }
                    self.onSuccess(user)
                    NotificationCenter.default.post(name: Notification.Name(kLoginThirdServerKey), object: nil)
                    self.cancelButtonClick()
                }
            }
    }

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        return web
    }()
    private lazy var loadingView = NVActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 28, height: 28), type: .lineScalePulseOutRapid, color: .label)
    private let qrcodeImgView: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFit
        return image
    }()
    private lazy var refreshButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        button.tintColor = .white
        button.accessibilityLabel = "Retry".localStr()
        button.addTarget(self, action: #selector(refreshAuthQrCode), for: .touchUpInside)
        return button
    }()
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        return label
    }()
    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Save QR Code".localStr()
        button.configuration = config
        button.addTarget(self, action: #selector(saveButtonClick), for: .touchUpInside)
        return button
    }()
}

extension Auth115LifeViewController: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard mode == .web, !didFinish, let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.absoluteString == "about:blank", navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
            return
        }
        if Drive115WebOAuth.isCallbackHost(url, redirectURI: Drive115_RedirectURL) {
            // Cancel BEFORE requesting the company's URL, even on malformed callbacks.
            decisionHandler(.cancel)
            guard navigationAction.targetFrame?.isMainFrame != false, !isExchanging else { return }
            guard let state = webState,
                  let code = Drive115WebOAuth.authorizationCode(url, redirectURI: Drive115_RedirectURL, expectedState: state) else {
                failAuthorization()
                return
            }
            webState = nil // Consume exactly once.
            // The authorization-code endpoint requires AppSecret, NOT AppKey.
            // Keep the secret in the POST body; the browser only receives ClientID.
            exchangeToken(url: "https://passportapi.115.com/open/authCodeToToken", parameters: [
                "client_id": Drive115_ClientID, "client_secret": Drive115_AppSecret,
                "code": code, "redirect_uri": Drive115_RedirectURL, "grant_type": "authorization_code"
            ], id: attempt)
            return
        }
        guard url.scheme == "https", let host = url.host?.lowercased(),
              host == "115.com" || host.hasSuffix(".115.com") else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Keep target=_blank inside the same delegate-controlled authorization view.
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url,
           url.scheme == "https" { webView.load(navigationAction.request) }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !isExchanging { loadingView.stopAnimating() }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleWebError(error)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleWebError(error)
    }
    private func handleWebError(_ error: Error) {
        let error = error as NSError
        guard mode == .web, !isExchanging, !didFinish, webState != nil,
              error.code != NSURLErrorCancelled,
              !(error.domain == "WebKitErrorDomain" && error.code == 102) else { return }
        failAuthorization()
    }
}

/// Pure URL validation for the in-app HTTPS callback. Does not contain secrets.
enum Drive115WebOAuth {
    static func authorizationURL(clientID: String, redirectURI: String, state: String) -> URL? {
        guard !clientID.isEmpty, !state.isEmpty,
              let redirect = URL(string: redirectURI), redirect.scheme == "https", redirect.host != nil else { return nil }
        var url = URLComponents(string: "https://passportapi.115.com/open/authorize")!
        url.queryItems = [URLQueryItem(name: "client_id", value: clientID),
                          URLQueryItem(name: "redirect_uri", value: redirectURI),
                          URLQueryItem(name: "response_type", value: "code"),
                          URLQueryItem(name: "state", value: state)]
        return url.url
    }

    static func isCallbackHost(_ url: URL, redirectURI: String) -> Bool {
        guard let host = URL(string: redirectURI)?.host?.lowercased() else { return false }
        return url.host?.lowercased() == host
    }

    static func authorizationCode(_ url: URL, redirectURI: String, expectedState: String) -> String? {
        guard !expectedState.isEmpty, let expected = URL(string: redirectURI),
              isCallbackHost(url, redirectURI: redirectURI), url.scheme == "https",
              (url.port ?? 443) == (expected.port ?? 443),
              url.path == expected.path, url.user == nil, url.password == nil,
              url.fragment == nil, let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        let states = query.filter { $0.name == "state" }
        let codes = query.filter { $0.name == "code" }
        guard !query.contains(where: { $0.name == "error" }),
              states.count == 1, states[0].value == expectedState,
              codes.count == 1, let code = codes[0].value,
              !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return code
    }
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
                            self.showOneAlert(message: "Photo saved to your Photos.".localStr(), confirm: "Scan QR Code".localStr()) {
                                
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
                    self.showTwoAlert(message: "You have denied access to the album, please re-enable it.".localStr(), confirm: "Settings".localStr(), cancle: "Cancel".localStr(), style: .alert) {
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
