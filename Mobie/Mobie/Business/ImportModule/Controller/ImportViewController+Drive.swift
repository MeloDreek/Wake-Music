//
//  ImportViewController+Drive.swift
//  Mobie
//
//  Created by 张文 on 7/2/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import GoogleSignIn
import Alamofire
import SwiftyDropbox
import ProgressHUD
#if canImport(MSAL)
import MSAL
#endif

extension ImportViewController {
    
    // 连接新服务
    func connectNewServer(_ itemType: ImportFileType) {
        if itemType == .fromFile {
            self.importFromFiles()
            return
        }
        
        if itemType == .fromFolder {
            self.importFromFolder()
            return
        }
        
        if itemType == .fromVideos {
            self.importFromVideos()
            return
        }
        
        if itemType == .fromUSB {
            self.importFromUSB()
            return
        }
        
        if itemType == .fromWiFi {
            self.importFromWiFi()
            return
        }
        
        // Server forms remain browsable; their Connect actions enforce access.
        let formServices: [ImportFileType] = [.fromSMB, .fromFTP, .fromWebDAV, .fromNavidrome]
        let defersAccessCheck = formServices.contains(itemType)
        if !defersAccessCheck {
            guard requireRemoteConnectionAccess() else { return }
        }

        if itemType == .fromWebDAV {
            self.importfromWebDAV()
        }
        
        if itemType == .fromNavidrome {
            self.importFromNavidrome()
        }
        
        if itemType == .fromBaiduDrive {
            KakaCacheTools.clearWebViewCache(displayName: "baidu") { [weak self] () in
                self?.importFromBaiduDrive()
            }
        }
        
        if itemType == .fromAliyunDrive {
            self.importFromAliyunDrive()
        }
        
        if itemType == .from115Drive {
            KakaCacheTools.clearWebViewCache(displayName: "115") { [weak self] () in
                self?.importFrom115Drive()
            }
        }
        
        if itemType == .fromGoogleDrive {
            self.importFromGoogleDrive()
        }
        
        if itemType == .fromDropboxDrive {
            self.importFromDropBoxDrive()
        }
        
        if itemType == .fromSMB {
            self.connectSMB()
        }
        if itemType == .fromFTP {
            self.connectFTP()
        }

        if itemType == .fromMEGADrive {
            self.connectMEGADrive()
        }
        
        if itemType == .from123Drive {
            self.connectPan123Drive()
        }
        if itemType == .fromGuangyaDrive {
            self.connectGuangyaDrive()
        }
        
        if itemType == .fromBoxDrive {
            self.connectBoxDrive()
        }

        if itemType == .fromePCloud {
            self.connectPCloudDrive()
        }

        if itemType == .fromOneDrive {
            self.importFromOneDrive()
        }
        
        if itemType == .fromYandexDrive {
            self.connectYandexDrive()
        }
        
        if !itemType.isAvailble() {
            self.view.makeToast("Coming Soon".localStr())
        }
    }
    
    /// Navidrome
    func importFromNavidrome() {
        let navModel = NavidromeUserModel(id: "", customName: "My Navidrome".localStr(), hostUrl: "", isAdmin: false, subsonicSalt: "", subsonicToken: "", lastFMApiKey: "", token: "", isLargeServer: true, username: "", password: "")
        let webVC = AuthNavidromeController(navModel)
        self.navigationController?.pushViewController(webVC, animated: true)
    }
    
    /// Webdav
    func importfromWebDAV() {
        let webdavUser = WebdavUserModel(customName: "My WebDAV".localStr(), hostUrl: "", path: nil, port: nil, netProtocol: .http, username: nil, password: nil)
        let webVC = AuthWebdavViewController(webdavUser)
        self.navigationController?.pushViewController(webVC, animated: true)
    }
    
    /// 百度网盘
    func importFromBaiduDrive() {
        
        let baiduVC = AuthBaiduViewController { [weak self] serverModel in
            self?.finishRemoteAuthorization(serverModel)
        } onFailure: { [weak self] error in
            self?.showOneAlert(message: error.errorDescription)
        }

        let navVC = KakaNavigationController(rootViewController: baiduVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    // 阿里云盘
    func importFromAliyunDrive() {
        
        ProgressHUD.animate("Processing...".localStr())
        KakaMusicPlayer.shared.authorizedAliyunpan { result in
            ProgressHUD.dismiss()
            switch result {
            case .success(let aliyunUser):
                self.finishRemoteAuthorization(ServerConfigModel(serverType: .fromAliyunDrive, aliyunUser: aliyunUser))
                break
            case .failure(let failure):
                self.showOneAlert(message: failure.errorDescription)
                break
            }
        }
    }
    
    /// 115网盘
    func importFrom115Drive() {
        
        let drive115VC = Auth115LifeViewController { [weak self] model in
            self?.finishRemoteAuthorization(ServerConfigModel(serverType: .from115Drive, drive115User: model))
        }

        let navVC = KakaNavigationController(rootViewController: drive115VC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
        
    }
    
    /// 谷歌网盘
    func importFromGoogleDrive() {
        
        if ConnectConfigManager.shared.connectedModels.filter({ $0.serverType == .fromGoogleDrive }).count > 0 {
            self.showOneAlert(title: ImportFileType.fromGoogleDrive.titleStr(), message: "You can’t sign in to multiple accounts at the same time. Please remove the previously signed-in account.".localStr())
            return
        }
        
        ProgressHUD.animate()
        
        GIDSignIn.sharedInstance.signIn(withPresenting: self, hint: nil, additionalScopes: Google_Scopes) { result, error in
            
            ProgressHUD.dismiss()
            
            guard let result = result, error == nil else {
                let message = error?.localizedDescription ?? KakaError.unknowError.errorDescription
                self.showOneAlert(message: message)
                return
            }
            
            let googleUser = result.user.convertDriveUser()
            
            let serverModel = ServerConfigModel(serverType: .fromGoogleDrive, isSelected: true, googleUser: googleUser)
            ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: serverModel) { [weak self] () in
                self?.finishRemoteAuthorization(serverModel)
            }
        }
    }
    
    ///  DropBOX
    func importFromDropBoxDrive() {
        
        if ConnectConfigManager.shared.connectedModels.filter({ $0.serverType == .fromDropboxDrive }).count > 0 {
            self.showOneAlert(title: ImportFileType.fromDropboxDrive.titleStr(), message: "You can’t sign in to multiple accounts at the same time. Please remove the previously signed-in account.".localStr())
            return
        }
        
        let scopeRequest = ScopeRequest(scopeType: .user, scopes: DropBox_Scopes, includeGrantedScopes: false)
        isAwaitingDropboxAuthorization = true
        
        DropboxClientsManager.authorizeFromControllerV2(UIApplication.shared, controller: self, loadingStatusDelegate: nil, openURL: { url in
            UIApplication.shared.open(url)
        }, scopeRequest: scopeRequest)
    }
    
    ///  OneDrive
    func importFromOneDrive() {
        
#if canImport(MSAL)
        
        if ConnectConfigManager.shared.connectedModels.filter({ $0.serverType == .fromOneDrive }).count > 0 {
            self.showOneAlert(title: ImportFileType.fromOneDrive.titleStr(), message: "You can’t sign in to multiple accounts at the same time. Please remove the previously signed-in account.".localStr())
            return
        }
        
        do {
            let config = MSALPublicClientApplicationConfig(clientId: OneDrive_ClientID, redirectUri: OneDrive_RedirectUri, authority: try MSALAuthority(url: URL(string: OneDrive_Authority)!))
            config.cacheConfig.keychainSharingGroup = AppBundleID
            let applicationContext = try MSALPublicClientApplication(configuration: config)
            
            applicationContext.acquireToken(with: MSALInteractiveTokenParameters(scopes: OneDrive_Scopes, webviewParameters: MSALWebviewParameters(authPresentationViewController: self))) { result, error in
                guard let tokenResult = result else {
                    self.view.makeToast(error?.localizedDescription)
                    return
                }
                                                
                let onedriveUser = tokenResult.convertOneDriveUser()
                
                let serverModel = ServerConfigModel(serverType: .fromOneDrive, isSelected: true, onedriveUser: onedriveUser)
                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: serverModel) { [weak self] () in
                    self?.finishRemoteAuthorization(serverModel)
                }
                                
            }
            
        } catch {
            debugPrint("MSAL 初始化失败: \(error)")
            self.showOneAlert(message: error.localizedDescription)
        }
#endif
    }
    
}
