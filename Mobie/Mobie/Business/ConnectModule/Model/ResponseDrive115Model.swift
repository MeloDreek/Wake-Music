//
//  ResponseDrive115Model.swift
//  Mobie
//
//  Created by 张文 on 8/6/25.
//

import SmartCodable
import AppGroupKit

// MARK:  1️⃣文件列表接口
struct Response115FilesModel: SmartCodableX {
    
    /// 状态
    var state: Bool = false
    
    /// 状态码
    var code: Int?
    
    /// 提示语
    var message: String?
    
    /// 文件数组
    var data: [Drive115FileModel]?
    
    /// 父目录id
    var cid: String?
    
    /// 父目录树
    var path: [Drive115PathsModel]?
    
    /// 偏移量
    var offset: Int?
    
    /// 当前目录文件数量
    var count: Int?
    
    // 需要重新授权115
    func isNeedReAuth115() -> Bool {
        return  self.code == 40140116 || self.code == 40140119 || self.code == 40140126
        // 40140116：refresh_token 无效（已解除授权）。重新授权
        // 40140119：refresh_token 已过期。重新授权
        // 40140126: access_token 校验失败（防篡改）
    }
    
    /// 需要刷新Token
    func isRefreshToken() -> Bool {
        return self.code == 40140120 || self.code == 40140121 || self.code == 40140125
        // 40140120：refresh_token 检验失败（防篡改）.调用 /open/refreshToken 后，refresh_token 本身也会重新生成，检查本地是否有更新 refresh_token 的值
        // 40140121：access_token 刷新失败，重试
        // 40140125：access_token 无效（已过期或者已解除授权）。调用 /open/refreshToken 刷新 token
    }
    
}

// MARK:  2️⃣刷新token的接口
/// 刷新115网盘Token的返回数据
struct Response115RefreshModel: SmartCodableX {
    /// 状态
    var state: Bool = false
    
    /// 状态码
    var code: Int?
    
    /// 提示语
    var message: String?
    
    /// 刷新后的信息
    var data: Drive115UserModel?
    
    // 需要重新授权115
    func isNeedReAuth115() -> Bool {
        return  self.code == 40140116 || self.code == 40140119 || self.code == 40140126
        // 40140116：refresh_token 无效（已解除授权）。重新授权
        // 40140119：refresh_token 已过期。重新授权
        // 40140126: access_token 校验失败（防篡改）
    }
    
    /// 需要刷新Token
    func isRefreshToken() -> Bool {
        return self.code == 40140120 || self.code == 40140121 || self.code == 40140125
        // 40140120：refresh_token 检验失败（防篡改）.调用 /open/refreshToken 后，refresh_token 本身也会重新生成，检查本地是否有更新 refresh_token 的值
        // 40140121：access_token 刷新失败，重试
        // 40140125：access_token 无效（已过期或者已解除授权）。调用 /open/refreshToken 刷新 token
    }
}

// MARK:  3️⃣下载接口
/// 获取115文件下载地址
struct Response115DownloadModel: SmartCodableX {
    
    /// 状态
    var state: Bool = false
    
    /// 状态码
    var code: Int?
    
    /// 提示语
    var message: String?
    
    /// 文件信息
    var data: [String: Download115FileInfo]?
    
    // 需要重新授权115
    func isNeedReAuth115() -> Bool {
        return  self.code == 40140116 || self.code == 40140119 || self.code == 40140126
        // 40140116：refresh_token 无效（已解除授权）。重新授权
        // 40140119：refresh_token 已过期。重新授权
        // 40140126: access_token 校验失败（防篡改）
    }
    
    /// 需要刷新Token
    func isRefreshToken() -> Bool {
        return self.code == 40140120 || self.code == 40140121 || self.code == 40140125
        // 40140120：refresh_token 检验失败（防篡改）.调用 /open/refreshToken 后，refresh_token 本身也会重新生成，检查本地是否有更新 refresh_token 的值
        // 40140121：access_token 刷新失败，重试
        // 40140125：access_token 无效（已过期或者已解除授权）。调用 /open/refreshToken 刷新 token
    }
    
    func downloadURL() -> URL? {
        // 检查是否有文件数据
        guard let fileInfo = self.data?.values.first,
              let fileURLString = fileInfo.url?.url,
              let fileURL = URL(string: fileURLString) else {
            return nil
        }
        
        return fileURL
    }
    
}

struct Download115FileInfo: SmartCodableX {
    var fileName: String = ""
    var fileSize: Int = 0
    var pickCode: String = ""
    var sha1: String = ""
    var url: File115URLInfo?
}

struct File115URLInfo: SmartCodableX {
    var url: String = ""
}
