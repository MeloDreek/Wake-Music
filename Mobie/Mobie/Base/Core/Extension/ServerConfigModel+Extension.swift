//
//  ServerConfigModel+Extension.swift
//  Mobie
//
//  Created by 张文 on 3/11/25.
//

import AppGroupKit
import FilesProvider


extension ServerConfigModel {
    
    /// 访问子文件夹的标题
    public func pageTitle() -> String {
        if let user = pcloudUser { return user.email.isEmpty ? "pCloud" : user.email }
        
        if let webdavUser = self.webdavUser {
            return webdavUser.pageTitle()
        }
        
        if let baiduUser = self.baiduUser {
            return baiduUser.baidu_nickname()
        }
        
        if let drive115User = self.drive115User {
            return drive115User.user_name
        }
        
        if let googleUser = self.googleUser {
            return googleUser.nickName ?? self.serverType.titleStr()
        }
        
        if let dropboxUser = self.dropboxUser {
            return dropboxUser.account?.name ?? self.serverType.titleStr()
        }
        
        if let onedriveUser = self.onedriveUser {
            return onedriveUser.account?.username ?? self.serverType.titleStr()
        }
        
        return self.serverType.titleStr()
        
    }
    
    /// 副标题
    func descString() -> String? {
        if let user = pcloudUser { return user.email.isEmpty ? user.apiHostName : user.email }
        
        if let webdavUser = self.webdavUser {
            return webdavUser.baseServerURL(false)?.absoluteString
        }
        
        if let navUser = self.navUser {
            return navUser.hostUrl
        }
        
        if let baiduUser = self.baiduUser {
            return baiduUser.baidu_nickname()
        }
        
        if let aliyunUser = self.aliyunUser, let aliUser = aliyunUser.aliUser {
            return aliUser.name
        }
        
        if let drive115User = self.drive115User {
            return drive115User.user_name
        }
        
        if let googleUser = self.googleUser {
            return googleUser.email ?? googleUser.nickName
        }
        
        if let dropboxUser = self.dropboxUser {
            return (dropboxUser.account?.email ?? dropboxUser.account?.name) ?? dropboxUser.userID
        }
        
        if let onedriveUser = self.onedriveUser {
            return (onedriveUser.account?.username ?? onedriveUser.account?.nickName) ?? onedriveUser.account?.msalID
        }
        
        return nil
    }
    
}

extension WebdavUserModel {
    /// 构造WebDav文件对象
    public func webdavProvider() -> WebDAVFileProvider? {
        
        guard let baseURL = self.baseServerURL(true) else { return nil }
        
        var webdavProvider: WebDAVFileProvider?
        if let username = self.username, let password = self.password, username.count > 0, password.count > 0 {
            let credential = URLCredential(user: username, password: password, persistence: .permanent)
            webdavProvider = WebDAVFileProvider(baseURL: baseURL, credential: credential, cache: nil)
            webdavProvider?.credentialType = .digest
        }else{
            webdavProvider = WebDAVFileProvider(baseURL: baseURL, credential: nil, cache: nil)
            webdavProvider?.credentialType = .basic
        }
        
        return webdavProvider
    }
}
