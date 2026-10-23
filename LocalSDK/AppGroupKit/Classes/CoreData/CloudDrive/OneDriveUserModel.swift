//
//  OneDriveUserModel.swift
//  AppGroupKit
//
//  Created by 张文 on 11/5/25.
//

import SmartCodable

public struct OneDriveUserModel: SmartCodableX, Equatable, Hashable {
    
    public init() { }
    
    public init(requestTime: TimeInterval, accessToken: String, expiresTime: TimeInterval, authHeader: String, authScheme: String, account: OnedriveAccount? = nil, path: String? = nil) {
        self.requestTime = requestTime
        self.accessToken = accessToken
        self.expiresTime = expiresTime
        self.authScheme = authScheme
        self.authHeader = authHeader
        self.account = account
        self.path = path
    }
    
    /// 保存token时的时间戳
    public var requestTime: TimeInterval = 0
    
    /// 令牌
    @SmartIgnored public var accessToken: String = ""
    
    /// token过期时间戳
    public var expiresTime: TimeInterval = 0
    
    /// 'pop' or 'Bearer xxxxxx'
    @SmartIgnored public var authHeader: String = ""
    
    /// 'pop' or 'Bearer'
    @SmartIgnored public var authScheme: String = ""
    
    /// 用户详细信息
    public var account: OnedriveAccount?
    
    /// 路径
    @SmartIgnored public var path: String?
    
    /// 方便查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(account?.msalID)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: OneDriveUserModel, rhs: OneDriveUserModel) -> Bool {
        return lhs.account?.msalID == rhs.account?.msalID
    }
    
    /// 文件夹名称
    public func pageTitle() -> String {
        if let path = self.path {
            return path.replaceChar(oldChar: "/drive/root:", newChar: "")
        }
        
        return "OneDrive".localStr()
    }
    
    /// 判断 token 是否过期
    public func isRefreshToken() -> Bool {
        // Legacy serialized token dates are absolute, not expires_in durations.
        return !expiresTime.isFinite || expiresTime <= Date().timeIntervalSince1970 + 60
    }
    
}

public struct OnedriveAccount: SmartCodableX {
    
    public init() { }
    
    public init(msalID: String, homeAccountId: String? = nil, username: String? = nil, nickName: String? = nil, environment: String, accountClaims: String) {
        self.msalID = msalID
        self.homeAccountId = homeAccountId
        self.username = username
        self.nickName = nickName
        self.environment = environment
        self.accountClaims = accountClaims
    }
    
    
    /// Stable local account key. The field name preserves older serialized accounts.
    public var msalID: String = ""

    /// Microsoft Graph /me.id for accounts authorized through the system OAuth flow.
    public var graphUserID: String?
    
    /// homeAccountId.identifier/
    public var homeAccountId: String?
    
    /// 登录名
    public var username: String?
    
    /// 昵称
    public var nickName: String?
    
    /// 登录环境/
    public var environment: String = ""
    
    /// 包含多个信息字段
    public var accountClaims: String = ""
    
}
