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
        if let user = smbUser { return user.title + " (" + user.host + ")" }
        if let user = ftpUser { return user.title + " (" + user.host + ")" }
        if let user = megaUser { return user.email.isEmpty ? "MEGA" : user.email }
        if let user = yandexUser { return user.login.isEmpty ? "Yandex Disk" : user.login }
        if let user = pan123User { return user.name.isEmpty ? "Pan123.Name".localStr() : user.name }
        if let user = guangyaUser { return user.name.isEmpty ? "Guangya.Name".localStr() : user.name }
        if let user = boxUser { return user.email.isEmpty ? "Box" : user.email }
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
        // Only display returned profile fields; never derive contact details from IDs/tokens.
        func details(_ values: String?...) -> String? {
            var parts: [String] = []
            for value in values {
                guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty,
                      !parts.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else { continue }
                parts.append(value)
            }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
        if let user = smbUser { return details(user.host, user.username) }
        if let user = ftpUser { return details(user.host, user.username) }
        if let user = megaUser { return details(user.name, user.email) ?? "MEGA" }
        if let user = yandexUser { return details(user.name, user.login) ?? "Yandex Disk" }
        if let user = pan123User { return details(user.name, user.email, user.phone) ?? "Pan123.Name".localStr() }
        if let user = guangyaUser { return user.name.isEmpty ? "Guangya.Name".localStr() : user.name }
        if let user = boxUser { return details(user.name, user.email) ?? "Box" }
        if let user = pcloudUser { return user.email.isEmpty ? user.apiHostName : user.email }
        
        if let webdavUser = self.webdavUser {
            return details(webdavUser.baseServerURL(false)?.absoluteString, webdavUser.username)
        }
        
        if let navUser = self.navUser {
            return details(navUser.hostUrl, navUser.username)
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
            return details(googleUser.nickName, googleUser.email)
        }
        
        if let dropboxUser = self.dropboxUser {
            return details(dropboxUser.account?.name, dropboxUser.account?.email) ?? dropboxUser.userID
        }
        
        if let onedriveUser = self.onedriveUser {
            return details(onedriveUser.account?.nickName, onedriveUser.account?.username) ?? onedriveUser.account?.msalID
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
