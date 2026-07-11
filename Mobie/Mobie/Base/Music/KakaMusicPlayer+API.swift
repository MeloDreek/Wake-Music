//
//  KakaMusicPlayer+API.swift
//  Mobie
//
//  Created by 张文 on 7/13/25.
//

import KakaFoundation
import AliyunpanSDK
import AppGroupKit
import Alamofire
import GoogleSignIn
import SmartCodable
import Kingfisher
import SwiftyDropbox
#if canImport(MSAL)
import MSAL
#endif

// MARK: 百度网盘
extension KakaMusicPlayer {
    
    /// 获取百度网盘的文件列表
    public func fetchBaiduFileList(serverModel: ServerConfigModel?, start: Int = 0, limit: Int = 1000, completion: @escaping (Result<[BaiduDriveFileModel], KakaError>) -> Void) {
        
        guard let baiduUser = serverModel?.baiduUser else {
            completion(.failure(KakaError.custom("Access token is nil")))
            return
        }
        
        let url = "https://pan.baidu.com/rest/2.0/xpan/file"
        
        let parameters: Parameters = [
            "method": "list",
            "access_token": baiduUser.access_token,
            "vip_version": "v2",
            "dir": baiduUser.path ?? "/",
            "start": start,
            "limit": limit
        ]
        
        debugPrint("参数parameters = \(parameters)")
        
        AF.request(url, method: .get, parameters: parameters).responseString { response in
            switch response.result {
            case .success(let responseString):
                
                debugPrint("百度文件列表 = \(responseString)")
                                
                guard let reponseModel = BaiduResponseModel.deserialize(from: responseString) else {
                    completion(.failure(KakaError.custom(responseString)))
                    return
                }
                
                if reponseModel.isTokenInvalid() {
                    completion(.failure(KakaError.tokenExpiredAuthAgain))
                }else{
                    let files = reponseModel.list ?? []
                    completion(.success(files))
                }
                                
            case .failure(let error):
                completion(.failure(KakaError.custom(error.errorDescription ?? error.localizedDescription)))
            }
        }
    }
    
    /// 获取百度文件的m3u8缓存URL，如果是百度不支持的格式，那就使用下载URL去播放
    @MainActor func handleBaiduStreaming(_ model: MusicItemModel) {
        guard let baiduFile = model.baiduFileModel, let baiduUser = baiduFile.baiduUser else {
            debugPrint("暂无token信息")
            self.playbackStatus = .error
            return
        }
        
        if baiduUser.isPremium() {
            debugPrint("网盘会员播放源文件")
            self.fetchBaiduDownloadURL(accessToken: baiduUser.access_token, fileModel: baiduFile) { downloadResult in
                switch downloadResult {
                case .success(let downloadURL):
                    self.playingMusic?.mediaPlayURL = downloadURL
                    if let tempModel = self.playingMusic {
                        self.playerView.set(url: downloadURL, options: self.audioOption(tempModel))
                    }
                    self.continueToPlay(model)
                case .failure(let failure):
                    self.playerView.resetPlayer()
                    appKeyWindow?.makeToast(failure.errorDescription)
                }
            }
            
            return
        }
        
        // 百度网盘没有m3u8缓存文件时
        self.fetchBaiduMediaPlayURL(accessToken: baiduUser.access_token, fileModel: baiduFile) { playResult in
            switch playResult {
            case .success(let m3uURL):
                self.playingMusic?.mediaPlayURL = m3uURL
                if let tempModel = self.playingMusic {
                    self.playerView.set(url: m3uURL, options: self.audioOption(tempModel))
                }
                
                self.continueToPlay(model)
            case .failure(let playError):
                
                if playError == .tokenExpiredAuthAgain {
                    // 重新授权
                    self.currentViewController()?.showOneAlert(title: "Reminder".localStr(), message: "Login failed or token has expired, please reauthorize".localStr()) {
                        
                        KakaCacheTools.clearWebViewCache(displayName: "baidu")
                        let baiduVC = AuthBaiduViewController { serverModel in
                            // 1️⃣更新播放列表
                            var newArray = [MusicItemModel]()
                            for index in 0..<self.musicArray.count {
                                var subModel = self.musicArray[index]
                                if let _ = subModel.baiduFileModel {
                                    subModel.baiduFileModel?.baiduUser = serverModel.baiduUser
                                }
                                
                                newArray.append(subModel)
                            }
                            
                            KakaMusicPlayer.shared.musicArray = newArray
                            KakaMusicPlayer.shared.tempMusicArray = newArray
                            
                            // 2️⃣当前播放的音乐
                            if var playingMusic = KakaMusicPlayer.shared.playingMusic {
                                if let _ = playingMusic.baiduFileModel {
                                    playingMusic.baiduFileModel?.baiduUser = serverModel.baiduUser
                                    self.playingMusic = playingMusic
                                    
                                    KakaMusicPlayer.shared.play()
                                }
                            }
                                                        
                        } onFailure: { error in
                            self.currentViewController()?.showOneAlert(title: "Reminder".localStr(), message: error.errorDescription)
                        }
                        let navVC = KakaNavigationController(rootViewController: baiduVC)
                        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
                        self.currentViewController()?.present(navVC, animated: true)
                    }
                    return
                }
               
                if let baiduError = BaiduDriveError.parseError(playError), baiduError.isUnsupportedFormat(), UIApplication.shared.applicationState == .active {
                    appKeyWindow?.makeToast("This format isn’t supported for streaming on the Cloud Drive. Loading...".localStr(), duration: 6)
                }
                
                self.fetchBaiduDownloadURL(accessToken: baiduUser.access_token, fileModel: baiduFile) { downloadResult in
                    switch downloadResult {
                    case .success(let downloadURL):
                        self.playingMusic?.mediaPlayURL = downloadURL
                        if let tempModel = self.playingMusic {
                            self.playerView.set(url: downloadURL, options: self.audioOption(tempModel))
                        }
                        self.continueToPlay(model)
                    case .failure(let failure):
                        self.playerView.resetPlayer()
                        appKeyWindow?.makeToast(failure.errorDescription)
                    }
                }
                
            }
        }
    }
    
    /// 获取百度网盘的下载URL
    public func fetchBaiduDownloadURL(accessToken: String, fileModel: BaiduDriveFileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        let url = "https://pan.baidu.com/rest/2.0/xpan/multimedia"
        let fsids = [fileModel].map { $0.fs_id }
        let fsidString = "[\(fsids.map { String($0) }.joined(separator: ","))]"
        
        let parameters: Parameters = [
            "method": "filemetas",
            "access_token": accessToken,
            "dlink": 1,
            "fsids": fsidString
        ]
        
        // 百度要求的 User-Agent 和 Host
        let headers: Alamofire.HTTPHeaders = [
            "User-Agent": "pan.baidu.com"
        ]
        
        AF.request(url, method: .get, parameters: parameters, headers: headers).responseString { response in
            switch response.result {
            case .success(let responseString):
                let reponseModel = BaiduResponseModel.deserialize(from: responseString)
                
                guard let files = reponseModel?.list, let firstFile = files.first, let fileURL = URL(string: firstFile.dlink ?? "") else {
                    let errorMsg = (reponseModel?.guid_info ?? "") + "\(reponseModel?.errno ?? -1)"
                    completion(.failure(KakaError.custom(errorMsg)))
                    return
                }
                
                var components = URLComponents(url: fileURL, resolvingAgainstBaseURL: false)
                    
                // 保留已有参数，再追加 access_token
                var queryItems = components?.queryItems ?? []
                queryItems.append(URLQueryItem(name: "access_token", value: accessToken))
                components?.queryItems = queryItems
                completion(.success(components!.url!))
            case .failure(let error):
                completion(.failure(KakaError.custom(error.errorDescription ?? error.localizedDescription)))
            }
        }
    }

    // 获取百度网盘的m3u8点播URL
    public func fetchBaiduMediaPlayURL(accessToken: String, fileModel: BaiduDriveFileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        
        let url = "https://pan.baidu.com/rest/2.0/xpan/file"
        let parameters: Parameters = [
            "method": "streaming",
            "access_token": accessToken,
            "path": fileModel.path,
            "type": "M3U8_HLS_MP3_128"
        ]
        
        debugPrint("百度点播parameters = \(parameters)")
                
        // 百度要求的 User-Agent 和 Host
        let headers: Alamofire.HTTPHeaders = [
            "User-Agent": self.generateBaiduUserAgent(),
            "Host": "pan.baidu.com"
        ]

        AF.request(url, method: .get, parameters: parameters, headers: headers).responseString { response in
            guard let statusCode = response.response?.statusCode else {
                completion(.failure(KakaError.custom(response.value ?? "")))
                return
            }
                        
            if let m3u8String = response.value, statusCode == 200 {
                
                guard let responseModel = BaiduResponseModel.deserialize(from: m3u8String), responseModel.isTokenInvalid() else {
                    let fileURL = fileModel.m3uCacheURL()
                    
                    do {
                        if FileManager.default.fileExists(atPath: fileURL.path) {
                            try? FileManager.default.removeItem(at: fileURL)
                        }
                        
                        try m3u8String.write(to: fileURL, atomically: true, encoding: .utf8)
                        debugPrint("m3u8播放地址 = \(fileURL)")
                        completion(.success(fileURL))
                    } catch {
                        debugPrint("❌ 写入 m3u8 文件失败: \(error)")
                        completion(.failure(KakaError.custom(error.localizedDescription)))
                    }
                    return
                }
                
                completion(.failure(.tokenExpiredAuthAgain))
            }else{
                let errorMsg = (response.value ?? "") + " " + "\(statusCode)"
                completion(.failure(KakaError.custom(errorMsg)))
            }
        }
    }

    private func generateBaiduUserAgent() -> String {
        let prefix = "xpanaudio" // 音乐播放器场景推荐使用

        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "UnknownApp"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"

        let device = UIDevice.current
        let sysName = device.systemName // iOS
        let sysVersion = device.systemVersion // e.g. 17.5.1

        return "\(prefix);\(appName);\(appVersion);\(sysName);\(sysVersion);ts"
    }
     
}

// MARK: 阿里云盘
extension KakaMusicPlayer {
    
    // 处理阿里云盘的播放
    @MainActor func handleAliyunpanStreaming(_ model: MusicItemModel) {
        guard let aliFileModel = model.aliFileModel else {
            debugPrint("暂无token信息")
            self.playbackStatus = .error
            return
        }
        
        self.fetchAliyunDownloadURL(fileModel: aliFileModel) { result in
            switch result {
            case .success(let downloadURL):
                self.playingMusic?.mediaPlayURL = downloadURL
                if let vModel = self.playingMusic {
                    self.playerView.set(url: downloadURL, options: self.audioOption(vModel))
                }
                self.continueToPlay(model)
                
            case .failure(let failure):
                self.playerView.resetPlayer()
                
                self.playbackStatus = .error
                if failure == .tokenExpiredAuthAgain {
                    self.currentViewController()?.showOneAlert(title: "Reminder".localStr(), message: KakaError.tokenExpiredAuthAgain.errorDescription, confirm: "OK".localStr()) {
                        
                        self.authorizedAliyunpan { result in
                            switch result {
                            case .success(let userModel):
                                // 1️⃣更新播放列表
                                var newArray = [MusicItemModel]()
                                for index in 0..<self.musicArray.count {
                                    var subModel = self.musicArray[index]
                                    if let _ = subModel.aliFileModel {
                                        subModel.aliFileModel?.aliyunUser = userModel
                                    }
                                    
                                    newArray.append(subModel)
                                }
                                
                                KakaMusicPlayer.shared.musicArray = newArray
                                KakaMusicPlayer.shared.tempMusicArray = newArray
                                
                                // 2️⃣当前播放的音乐
                                if var playingMusic = KakaMusicPlayer.shared.playingMusic {
                                    if let _ = playingMusic.aliFileModel {
                                        playingMusic.aliFileModel?.aliyunUser = userModel
                                        self.playingMusic = playingMusic
                                        
                                        KakaMusicPlayer.shared.play()
                                    }
                                }
                                break
                            case .failure(let failure):
                                break
                            }
                        }
                    }
                }else{
                    self.currentViewController()?.showOneAlert(title: "Reminder".localStr(), message: failure.errorDescription)
                }
            }
        }

    }
    
    // 授权阿里云盘
    func authorizedAliyunpan(completion: @escaping (Result<AliyunpanUserModel, KakaError>) -> Void) {
        Task {
            do {
                // 初始化配置
                let config = AliyunpanClientConfig(appId: Aliyun_AppID, scope: Aliyun_Scopes)
                let client = AliyunpanClient(config)
                
                // 3. 执行授权，// .pkce 会自动处理跳转逻辑
                let token: AliyunpanToken = try await client.authorize(credentials: .pkce)
                
                // 获取用户的信息
                let userProfile = try await client.send(AliyunpanScope.User.GetDriveInfo())
                                                
                // 4. 授权成功：进入文件列表页或刷新 UI
                await MainActor.run {
                    
                    let aliyunUser = AliyunpanUser(user_id: userProfile.user_id, name: userProfile.name, avatar: userProfile.avatar, default_drive_id: userProfile.default_drive_id)
                    
                    let userModel = AliyunpanUserModel(token_type: token.token_type, access_token: token.access_token, refresh_token: token.refresh_token, expires_in: token.expires_in, aliUser: aliyunUser)
                    let serverModel = ServerConfigModel(serverType: .fromAliyunDrive, aliyunUser: userModel)
                    ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: serverModel) {
                        completion(.success(userModel))
                    }
                }
            } catch {
                await MainActor.run {
                    #if Target_Mobie_Pro
                    completion(.failure(KakaError.custom("授权异常，建议使用永不过期的Webdav连接您的阿里云盘（阿里云盘App内查看您的Webdav账号密码）")))
                    #else
                    completion(.failure(KakaError.custom(error.localizedDescription)))
                    #endif
                }
            }
        }
    }
    
    /// 获取阿里云盘某个文件夹下的所有文件信息（内部自动处理分页）
    /// - Parameters:
    ///   - parentFileId: 文件夹ID，根目录传 "root"
    ///   - driveId: 网盘ID（必须提供，通常从 GetDriveInfo 获取）
    public func fetchAliyunFileList(serverModel: ServerConfigModel?, limit: Int = 100, completion: @escaping (Result<[AliyunpanFileModel], KakaError>) -> Void) {
        
        guard let aliyunUser = serverModel?.aliyunUser else {
            completion(.failure(KakaError.custom("Access token is nil")))
            return
        }
        
        if aliyunUser.isExpired() {
            completion(.failure(KakaError.tokenExpiredAuthAgain))
            return
        }
        
        
        Task {
            var allFileArray: [AliyunpanFileModel] = []
            var currentMarker: String? = nil
            
            let config = AliyunpanClientConfig(appId: Aliyun_AppID, scope: Aliyun_Scopes)
            let aliyunClient = AliyunpanClient(config)
            
            do {
                repeat {
                    // 1. 构造请求
                    let drive_id = aliyunUser.aliUser?.default_drive_id ?? "" // 网盘ID
                    let parentFolderID = aliyunUser.parentFolderID ?? "root"   // 文件夹ID
                    let params = AliyunpanFileScope.GetFileList.Request(drive_id: drive_id, parent_file_id: parentFolderID, limit: limit, marker: currentMarker, category: .audio, fields: "*")
                    let request = AliyunpanScope.File.GetFileList(params)
                    
                    // 2. 发送请求
                    let response = try await aliyunClient.send(request)
                    
                    let models = response.items.map { $0.convertAliyunFile(drive_id) }
                    allFileArray.append(contentsOf: models)
                    
                    // 3. 更新游标，准备下一页
                    currentMarker = response.next_marker
                    
                    // 如果 next_marker 为空字符串或 nil，说明加载完毕
                } while currentMarker != nil && !currentMarker!.isEmpty
                
                // 5. 全部获取完成，回调成功
                DispatchQueue.main.async {
                    completion(.success(allFileArray))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(KakaError.custom(error.localizedDescription)))
                }
            }
        }
    }
    
    /// 获取阿里云盘的下载URL
    public func fetchAliyunDownloadURL(fileModel: AliyunpanFileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        // 1. 基础校验
        guard let aliyunUser = fileModel.aliyunUser, !fileModel.drive_id.isEmpty, !fileModel.file_id.isEmpty else {
            completion(.failure(KakaError.custom("Invalid drive_id or file_id")))
            return
        }
        
        if aliyunUser.isExpired() {
            completion(.failure(.tokenExpiredAuthAgain))
            return
        }
        
        let sizeLimit: Int64 = 5 * 1024 * 1024
        if let fileSize = fileModel.size, fileSize > 0, fileSize <= sizeLimit,
           let rawUrlString = fileModel.url, let downloadUrl = URL(string: rawUrlString) {
            debugPrint("⚡️ 文件小于 5MB，使用模型自带 URL")
            completion(.success(downloadUrl))
            return
        }
        
        Task {
            do {
                // 2. 初始化 Client（建议复用全局 client，此处仅为示例）
                let config = AliyunpanClientConfig(appId: Aliyun_AppID, scope: Aliyun_Scopes)
                let aliyunClient = AliyunpanClient(config)
                
                // 3. 构造请求参数
                let params = AliyunpanFileScope.GetFileDownloadUrl.Request(
                    drive_id: fileModel.drive_id,
                    file_id: fileModel.file_id,
                    expire_sec: 900
                )
                let request = AliyunpanScope.File.GetFileDownloadUrl(params)
                
                // 4. 发送请求
                let response = try await aliyunClient.send(request)
                
                // 5. 解析并回调
                await MainActor.run {
                    completion(.success(response.url))
                }
                
            } catch {
                await MainActor.run {
                    completion(.failure(KakaError.custom(error.localizedDescription)))
                }
            }
        }
    }
    
}

// MARK:  115网盘
extension KakaMusicPlayer {
    
    // 处理115网盘的播放，暂不支持点播
    @MainActor func handle115DriveStreaming(_ model: MusicItemModel) {
        guard let drive115Model = model.drive115Model else {
            debugPrint("暂无token信息")
            self.playbackStatus = .error
            return
        }
        
        self.fetch115DownloadPlayURL(file115: drive115Model) { result in
            switch result {
            case .success(let downloadURL):
                self.playingMusic?.mediaPlayURL = downloadURL
                if let vModel = self.playingMusic {
                    self.playerView.set(url: downloadURL, options: self.audioOption(vModel))
                }
                self.continueToPlay(model)
                
//                let fileName = model.downloadPathName()
//                let targetFileURL = SandboxFileManager.shared.preDownloadURL().appendingPathComponent(fileName)
//                self.download(downloadURL: downloadURL, targetFileURL: targetFileURL)
                
            case .failure(let failure):
                self.playerView.resetPlayer()
                
                self.playbackStatus = .error
                if failure == .tokenExpiredAuthAgain {
                    self.currentViewController()?.showOneAlert(title: "Reminder".localStr(), message: KakaError.tokenExpiredAuthAgain.errorDescription, confirm: "OK".localStr()) {
                        let drive115VC = Auth115LifeViewController { userModel in
                            // 1️⃣更新播放列表
                            var newArray = [MusicItemModel]()
                            for index in 0..<self.musicArray.count {
                                var subModel = self.musicArray[index]
                                if let _ = subModel.drive115Model {
                                    subModel.drive115Model?.drive115User = userModel
                                }
                                
                                newArray.append(subModel)
                            }
                            
                            KakaMusicPlayer.shared.musicArray = newArray
                            KakaMusicPlayer.shared.tempMusicArray = newArray
                            
                            // 2️⃣当前播放的音乐
                            if var playingMusic = KakaMusicPlayer.shared.playingMusic {
                                if let _ = playingMusic.drive115Model {
                                    playingMusic.drive115Model?.drive115User = userModel
                                    self.playingMusic = playingMusic
                                    
                                    KakaMusicPlayer.shared.play()
                                }
                            }
                            
                        }

                        let navVC = KakaNavigationController(rootViewController: drive115VC)
                        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
                        self.currentViewController()?.present(navVC, animated: true)
                    }
                }else{
                    self.currentViewController()?.showOneAlert(title: "Reminder".localStr(), message: failure.errorDescription)
                }
            }
        }

    }
    

    /// 获取115网盘的文件夹列表（自动分页 + 自动刷新 token）
    public func fetch115DriveFiles(
        serverModel: ServerConfigModel?,
        completion: @escaping (Result<[Drive115FileModel], KakaError>) -> Void) {
        
        guard let oldServer = serverModel, let _ = oldServer.drive115User else {
            completion(.failure(KakaError.custom("Access token is nil")))
            return
        }
        
        let url = "https://proapi.115.com/open/ufile/files"
        let limit = 1150
        
        // 用于累积所有分页结果
        var allFiles: [Drive115FileModel] = []
        
        // 内部递归请求方法
        func requestPage(server: ServerConfigModel, offset: Int) {
            guard let user = server.drive115User else {
                completion(.failure(KakaError.custom("Access token is nil")))
                return
            }
            
            let parameters: Parameters = [
                "cid": user.cid ?? 0,
                "show_dir": 1,
                "stdir": 1,
                "offset": offset,
                "limit": limit
            ]
            
            var headers: Alamofire.HTTPHeaders = HTTPHeaders.default
            headers.add(name: "Authorization", value: "Bearer \(user.access_token)")
            
            AF.request(url, method: .get, parameters: parameters, headers: headers)
                .responseString { [weak self] response in
                    
                    switch response.result {
                    case .success(let responseString):
                        
                        debugPrint("获取115文件列表(offset=\(offset)) ✅ = \(responseString)")
                        
                        guard let responseModel = Response115FilesModel.deserialize(from: responseString) else {
                            completion(.failure(KakaError.custom(responseString)))
                            return
                        }
                        
                        // 处理 token 失效
                        if responseModel.isRefreshToken() {
                            self?.refresh115AaccessToken(configModel: server) { result in
                                switch result {
                                case .success(let newServer):
                                    // 用新 token 继续当前分页
                                    requestPage(server: newServer, offset: offset)
                                case .failure(let error):
                                    completion(.failure(error))
                                }
                            }
                            return
                        }
                        
                        if responseModel.isNeedReAuth115() {
                            completion(.failure(.tokenExpiredAuthAgain))
                            return
                        }
                        
                        guard responseModel.state,
                              let files = responseModel.data else {
                            let message = (responseModel.message ?? "") + " \(responseModel.code ?? -1)"
                            completion(.failure(KakaError.custom(message)))
                            return
                        }
                        
                        // 映射并追加结果
                        let mappedFiles: [Drive115FileModel] = files.map {
                            var model = $0
                            model.drive115User = user
                            model.path = responseModel.path
                            return model
                        }
                        
                        allFiles.append(contentsOf: mappedFiles)
                        
                        // 判断是否需要继续分页
                        if files.count == limit {
                            let nextOffset = (responseModel.offset ?? offset) + limit
                            requestPage(server: server, offset: nextOffset)
                        } else {
                            // 分页结束
                            completion(.success(allFiles))
                        }
                        
                    case .failure(let error):
                        debugPrint("获取115文件列表❌ = \(error.localizedDescription)")
                        completion(.failure(KakaError.custom(error.localizedDescription)))
                    }
                }
        }
        
        // 从第一页开始
        requestPage(server: oldServer, offset: 0)
    }

    /*
     "获取115文件列表✅ = {\"state\":false,\"message\":\"access_token \\u65e0\\u6548\",\"code\":40140125,\"data\":[]}"
     "刷新115网盘token = {\"state\":0,\"code\":40140116,\"errno\":40140116,\"data\":{},\"message\":\"no auth\",\"error\":\"no auth\"}"
     */
    
    /// 刷新115生活的token
    func refresh115AaccessToken(configModel: ServerConfigModel, completion: @escaping (Result<ServerConfigModel, KakaError>) -> Void) {
        
        guard var drive115User = configModel.drive115User else {
            completion(.failure(KakaError.custom("Access token is empty")))
            return
        }
        
        let url = "https://passportapi.115.com/open/refreshToken"
        
        let parameters: Parameters = [
            "refresh_token": drive115User.refresh_token
        ]
        
        var headers: Alamofire.HTTPHeaders = HTTPHeaders.default
        headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        
        AF.request(url, method: .post, parameters: parameters, headers: headers).responseData { response in
            switch response.result {
            case .success(let data):
                let responseString = String(data: data, encoding: .utf8) ?? ""
                debugPrint("刷新115网盘token = \(String(data: data, encoding: .utf8) ?? "")")

                guard let refreshModel = Response115RefreshModel.deserialize(from: responseString) else {
                    completion(.failure(KakaError.custom(responseString)))
                    return
                }
                
                guard let data = refreshModel.data, refreshModel.state, !data.access_token.isEmpty else {
                    if refreshModel.isRefreshToken() {
                        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.12) {
                            // 继续刷新token
                            self.refresh115AaccessToken(configModel: configModel, completion: completion)
                        }
                    }else if refreshModel.isNeedReAuth115() {
                        // 需要重新授权
                        completion(.failure(.tokenExpiredAuthAgain))
                    }else{
                        let message = (refreshModel.message ?? "") + " " + "\((refreshModel.code ?? -1))"
                        completion(.failure(KakaError.custom(message)))
                    }
                    return
                }
                                                
                drive115User.access_token = data.access_token
                drive115User.refresh_token = data.refresh_token
                drive115User.expires_in = data.expires_in
                
                let drive115Server = ServerConfigModel(serverType: .from115Drive, drive115User: drive115User)

                // 1️⃣更新播放列表
                var newArray = [MusicItemModel]()
                for index in 0..<self.musicArray.count {
                    var subModel = self.musicArray[index]
                    if let _ = subModel.drive115Model {
                        subModel.drive115Model?.drive115User = drive115User
                    }
                    
                    newArray.append(subModel)
                }
                
                KakaMusicPlayer.shared.musicArray = newArray
                KakaMusicPlayer.shared.tempMusicArray = newArray
                
                // 2️⃣当前播放的音乐
                if var playingMusic = KakaMusicPlayer.shared.playingMusic {
                    if let _ = playingMusic.drive115Model {
                        playingMusic.drive115Model?.drive115User = drive115User
                        
                        KakaMusicPlayer.shared.playingMusic = playingMusic
                        
                        DispatchQueue.main.async {
                            KakaMusicPlayer.shared.play()
                        }
                    }
                }
                
                // 更新服务器，收藏的文件夹、收藏的歌曲
                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: drive115Server) {
                    completion(.success(drive115Server))
                }
                break
            case .failure(let error):
                completion(.failure(KakaError.custom(error.errorDescription ?? error.localizedDescription)))
                break
            }
        }
    }
    
    /// 获取115生活音视频的下载地址
    func fetch115DownloadPlayURL(file115: Drive115FileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        
        guard let drive115User = file115.drive115User else {
            completion(.failure(KakaError.custom("Access token is empty")))
            return
        }
        
//        let specialArray = ["dsd", "dsf", "dff"]
//        if specialArray.contains(file115.fileExtension().lowercased()) {
//            completion(.failure(KakaError.custom("115暂时无法处理此格式的音频")))
//            return
//        }
        
        let url = "https://proapi.115.com/open/ufile/downurl"
        
        let parameters: Parameters = [
            "pick_code": file115.filePickCode()
        ]
                
        var headers: Alamofire.HTTPHeaders = HTTPHeaders.default
        headers.add(name: "Authorization", value: "Bearer \(drive115User.access_token)")
        
        debugPrint("下载header = \(headers)")
        
        AF.request(url, method: .post, parameters: parameters, headers: headers).responseData { response in
            switch response.result {
            case .success(let data):
                
                debugPrint("获取115生活下载地址 = \(String(data: data, encoding: .utf8) ?? "")")
                
                let responseString = String(data: data, encoding: .utf8) ?? ""
                guard let downloadModel = Response115DownloadModel.deserialize(from: responseString) else {
                    completion(.failure(KakaError.custom(responseString)))
                    return
                }
                
                guard let downloadURL = downloadModel.downloadURL(), downloadModel.state else {
                    if downloadModel.isRefreshToken() {
                        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.12) {
                            // 继续刷新token
                            self.refresh115AaccessToken(configModel: ServerConfigModel(serverType: .from115Drive, drive115User: drive115User)) { [weak self] result in
                                switch result {
                                case .success(let newServer):
                                    // 刷新token，继续获取文件下载地址
                                    var newFile = file115
                                    newFile.drive115User = newServer.drive115User
                                    self?.fetch115DownloadPlayURL(file115: newFile, completion: completion)
                                    break
                                case .failure(let failure):
                                    completion(.failure(failure))
                                    break
                                }
                            }
                        }
                    }else if downloadModel.isNeedReAuth115() {
                        // 需要重新授权
                        completion(.failure(.tokenExpiredAuthAgain))
                    }else{
                        let message = (downloadModel.message ?? "") + " " + "\((downloadModel.code ?? -1))"
                        completion(.failure(KakaError.custom(message)))
                    }
                    return
                }
                
                completion(.success(downloadURL))
                
                break
            case .failure(let error):
                completion(.failure(KakaError.custom(error.errorDescription ?? error.localizedDescription)))
                break
            }
        }
    }
    
    
}

/*
/// 获取115生活在线播放地址   暂时不支持音频在线播放
func fetch115OnlinePlayURL(file115: Drive115FileModel, completion: @escaping (Result<URL, Error>) -> Void) {
    
    guard let access_token = file115.drive115User?.access_token else {
        completion(.failure(NSError(domain: "Access token is empty", code: -1)))
        return
    }
    
    let url = "https://proapi.115.com/open/video/play"
    
    let parameters: Parameters = [
        "pick_code": file115.filePickCode()
    ]
    
    // 百度要求的 User-Agent 和 Host
    let headers: HTTPHeaders = [
        "Authorization": "Bearer \(access_token)"
    ]
    
    AF.request(url, method: .get, parameters: parameters, headers: headers).responseString { response in
        switch response.result {
        case .success(let responseString):
            debugPrint("获取115生活在线播放地址 = \(responseString)")
        case .failure(let error):
            completion(.failure(NSError(domain: error.errorDescription ?? error.localizedDescription, code: -1)))
        }
    }
}
 */
// MARK:  谷歌网盘
extension KakaMusicPlayer {
    
    /// 获取谷歌网盘下的文件列表
    public func fetchGoogleDriveFiles(serverModel: ServerConfigModel?, pageToken: String? = nil, limit: Int = 1000, completion: @escaping (Result<(files: [GoogleDriveFileModel], nextPageToken: String?), KakaError>) -> Void) {
        let url = "https://www.googleapis.com/drive/v3/files"
        let accessToken = serverModel?.googleUser?.accessToken ?? ""
        let folderId = serverModel?.googleUser?.folderId ?? "root"
                
        var parameters: [String: Any] = [
            "pageSize": limit,
            "orderBy": "folder,name,modifiedTime desc",
            "fields": "nextPageToken, files(id, name, mimeType, size, kind, createdTime, modifiedTime, webContentLink, parents)",
            "q": "'\(folderId)' in parents and (mimeType contains 'audio/' or mimeType = 'application/vnd.google-apps.folder')",
        ]
        
        debugPrint("谷歌查询参数 = \(parameters)")
        
        // 若有上一页 token
        if let pageToken = pageToken, !pageToken.isEmpty {
            parameters["pageToken"] = pageToken
        }
        
        let headers: Alamofire.HTTPHeaders = [
            "Authorization": "Bearer \(accessToken)",
            "Accept": "application/json"
        ]
        
        AF.request(url, method: .get, parameters: parameters, headers: headers).responseData { response in
            switch response.result {
            case .success(let data):
                
                let responseString = String(data: data, encoding: .utf8) ?? ""
                let jsonObject = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
                debugPrint("谷歌文件列表 = \(responseString)")
                
                guard let fileJsons = jsonObject?["files"] as? [[String: Any]], let fileArray = [GoogleDriveFileModel].deserialize(from: fileJsons) else {
                    // 检查是否 token 失效
                    if let errorModel = GoogleErrorResponse.deserialize(from: jsonObject), errorModel.error != nil {
                        completion(.failure(.tokenExpiredAuthAgain))
                    } else {
                        completion(.failure(.custom(responseString)))
                    }
                    
                    return
                }
                            
                let nextPageToken = jsonObject?["nextPageToken"] as? String
                completion(.success((files: fileArray, nextPageToken: nextPageToken)))
                
                break
            case .failure(let error):
                completion(.failure(KakaError.custom(error.localizedDescription)))
                break
            }
        }
    }
    
    // 处理Google网盘的播放，自动刷新token
    @MainActor func handleGoogleStreaming(_ model: MusicItemModel) {
        guard let googleFile = model.googleFile, let googleUser = googleFile.googleUser else {
            debugPrint("暂无token信息")
            self.playbackStatus = .error
            return
        }
        
        // 是否需要刷新
        if googleUser.isRefreshToken() {
            
            guard let currentUser = GIDSignIn.sharedInstance.currentUser, currentUser.userID == googleUser.userID else {
                self.playbackStatus = .error
                return
            }

            // 复制需要的值，避免捕获 non-Sendable
            let originalModel = model
            let originalGoogleUser = googleUser

            currentUser.refreshTokensIfNeeded { user, error in
                guard let user = user, error == nil else {
                    KakaMusicPlayer.shared.playbackStatus = .error
                    return
                }

                Task { @MainActor in
                    var updatedUser = originalGoogleUser
                    updatedUser.accessToken = user.accessToken.tokenString
                    updatedUser.expiresTime = user.accessToken.expirationDate?.timeIntervalSince1970 ?? 0
                    updatedUser.refreshToken = user.refreshToken.tokenString

                    let googleServer = ServerConfigModel(serverType: .fromGoogleDrive, googleUser: updatedUser)
                    ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: googleServer)

                    let newPlaylist = KakaMusicPlayer.shared.musicArray.map { item in
                        var newItem = item
                        if var _ = item.googleFile {
                            newItem.googleFile?.googleUser = updatedUser
                        }
                        return newItem
                    }

                    KakaMusicPlayer.shared.musicArray = newPlaylist

                    var newModel = originalModel
                    newModel.googleFile?.googleUser = updatedUser

                    KakaMusicPlayer.shared.playerView.set(url: newModel.mediaPlayURL, options: KakaMusicPlayer.shared.audioOption(newModel))
                    KakaMusicPlayer.shared.continueToPlay(newModel)
                }
            }

        } else {
            if let temp = self.playingMusic {
                self.playerView.set(url: googleFile.mediaPlayURL(), options: self.audioOption(temp))
            }
            self.continueToPlay(model)
        }
    }

    
    /// 获取谷歌网盘音视频的下载地址
    func fetchGoogleDownloadPlayURL(googleFile: GoogleDriveFileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        
        guard let googleUser = googleFile.googleUser else {
            completion(.failure(KakaError.custom("Access token is empty")))
            return
        }
        
        let url = "https://www.googleapis.com/drive/v3/files/\(googleFile.id)/download"
                
        let headers: Alamofire.HTTPHeaders = [
            "Authorization": "Bearer \(googleUser.accessToken)",
            "Content-Type": "application/json"
        ]
                
        AF.request(url, method: .post, parameters: Parameters.init(), headers: headers).responseData { response in
            switch response.result {
            case .success(let data):
                
                let responseString = String(data: data, encoding: .utf8) ?? ""
                debugPrint("获取谷歌网盘下载地址 = \(responseString)")
                
                guard let model = GoogleDriveFileModel.deserialize(from: responseString), let downloadURL = URL(string: model.webContentLink) else {
                    completion(.failure(KakaError.custom(responseString)))
                    return
                }
                
                completion(.success(downloadURL))
                                
                break
            case .failure(let error):
                completion(.failure(KakaError.custom(error.errorDescription ?? error.localizedDescription)))
                break
            }
        }
    }
    
    
}

/*
 "谷歌文件列表 = {\n  \"error\": {\n    \"code\": 401,\n    \"message\": \"Request had invalid authentication credentials. Expected OAuth 2 access token, login cookie or other valid authentication credential. See https://developers.google.com/identity/sign-in/web/devconsole-project.\",\n    \"errors\": [\n      {\n        \"message\": \"Invalid Credentials\",\n        \"domain\": \"global\",\n        \"reason\": \"authError\",\n        \"location\": \"Authorization\",\n        \"locationType\": \"header\"\n      }\n    ],\n    \"status\": \"UNAUTHENTICATED\"\n  }\n}\n"
 */

// MARK: Dropbox网盘
extension KakaMusicPlayer {
    /// 获取Dropbox网盘下的文件列表
    public func fetchDropboxFiles(serverModel: ServerConfigModel?, cursor: String? = nil, limit: UInt32 = 1000, completion: @escaping (Result<DropboxFilePage, KakaError>) -> Void) {
        
        guard let client = DropboxClientsManager.authorizedClient else {
            completion(.failure(.tokenExpiredAuthAgain))
            return
        }
        
        if let cursor = cursor, !cursor.isEmpty {
            // 加载分页
            client.files.listFolderContinue(cursor: cursor).response { response, error in
                if let result = response {
                    var fileArray = [DropboxDriveFileModel]()
                    
                    for index in 0..<result.entries.count {
                        let subFile = result.entries[index]
                        if let folderModel = subFile as? Files.FolderMetadata {
                            fileArray.append(folderModel.convertDropboxFolder())
                        }else if let fileModel = subFile as? Files.FileMetadata {
                            fileArray.append(fileModel.convertDropboxFile())
                        }else{
                            fileArray.append(subFile.convertDropboxBase())
                        }
                    }
                    
                    let pageModel = DropboxFilePage(entries: fileArray, cursor: result.cursor, hasMore: result.hasMore)
                    completion(.success(pageModel))
                    
                }else{
                    completion(.failure(KakaError.custom(error?.localizedDescription ?? KakaError.unknowError.errorDescription)))
                }
            }
        }else{
            // 首次加载
            client.files.listFolder(path: serverModel?.dropboxUser?.path ?? "", recursive: false, includeMediaInfo: true, includeDeleted: false, limit: limit, includeNonDownloadableFiles: true).response { response, error in
                if let result = response {
                    var fileArray = [DropboxDriveFileModel]()
                    
                    for index in 0..<result.entries.count {
                        let subFile = result.entries[index]
                        if let folderModel = subFile as? Files.FolderMetadata {
                            fileArray.append(folderModel.convertDropboxFolder())
                        }else if let fileModel = subFile as? Files.FileMetadata {
                            fileArray.append(fileModel.convertDropboxFile())
                        }else{
                            fileArray.append(subFile.convertDropboxBase())
                        }
                    }
                    
                    let pageModel = DropboxFilePage(entries: fileArray, cursor: result.cursor, hasMore: result.hasMore)
                    completion(.success(pageModel))
                    
                }else{
                    completion(.failure(KakaError.custom(error?.localizedDescription ?? KakaError.unknowError.errorDescription)))
                }
            }
        }
                 
    }
    
    // 处理Dropbox网盘的播放，自动刷新token
    @MainActor func handleDropboxStreaming(_ model: MusicItemModel) {
        
        guard let client = DropboxClientsManager.authorizedClient else {
            debugPrint("Dropbox授权失效了")
            self.playbackStatus = .error
            return
        }
        
        guard var dropboxFile = model.dropboxFile, let oldDropboxUser = dropboxFile.dropboxUser else {
            debugPrint("暂无Dropbox的token信息")
            self.playbackStatus = .error
            return
        }
        
        client.accessTokenProvider.refreshAccessTokenIfNecessary { refreshResult in
            switch refreshResult {
            case .success(let tokenModel):
                debugPrint("刷新了Dropbox的Token")
                
                var updatedUser = oldDropboxUser
                updatedUser.accessToken = tokenModel.accessToken
                updatedUser.expiresTime = tokenModel.tokenExpirationTimestamp ?? 0
                updatedUser.refreshToken = tokenModel.refreshToken

                let googleServer = ServerConfigModel(serverType: .fromDropboxDrive, dropboxUser: updatedUser)
                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: googleServer)

                let newPlaylist = KakaMusicPlayer.shared.musicArray.map { item in
                    var newItem = item
                    if var _ = item.googleFile {
                        newItem.dropboxFile?.dropboxUser = updatedUser
                    }
                    return newItem
                }

                KakaMusicPlayer.shared.musicArray = newPlaylist
                
                dropboxFile.dropboxUser = updatedUser
                self.playingMusic?.dropboxFile?.dropboxUser = updatedUser
                
                // 获取新的播放地址
                self.fetchDropboxDownloadPlayURL(dropboxFile: dropboxFile) { result in
                    switch result {
                    case .success(let downloadURL):
                        self.playingMusic?.mediaPlayURL = downloadURL
                        if let vModel = self.playingMusic {
                            self.playerView.set(url: downloadURL, options: self.audioOption(vModel))
                        }
                        
                        self.continueToPlay(model)
                        
                    case .failure(let failure):
                        self.playerView.resetPlayer()
                        self.playbackStatus = .error
                        self.currentViewController()?.showOneAlert(title: "Reminder".localStr(), message: failure.errorDescription)
                    }
                }
                break
            case .error(_, let description):
                debugPrint("刷新Dropbox的token错误:\(description ?? "")")
                self.playbackStatus = .error
                self.currentViewController()?.showOneAlert(title: "Reminder".localStr(), message: description ?? "")
                break
            case .cancel:
                debugPrint("刷新Dropbox的token已取消")
                self.playbackStatus = .error
                self.currentViewController()?.showOneAlert(title: "Reminder".localStr(), message: KakaError.youhaveCanceled.errorDescription)
                break
            case .none:
                debugPrint("不需要刷新Dropbox，直接播放")
                
                self.fetchDropboxDownloadPlayURL(dropboxFile: dropboxFile) { result in
                    switch result {
                    case .success(let downloadURL):
                        self.playingMusic?.mediaPlayURL = downloadURL
                        if let vModel = self.playingMusic {
                            self.playerView.set(url: downloadURL, options: self.audioOption(vModel))
                        }
                        
                        self.continueToPlay(model)
                        
                    case .failure(let failure):
                        self.playerView.resetPlayer()
                        self.playbackStatus = .error
                        self.currentViewController()?.showOneAlert(title: "Reminder".localStr(), message: failure.errorDescription)
                    }
                }
                break
            }
        }

    }
    
    // 获取Dropbox的音视频下载地址
    func fetchDropboxDownloadPlayURL(dropboxFile: DropboxDriveFileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        
        guard let client = DropboxClientsManager.authorizedClient else {
            completion(.failure(.tokenExpiredAuthAgain))
            return
        }
        
        client.files.getTemporaryLink(path: dropboxFile.path_display ?? "").response { result, error in
            guard let link = result?.link, let downloadURL = URL(string: link) else {
                completion(.failure(KakaError.custom(error?.localizedDescription ?? KakaError.unknowError.errorDescription)))
                return
            }
            
            debugPrint("获取Dropbox网盘下载地址 = \(downloadURL)")
            completion(.success(downloadURL))
        }
        
    }
    
}

// MARK: OneDrive网盘
extension KakaMusicPlayer {
    
    /// 获取OneDrive网盘下的文件列表
    public func fetchOneDriveFiles(serverModel: ServerConfigModel?, cursor: String? = nil, limit: Int = 1000, completion: @escaping (Result<OneDriveFilePage, KakaError>) -> Void) {
        
        let endpoint: String
        // 如果有 nextLink（分页游标），直接用它
        if let cursor = cursor, !cursor.isEmpty {
            endpoint = cursor
        } else if let path = serverModel?.onedriveUser?.path, !path.isEmpty {
            // 子目录
            endpoint = "https://graph.microsoft.com/v1.0/me/\(path):/children?$top=\(limit)"
        } else {
            // 根目录
            endpoint = "https://graph.microsoft.com/v1.0/me/drive/root/children?$top=\(limit)"
        }
        
        guard let url = URL(string: endpoint) else {
            return
        }
        
        let headers: Alamofire.HTTPHeaders = [
            "Authorization": "Bearer \(serverModel?.onedriveUser?.accessToken ?? "")",
            "Accept": "application/json"
        ]
                
        let parameters: Parameters = [:]
        
        AF.request(url, method: .get, parameters: parameters, headers: headers).responseData { response in
            switch response.result {
            case .success(let data):
                
                let responseString = String(data: data, encoding: .utf8) ?? ""
                debugPrint("OneDrive文件列表✅ = \(responseString)")
                guard let pageModel = OneDriveFilePage.deserialize(from: responseString) else {
                    completion(.failure(KakaError.custom(responseString)))
                    return
                }
                
                guard let _ = pageModel.value, pageModel.error == nil else {
                    if pageModel.isTokenExpired() {
                        self.refreshOnedriveTokenIfNeeded(onedriveUser: serverModel!.onedriveUser!) { result in
                            switch result {
                            case .success(let user):
                                let newServer = ServerConfigModel(serverType: .fromOneDrive, onedriveUser: user)
                                self.fetchOneDriveFiles(serverModel: newServer, cursor: cursor, limit: limit, completion: completion)
                                break
                            case .failure(let failure):
                                completion(.failure(failure))
                                break
                            }
                        }
                    }else{
                        completion(.failure(KakaError.custom(pageModel.error?.message ?? responseString)))
                    }
                    return
                }
                
                completion(.success(pageModel))
                                
                break
            case .failure(let error):
                debugPrint("OneDrive文件列表❌ = \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(KakaError.custom(error.localizedDescription)))
                }
                break
            }
        }
    }
    
    // 获取单个文件的下载地址
    func fetchOneDriveFileDetail(onedriveFile: OneDriveFileModel, completion: @escaping (Result<URL, KakaError>) -> Void) {
        
        guard let onedriveUser = onedriveFile.onedriveUser else {
            completion(.failure(.unknowError))
            return
        }
        
        self.refreshOnedriveTokenIfNeeded(onedriveUser: onedriveUser) { result in
            switch result {
            case .success(let refreshedUser):
                
                var newFile = onedriveFile
                newFile.onedriveUser = refreshedUser
                
                let fileId = newFile.id
                let accessToken = newFile.onedriveUser?.accessToken ?? ""
                
                let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/items/\(fileId)")!

                let headers: Alamofire.HTTPHeaders = [
                    "Authorization": "Bearer \(accessToken)",
                    "Accept": "application/json"
                ]

                AF.request(url, method: .get, headers: headers).responseData { response in
                    switch response.result {
                    case .success(let data):

                        let jsonStr = String(data: data, encoding: .utf8) ?? ""

                        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            completion(.failure(.custom(jsonStr)))
                            return
                        }

                        guard let url = json["@microsoft.graph.downloadUrl"] as? String, let playURL = URL(string: url) else {
                            completion(.failure(.unknowError))
                            return
                        }

                        completion(.success(playURL))

                    case .failure(let error):
                        completion(.failure(.custom(error.localizedDescription)))
                    }
                }
                break
            case .failure(let failure):
                completion(.failure(failure))
                break
            }
        }
        
    }

    
    /// 刷新 Token
    func refreshOnedriveTokenIfNeeded(onedriveUser: OneDriveUserModel, completion: @escaping (Result<OneDriveUserModel, KakaError>) -> Void) {
#if canImport(MSAL)
        do {
            let authority = try MSALAADAuthority(url: URL(string: OneDrive_Authority)!)
            let config = MSALPublicClientApplicationConfig(clientId: OneDrive_ClientID, redirectUri: OneDrive_RedirectUri, authority: authority)
            config.cacheConfig.keychainSharingGroup = AppBundleID
            let applicationContext = try MSALPublicClientApplication(configuration: config)
            
            let account = try applicationContext.account(forIdentifier: onedriveUser.account?.msalID ?? "")
            
            let parameters = MSALSilentTokenParameters(scopes: OneDrive_Scopes, account: account)
                    
            applicationContext.acquireTokenSilent(with: parameters) { (result, error) in
                
                guard let tokenResult = result else {
                    DispatchQueue.main.async {
                        completion(.failure(KakaError.tokenExpiredAuthAgain))
                    }
                    return
                }
                
                let onedriveUser = tokenResult.convertOneDriveUser()
                
                let serverModel = ServerConfigModel(serverType: .fromOneDrive, isSelected: true, onedriveUser: onedriveUser)
                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: serverModel) { () in
                    completion(.success(onedriveUser))
                }
            }
            
        } catch {
            debugPrint("静默刷新令牌失败 = \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(KakaError.tokenExpiredAuthAgain))
            }
        }
        #endif
    }
    
    // 处理OneDrive网盘的播放，自动刷新token
    @MainActor func handleOneDriveStreaming(_ model: MusicItemModel) {

        guard let onedriveFile = model.onedriveFile else {
            self.playbackStatus = .error
            return
        }
        
        // 获取下载地址
        self.fetchOneDriveFileDetail(onedriveFile: onedriveFile) { urlResult in
            
            switch urlResult {
            case .success(let playURL):
                
                debugPrint("旧的播放地址 = \(onedriveFile.mediaPlayURL().absoluteString)")
                debugPrint("新的播放地址 = \(playURL.absoluteString)")

                // 3. 播放
                self.playingMusic?.mediaPlayURL = playURL
                if let playingMusic = self.playingMusic {
                    self.playerView.set(url: playingMusic.mediaPlayURL, options: self.audioOption(playingMusic))
                    self.continueToPlay(playingMusic)
                }
                break
            case .failure(let error):
                self.playbackStatus = .error
                self.currentViewController()?.showOneAlert(
                    title: "Reminder".localStr(),
                    message: error.errorDescription
                )
                break
            }
        }
    }

    
}
