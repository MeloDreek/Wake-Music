//
//  ServerConfigModel.swift
//  AppGroupKit
//
//  Created by 张文 on 2/23/25.
//

import SmartCodable

/// 连接的服务器登录信息
public struct ServerConfigModel: SmartCodableX, Equatable, Hashable {
    
    public init() { }
    
    public init(serverType: ImportFileType = ImportFileType.fromWebDav, isSelected: Bool = false, webdavUser: WebdavUserModel? = nil, navUser: NavidromeUserModel? = nil, baiduUser: BaiduDriveUserModel? = nil, aliyunUser: AliyunpanUserModel? = nil, drive115User: Drive115UserModel? = nil, googleUser: GoogleDriveUserModel? = nil, dropboxUser: DropboxDriveUserModel? = nil, onedriveUser: OneDriveUserModel? = nil, pcloudUser: PCloudDriveUserModel? = nil) {
        self.serverType = serverType
        self.isSelected = isSelected
        self.webdavUser = webdavUser
        self.navUser = navUser
        self.baiduUser = baiduUser
        self.aliyunUser = aliyunUser
        self.drive115User = drive115User
        self.googleUser = googleUser
        self.dropboxUser = dropboxUser
        self.onedriveUser = onedriveUser
        self.pcloudUser = pcloudUser
    }
    
    /// 导入方式的信息
    public var serverType = ImportFileType.fromWebDav
    
    
    /// 当前选中的服务器
    public var isSelected: Bool = false
    
    /// Webdav登录信息
    public var webdavUser: WebdavUserModel?
    
    /// Nav用户信息
    public var navUser: NavidromeUserModel?
    
    /// 百度网盘信息
    public var baiduUser: BaiduDriveUserModel?
    
    /// 阿里云盘
    public var aliyunUser: AliyunpanUserModel?
    
    /// 115网盘信息
    public var drive115User: Drive115UserModel?
    
    /// 谷歌网盘信息
    public var googleUser: GoogleDriveUserModel?
    
    /// Dropbox
    public var dropboxUser: DropboxDriveUserModel?
    
    /// OneDrive
    public var onedriveUser: OneDriveUserModel?

    public var pcloudUser: PCloudDriveUserModel?
    
    /// 提高查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(serverType)
        hasher.combine(webdavUser)
        hasher.combine(navUser)
        hasher.combine(baiduUser)
        hasher.combine(aliyunUser)
        hasher.combine(drive115User)
        hasher.combine(googleUser)
        hasher.combine(dropboxUser)
        hasher.combine(onedriveUser)
        hasher.combine(pcloudUser)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: ServerConfigModel, rhs: ServerConfigModel) -> Bool {
        return lhs.serverType == rhs.serverType &&
        lhs.pcloudUser == rhs.pcloudUser &&
        lhs.webdavUser?.username ==  rhs.webdavUser?.username &&
        lhs.navUser?.id ==  rhs.navUser?.id &&
        lhs.baiduUser?.uk ==  rhs.baiduUser?.uk &&
        lhs.aliyunUser?.aliUser?.user_id ==  rhs.aliyunUser?.aliUser?.user_id &&
        lhs.drive115User?.user_id ==  rhs.drive115User?.user_id &&
        lhs.googleUser?.userID ==  rhs.googleUser?.userID &&
        lhs.dropboxUser?.userID ==  rhs.dropboxUser?.userID &&
        lhs.onedriveUser?.account?.msalID ==  rhs.onedriveUser?.account?.msalID
    }
    
}

extension ServerConfigModel {
    
    /// 外显名称
    public func showTitle() -> String {
        if pcloudUser != nil { return "pCloud" }
        if self.serverType == .fromWebDav {
            return self.webdavUser?.customName ?? "WebDAV".localStr()
        }else if serverType == .fromNavidrome {
            if let customName = self.navUser?.customName, !customName.isEmpty {
                return customName
            }
            
            return "My Navidrome".localStr()
        }else if serverType == .fromBaiduDrive {
            return "Baidu Drive".localStr()
        }else if serverType == .fromAliyunDrive {
            return "Aliyun Drive".localStr()
        }else if serverType == .from115Drive {
            return "115 Drive".localStr()
        }else if serverType == .fromGoogleDrive {
            return "Google Drive".localStr()
        }else if serverType == .fromDropboxDrive {
            return "Dropbox".localStr()
        }else if serverType == .fromOneDrive {
            return "OneDrive".localStr()
        }
        else{
            return serverType.rawValue
        }
    }
    
    /// 自定义的名称
    public func customNameStr() -> String? {
        if let user = pcloudUser { return user.email.isEmpty ? "pCloud" : user.email }
        if let webdavUser = self.webdavUser {
            return webdavUser.customName
        }
        
        if let navUser = self.navUser {
            return navUser.customName.isEmpty ? "Navidrome" : navUser.customName
        }
        
        if let baiduUser = self.baiduUser {
            return baiduUser.baidu_nickname()
        }
        
        if let drive115User = self.drive115User {
            return "115" + "_" + drive115User.user_name
        }
        
        if let googleUser = self.googleUser {
            return googleUser.nickName ?? "Google Drive".localStr()
        }
        
        if let dropboxUser = self.dropboxUser {
            return (dropboxUser.account?.email ?? dropboxUser.account?.name) ?? dropboxUser.userID
        }
        
        if let onedriveUser = self.onedriveUser {
            return (onedriveUser.account?.username ?? onedriveUser.account?.nickName) ?? onedriveUser.account?.msalID
        }
        
        return nil
    }
    
    /// 网络协议
    public func networkProtocol() -> NetworkProtocol? {
        if let webdavUser = self.webdavUser {
            return webdavUser.netProtocol
        }
        
        return nil
    }
    
    /// 主机地址
    public func hostURLStr() -> String? {
        if let webdavUser = self.webdavUser {
            return webdavUser.hostUrl
        }
        
        if let navUser = self.navUser {
            return navUser.hostUrl
        }
        
        if let baiduUser = self.baiduUser {
            return "\(baiduUser.uk ?? 0)"
        }
        
        if let drive115User = self.drive115User {
            return drive115User.user_id
        }
        
        return nil
    }
    
    /// 路径
    public func pathStr() -> String? {
        if let webdavUser = self.webdavUser {
            return webdavUser.path
        }
        
        if let baiduUser = self.baiduUser {
            return baiduUser.path
        }
        
        return nil
    }
    
    /// 端口
    public func portStr() -> String? {
        if let webdavUser = self.webdavUser {
            return webdavUser.port
        }
        
        return nil
    }
    
    /// 用户名
    public func usernameStr() -> String? {
        if let webdavUser = self.webdavUser {
            return webdavUser.username
        }
        
        if let navUser = self.navUser {
            return navUser.username
        }
        
        return nil
    }
    
    /// 密码
    public func passwordStr() -> String? {
        if let webdavUser = self.webdavUser {
            return webdavUser.password
        }
        
        if let navUser = self.navUser {
            return navUser.password
        }
        
        return nil
    }
    
}
