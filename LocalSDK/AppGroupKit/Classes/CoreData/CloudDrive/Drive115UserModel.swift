//
//  Drive115UserModel.swift
//  AppGroupKit
//
//  Created by 张文 on 7/16/25.
//

import SmartCodable

/// 115网盘用户信息
public struct Drive115UserModel: SmartCodableX, Hashable, Equatable {
    
    public init(access_token: String, refresh_token: String, expires_in: Int, user_id: String, user_name: String, user_face_s: String, user_face_m: String, user_face_l: String, rt_space_info: Drive115SpaceInfo, vip_info: Drive115VipInfo) {
        self.access_token = access_token
        self.refresh_token = refresh_token
        self.expires_in = expires_in
        self.user_id = user_id
        self.user_name = user_name
        self.user_face_s = user_face_s
        self.user_face_m = user_face_m
        self.user_face_l = user_face_l
        self.rt_space_info = rt_space_info
        self.vip_info = vip_info
    }
    
    public init() {
        
    }
    
    /// 访问资源的token
    public var access_token: String = ""
    
    /// 刷新token的参数
    public var refresh_token: String = ""
    
    /// 有效期（秒）
    public var expires_in: Int = 0
    
    
    /// 用户ID
    public var user_id: String = ""
    
    /// 用户名
    public var user_name: String = ""
    
    /// 小尺寸用户头像
    public var user_face_s: String = ""
    
    /// 中尺寸用户头像
    public var user_face_m: String = ""
    
    /// 大尺寸用户头像
    public var user_face_l: String = ""
    
    /// 用户空间信息
    public var rt_space_info: Drive115SpaceInfo = .init()
    
    /// 用户vip等级信息
    public var vip_info: Drive115VipInfo = .init()
    
    
    /// 当前所在的目录文件(夹)ID
    public var cid: String?
    
    /// 访问子文件夹的标题
    public func pageTitle() -> String {
        return "115 Drive".localStr()
    }
    
    /// 是否根目录
    public func isRootDic() -> Bool {
        return self.cid == nil || self.cid == "0"
    }
    
    /// 提高查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(user_id)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: Drive115UserModel, rhs: Drive115UserModel) -> Bool {
        return lhs.user_id == rhs.user_id
    }
    
}


public struct Drive115SpaceInfo: SmartCodableX {
    
    public init(all_total: Drive115Space, all_remain: Drive115Space, all_use: Drive115Space) {
        self.all_total = all_total
        self.all_remain = all_remain
        self.all_use = all_use
    }
    
    public init() {
        
    }
    
    /// 用户总空间
    public var all_total: Drive115Space = .init()
    
    /// 用户剩余空间
    public var all_remain: Drive115Space = .init()
    
    /// 用户已使用空间
    public var all_use: Drive115Space = .init()
    
}

public struct Drive115Space: SmartCodableX {
    
    public init(size: Int, size_format: String) {
        self.size = size
        self.size_format = size_format
    }
    
    public init() {
        
    }
    
    /// 用户总空间大小(字节)
    public var size: Int = 0
    
    /// 用户总空间大小(格式化)
    public var size_format: String = ""
    
}

public struct Drive115VipInfo: SmartCodableX {
    
    public init(level_name: String, expire: TimeInterval) {
        self.level_name = level_name
        self.expire = expire
    }
    
    public init() {
        
    }
    
    /// vip等级名称；原石会员、尝鲜VIP、体验VIP、月费VIP、年费VIP、超级VIP、长期VIP
    public var level_name: String = ""
    
    /// 过期时间戳
    public var expire: TimeInterval = 0
}
