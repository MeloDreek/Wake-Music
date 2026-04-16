//
//  AliyunpanUserModel.swift
//  AppGroupKit
//
//  Created by 张文 on 4/10/26.
//

import SmartCodable

/// 阿里云盘的用户信息
public struct AliyunpanUserModel: SmartCodable, Hashable, Equatable {
    
    public init() { }
    
    public init(token_type: String, access_token: String, refresh_token: String? = nil, expires_in: TimeInterval, aliUser: AliyunpanUser? = nil, parentFolderID: String? = nil) {
        self.token_type = token_type
        self.access_token = access_token
        self.refresh_token = refresh_token
        self.expires_in = expires_in
        self.aliUser = aliUser
        self.parentFolderID = parentFolderID
    }
    
    /// Bearer
    public var token_type: String = ""
    
    /// 用来获取用户信息的access_token。刷新后，旧access_token不会立即失效
    public var access_token: String = ""
    
    /// 单次有效，用来刷新access_token，90天有效期。刷新后，返回新的refresh_token，请保存以便下一次刷新使用
    public var refresh_token: String?
    
    /// access_token的过期时间，单位秒
    public var expires_in: TimeInterval = 0
    
    /// 在云盘的信息
    public var aliUser: AliyunpanUser?
    
    /// 父文件夹ID
    public var parentFolderID: String?
    
    // 文件路径标题
    public var path: String?
    
    /// 提高查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(aliUser?.user_id)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: AliyunpanUserModel, rhs: AliyunpanUserModel) -> Bool {
        return lhs.aliUser?.user_id == rhs.aliUser?.user_id
    }
}


/// 阿里云的用户信息
public struct AliyunpanUser: SmartCodable {
    
    public init() { }
    
    public init(user_id: String, name: String, avatar: String, default_drive_id: String, resource_drive_id: String? = nil, backup_drive_id: String? = nil) {
        self.user_id = user_id
        self.name = name
        self.avatar = avatar
        self.default_drive_id = default_drive_id
        self.resource_drive_id = resource_drive_id
        self.backup_drive_id = backup_drive_id
    }
    
    /// 用户ID，具有唯一性
    public var user_id: String = ""
    /// 昵称
    public var name: String = ""
    /// 头像地址
    public var avatar: String = ""
    /// 默认drive
    public var default_drive_id: String = ""
    /// 资源库
    public var resource_drive_id: String?
    /// 备份盘
    public var backup_drive_id: String?
    
}


extension AliyunpanUserModel {
    /// 访问子文件夹的标题
    public func pageTitle() -> String {
        return self.path ?? "Aliyun Drive".localStr()
    }
    
    /// 是否为根目录
    public func isRootDic() -> Bool {
        return self.parentFolderID == "root" || self.parentFolderID == nil
    }
    
    /// 阿里云盘昵称
    public func aliyun_nickname() -> String {
        if let aliUser = self.aliUser {
            return aliUser.name
        }
        
        return "Aliyun Drive".localStr()
    }
    
    /// 是否已过期
    public func isExpired() -> Bool {
        return Date().timeIntervalSince1970 > self.expires_in
    }
    
}
