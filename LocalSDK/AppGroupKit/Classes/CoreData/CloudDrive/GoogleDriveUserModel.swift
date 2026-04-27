//
//  GoogleDriveUserModel.swift
//  AppGroupKit
//
//  Created by 张文 on 10/22/25.
//

import SmartCodable


/// 谷歌网盘的登录信息
public struct GoogleDriveUserModel: SmartCodableX, Sendable, Hashable, Equatable {
    
    public init(userID: String? = nil, nickName: String? = nil, avatarPic: String? = nil, email: String? = nil, requestTime: TimeInterval, accessToken: String, refreshToken: String, expiresTime: TimeInterval) {
        self.userID = userID
        self.nickName = nickName
        self.avatarPic = avatarPic
        self.email = email
        self.requestTime = requestTime
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresTime = expiresTime
    }
    
    public init() { }
    
    /// 用户ID
    public var userID: String?
    
    /// 谷歌昵称
    public var nickName: String?
    
    /// 头像地址
    public var avatarPic: String?
    
    /// 邮箱
    public var email: String?
    
    /// 保存token时的时间戳
    public var requestTime: TimeInterval = 0
    
    /// 令牌
    public var accessToken: String = ""
    
    /// 刷新令牌
    public var refreshToken: String = ""
    
    /// 过期时间戳
    public var expiresTime: TimeInterval = 0
    
    /// 父文件夹ID
    @SmartIgnored
    public var folderId: String = "root"
    
    /// 文件路径名称
    @SmartIgnored
    public var pathName: String = "Google Drive".localStr()
    
    /// 方便查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(userID)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: GoogleDriveUserModel, rhs: GoogleDriveUserModel) -> Bool {
        return lhs.userID == rhs.userID
    }
}

extension GoogleDriveUserModel {
    /// 访问子文件夹的标题
    public func pageTitle() -> String {
        return self.pathName
    }

    /// 是否为根目录
    public func isRootDic() -> Bool {
        return false
    }
    
    /// 判断 token 是否过期
    public func isRefreshToken() -> Bool {
        let expirationTime = /*self.requestTime + */self.expiresTime

        let expiresDate = Date(timeIntervalSince1970: expirationTime.rounded())
        let nowDate = Date()
        
        debugPrint("现在日期 = \(nowDate)，过期日期 = \(expiresDate)， requestTime = \(self.requestTime)，expires_in = \(self.expiresTime)")
        
        let comparisonResult = nowDate.compare(expiresDate)
        
        // 如果当前日期晚于过期日期，则 token 已过期
        return comparisonResult == .orderedDescending
    }
    
}
