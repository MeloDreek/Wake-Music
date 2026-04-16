//
//  ConnectListViewController+Connect.swift
//  Mobie
//
//  Created by 张文 on 10/23/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import GoogleSignIn
import Alamofire
import SwiftyDropbox
import ProgressHUD
import AliyunpanSDK
//import PCloudSDKSwift
#if canImport(MSAL)
import MSAL
#endif

extension ConnectListViewController {
    
    // 连接新服务器
    func connectNewServer(_ itemType: ImportFileType) {
        
        guard UserInfoManager.shared.isVIP() else {
            self.vipCenterClick()
            return
        }
        
        if itemType == .fromWebDav {
            self.importFromWebdav()
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
        
        if itemType == .fromePCloud {
            self.importFrompCloudDrive()
        }
        
        if itemType == .fromOneDrive {
            self.importFromOneDrive()
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
    func importFromWebdav() {
        let webdavUser = WebdavUserModel(customName: "My WebDav".localStr(), hostUrl: "", path: nil, port: nil, netProtocol: .http, username: nil, password: nil)
        let webVC = AuthWebdavViewController(webdavUser)
        self.navigationController?.pushViewController(webVC, animated: true)
    }
    
    /// 百度网盘
    func importFromBaiduDrive() {
        
        let baiduVC = AuthBaiduViewController { [weak self] serverModel in
            let fileVC = BaiduDriveFileListController(loginModel: serverModel.baiduUser!)
            self?.navigationController?.pushViewController(fileVC, animated: true)
        } onFailure: { [weak self] error in
            self?.showOneAlert(title: "Reminder".localStr(), message: error.errorDescription)
        }

        let navVC = KakaNavigationController(rootViewController: baiduVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    // 阿里云盘
    func importFromAliyunDrive() {
        
        ProgressHUD.animate("Please wait".localStr())
        
        KakaMusicPlayer.shared.authorizedAliyunpan { result in
            ProgressHUD.dismiss()
            switch result {
            case .success(let aliyunUser):
                self.refreshDataAction()
                let folderVC = AliyunDriveFileListController(loginModel: aliyunUser)
                self.navigationController?.pushViewController(folderVC, animated: true)
                break
            case .failure(let failure):
                self.showOneAlert(title: "Reminder".localStr(), message: failure.errorDescription)
                break
            }
        }
    }
    
    /// 115网盘
    func importFrom115Drive() {
        
        let drive115VC = Auth115LifeViewController { model in
            let fileVC = Drive115FileListController(loginModel: model)
            fileVC.title = ImportFileType.from115Drive.titleStr()
            self.navigationController?.pushViewController(fileVC, animated: true)
        }

        let navVC = KakaNavigationController(rootViewController: drive115VC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
        
    }
    
    /// 谷歌网盘
    func importFromGoogleDrive() {
        
        ProgressHUD.animate()
        
        GIDSignIn.sharedInstance.signIn(withPresenting: self, hint: nil, additionalScopes: Google_Scopes) { result, error in
            
            ProgressHUD.dismiss()
            
            guard let result = result, error == nil else {
                let message = error?.localizedDescription ?? KakaError.unknowError.errorDescription
                self.showOneAlert(title: "Reminder".localStr(), message: message)
                return
            }
            
            let googleUser = result.user.convertDriveUser()
            
            let serverModel = ServerConfigModel(serverType: .fromGoogleDrive, isSelected: true, googleUser: googleUser)
            ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: serverModel) { [weak self] () in
                let googleVC = GoogleDriveFileListController(loginModel: googleUser)
                self?.navigationController?.pushViewController(googleVC, animated: true)
            }
        }
    }
    
    ///  DropBOX
    func importFromDropBoxDrive() {
        let scopeRequest = ScopeRequest(scopeType: .user, scopes: DropBox_Scopes, includeGrantedScopes: false)
        
        DropboxClientsManager.authorizeFromControllerV2(UIApplication.shared, controller: self, loadingStatusDelegate: nil, openURL: { url in
            UIApplication.shared.open(url)
        }, scopeRequest: scopeRequest)
    }
    
    // pCloud
    func importFrompCloudDrive() {
//        PCloud.authorize(with: self) { result in
//            switch result {
//            case .success(let user):
//                print("授权成功，用户 ID: \(user.id)")
//                break
//            case .failure(let error):
//                self.showOneAlert(title: "Reminder".localStr(), message: error.rawValue)
//                break
//            case .cancel:
//                self.view.makeToast(KakaError.youhaveCanceled.errorDescription)
//                break
//            }
//        }
    }
    
    ///  OneDrive
    func importFromOneDrive() {
#if canImport(MSAL)
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
                    let googleVC = OneDriveFileListController(loginModel: onedriveUser)
                    self?.navigationController?.pushViewController(googleVC, animated: true)
                }
                                
            }
            
        } catch {
            debugPrint("MSAL 初始化失败: \(error)")
            self.showOneAlert(title: "Reminder".localStr(), message: error.localizedDescription)
        }
#endif
    }
    
}
