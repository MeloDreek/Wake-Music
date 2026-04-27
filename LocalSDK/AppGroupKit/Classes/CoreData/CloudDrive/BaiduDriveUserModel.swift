//
//  BaiduDriveUserModel.swift
//  AppGroupKit
//
//  Created by 张文 on 7/3/25.
//

import SmartCodable

/// 百度网盘的用户信息
public struct BaiduDriveUserModel: SmartCodableX, Equatable, Hashable {
    
    public init(uk: Int, access_token: String, expires_in: Int, requestTime: TimeInterval, scope: String, baidu_name: String, netdisk_name: String? = nil, avatar_url: String, vip_type: Int, errmsg: String? = nil, path: String? = nil) {
        self.uk = uk
        self.access_token = access_token
        self.expires_in = expires_in
        self.requestTime = requestTime
        self.scope = scope
        self.baidu_name = baidu_name
        self.netdisk_name = netdisk_name
        self.avatar_url = avatar_url
        self.vip_type = vip_type
        self.errmsg = errmsg
        self.path = path
    }
    
    public init() {
        
    }
    
    /// 用户ID
    public var uk: Int = 0
    
    /// 百度网盘Token
    public var access_token: String = ""
    
    /// 过期时间，秒数
    public var expires_in: Int = 0
    
    /// 保存token时的时间戳
    public var requestTime: TimeInterval = 0
    
    /// 能力
    public var scope: String = ""
    
    /// 百度账号
    public var baidu_name: String = ""
    
    /// 网盘账号，通常为nil
    public var netdisk_name: String?
    
    /// 头像地址
    public var avatar_url: String = ""
    
    /// 会员类型。旧含义0普通用户、1普通会员、2超级会员。指定vip_version字段为v2时，0普通用户、1会员VIP用户、2超级会员SVIP用户
    public var vip_type: Int = 0
    
    /// 错误信息
    public var errmsg: String?
    
    /// 文件夹路径
    public var path: String?
    
    
    /// 方便查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uk)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: BaiduDriveUserModel, rhs: BaiduDriveUserModel) -> Bool {
        return lhs.uk == rhs.uk
    }
    
}

extension BaiduDriveUserModel {
    /// 访问子文件夹的标题
    public func pageTitle() -> String {
        guard let path = self.path, path.count > 1 else {
            return "Baidu Drive".localStr()
        }
        
        return path
    }
    
    /// 百度会员
    public func isPremium() -> Bool {
        return self.vip_type == 1 || self.vip_type == 2
    }
    
    /// 是否为根目录
    public func isRootDic() -> Bool {
        return self.path == nil || self.path == "/"
    }
    
    /// 百度网盘昵称
    public func baidu_nickname() -> String {
        if let netdisk_name = self.netdisk_name, netdisk_name.count > 0 {
            return netdisk_name
        }
        
        return self.baidu_name
    }
    
    /// 判断 token 是否过期
    public func isRefreshToken() -> Bool {
        let expirationTime = self.requestTime + TimeInterval(expires_in)

        let expiresDate = Date(timeIntervalSince1970: expirationTime.rounded())
        debugPrint("过期日期 = \(expiresDate)， requestTime = \(self.requestTime)，expires_in = \(self.expires_in)")
        let nowDate = Date()
        
        let comparisonResult = nowDate.compare(expiresDate)
        
        // 如果当前日期晚于过期日期，则 token 已过期
        return comparisonResult == .orderedDescending
    }
    
}
