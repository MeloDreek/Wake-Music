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
    public var accessToken: String = ""
    
    /// token过期时间戳
    public var expiresTime: TimeInterval = 0
    
    /// 'pop' or 'Bearer xxxxxx'
    public var authHeader: String = ""
    
    /// 'pop' or 'Bearer'
    public var authScheme: String = ""
    
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
        let expirationTime = self.requestTime + self.expiresTime

        let expiresDate = Date(timeIntervalSince1970: expirationTime.rounded())
        let nowDate = Date()
        debugPrint("现在日期 = \(nowDate)，过期日期 = \(expiresDate)， requestTime = \(self.requestTime)，expires_in = \(self.expiresTime)")

        
        let comparisonResult = nowDate.compare(expiresDate)
        
        // 如果当前日期晚于过期日期，则 token 已过期
        return comparisonResult == .orderedDescending
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
    
    
    /// MSAL ID
    public var msalID: String = ""
    
    /// homeAccountId.identifier/
    public var homeAccountId: String?
    
    /// 登录名（如 melodreek@gmail.com
    public var username: String?
    
    /// 昵称
    public var nickName: String?
    
    /// 登录环境/
    public var environment: String = ""
    
    /// 包含多个信息字段
    public var accountClaims: String = ""
    
}

/*
po accountClaims.description
["ver": 2.0, "kid": bWyeFXBZxjqpLQuEDIXWySSIcyg, "aio": Djhrb!*mFtEbV9fOF5JXqVAm7!d*ci5rr7CffN7vJl1FcfNiAPFFEvOaMYgKy80DAQDJqY0J4xJMmgAlAwloTr74Dc2LHVCrllasjEUe8DBnlU8OL3nlqvKKbc0!N0wo1eEnkTUGyya1bUGRZ!4JYR5YnC0yQKT6yhL*WOw0kcR2, "iat": 1762337675, "name": Melo Dreek, "exp": 1762424375, "typ": JWT, "sub": AAAAAAAAAAAAAAAAAAAAAJRDnO9embsDSr35VpgyiQE, "nbf": 1762337675, "iss": https://login.microsoftonline.com/9188040d-6c67-4c5b-b112-36a304b66dad/v2.0, "alg": RS256, "tid": 9188040d-6c67-4c5b-b112-36a304b66dad, "oid": 00000000-0000-0000-b3db-63ec4e5b22a9, "preferred_username": melodreek@gmail.com, "aud": e4941369-cd73-4f3c-8e48-c1404e373719]
*/
