//
//  DropboxDriveUserModel.swift
//  AppGroupKit
//
//  Created by 张文 on 10/27/25.
//

import SmartCodable

/// Dropbox的登录信息
public struct DropboxDriveUserModel: SmartCodable, Hashable, Equatable {
    
    public init() { }
    
    public init(userID: String? = nil, requestTime: TimeInterval, accessToken: String, refreshToken: String? = nil, expiresTime: TimeInterval, account: DropboxAccount? = nil, path: String? = nil) {
        self.userID = userID
        self.requestTime = requestTime
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresTime = expiresTime
        self.account = account
        self.path = path
    }
    
    /// 用户ID
    public var userID: String?
    
    /// 保存token时的时间戳
    public var requestTime: TimeInterval = 0
    
    /// 令牌
    public var accessToken: String = ""
    
    /// 刷新令牌
    public var refreshToken: String?
    
    /// token过期时间戳
    public var expiresTime: TimeInterval = 0
    
    /// 用户详细信息
    public var account: DropboxAccount?
    
    /// 路径
    @SmartIgnored public var path: String?
    
    /// 方便查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(userID)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: DropboxDriveUserModel, rhs: DropboxDriveUserModel) -> Bool {
        return lhs.userID == rhs.userID
    }
}

extension DropboxDriveUserModel {
    /// 访问子文件夹的标题
    public func pageTitle() -> String {
        return self.path ?? "Dropbox".localStr()
    }
    
    /// 判断 token 是否过期
    public func isRefreshToken() -> Bool {
        let expirationTime = self.requestTime + self.expiresTime

        let expiresDate = Date(timeIntervalSince1970: expirationTime.rounded())
        let nowDate = Date()
        debugPrint("现在日期 = \(nowDate)，过期日期 = \(expiresDate)， requestTime = \(self.requestTime)，expires_in = \(self.expiresTime)")
        
        let comparisonResult = nowDate.compare(expiresDate)
        
        // 如果当前日期晚于过期日期，则 token 已过期
        return comparisonResult == .orderedDescending
    }
    
}

public struct DropboxAccount: SmartCodable {
    
    public init() { }
    
    public init(accountId: String, name: String, email: String, emailVerified: Bool, profilePhotoUrl: String? = nil, disabled: Bool) {
        self.accountId = accountId
        self.name = name
        self.email = email
        self.emailVerified = emailVerified
        self.profilePhotoUrl = profilePhotoUrl
        self.disabled = disabled
    }
    
    /// The user's unique Dropbox ID.
    public var accountId: String = ""
    
    /// Details of a user's name.
    public var name: String = ""
    
    /// The user's email address. Do not rely on this without checking the emailVerified field. Even then, it's
    /// possible that the user has since lost access to their email.
    public var email: String = ""
    
    /// Whether the user has verified their email address.
    public var emailVerified: Bool = false
    
    /// URL for the photo representing the user, if one is set.
    public var profilePhotoUrl: String?
    
    /// Whether the user has been disabled.
    public var disabled: Bool = false
    
}
