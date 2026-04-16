//
//  WebdavUserModel.swift
//  AppGroupKit
//
//  Created by 张文 on 7/18/25.
//

import SmartCodable

/// 网络协议
public enum NetworkProtocol: String, SmartCaseDefaultable {
    case http = "http"
    case https = "https"
    
    case smb = "smb"
    
    case nfs = "nfs"
    
    case ftp = "ftp"
    case ftps = "ftps"
    case ftpes = "ftpes"
    case sftp = "sftp"
}

/// Webdav登录信息
public struct WebdavUserModel: SmartCodable, Equatable, Hashable {
    
    public init(customName: String, hostUrl: String, path: String? = nil, port: String? = nil, netProtocol: NetworkProtocol, username: String? = nil, password: String? = nil) {
        self.customName = customName
        self.hostUrl = hostUrl
        self.path = path
        self.port = port
        self.netProtocol = netProtocol
        self.username = username
        self.password = password
    }
    
    public init() {
        
    }
    
    /// 自定义名称
    public var customName: String = ""
    
    /// IP地址
    public var hostUrl: String = ""
    
    /// 路径
    public var path: String?
    
    /// 端口
    public var port: String?
    
    /// 网络协议
    public var netProtocol: NetworkProtocol = .http
    
    /// 用户名
    public var username: String?
    
    /// 密码
    public var password: String?
    
    /// 提高查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(hostUrl)
        hasher.combine(username)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: WebdavUserModel, rhs: WebdavUserModel) -> Bool {
        return lhs.hostUrl == rhs.hostUrl &&
               lhs.username == rhs.username
    }
    
}

extension WebdavUserModel {
    
    /// 是否为根目录
    public func isRootDic() -> Bool {
        return self.path == nil || self.path == "/"
    }
    
    /// 外显名称
    public func showTitle() -> String {
        return self.customName ?? "My WebDav".localStr()
    }
    /// 访问子文件夹的标题
    public func pageTitle() -> String {
        guard let path = self.path, path.count > 1 else {
            return self.customName
        }
        
        return path
    }
    
    /// 构造WevDav服务器URL
    public func baseServerURL(_ isShowPass: Bool = false) -> URL? {

        // 创建一个基础 URL
        var baseURLString = "\(self.netProtocol.rawValue)://\(self.hostUrl)"
        if self.hostUrl.hasPrefix("http") {
            baseURLString = self.hostUrl
        }

        // 使用基础 URL 初始化 URLComponents
        var components: URLComponents?
        if #available(iOS 17.0, *) {
            components = URLComponents(string: baseURLString, encodingInvalidCharacters: true)
        } else {
            components = URLComponents(string: baseURLString)
        }
        
        if isShowPass {
            if let user = self.username, user.removeSpace().count > 0 {
                components?.user = user
            }
            
            if let password = self.password, password.removeSpace().count > 0 {
                components?.password = password
            }
        }
        
        if let port = self.port, !port.isEmpty {
            components?.port = Int(port)
        }
        
        // 输出调试信息
        debugPrint("WebDav🔗 = \(components?.url?.absoluteString ?? "")")
        
        // 返回构造的 URL
        return components?.url
        
    }
    
}
