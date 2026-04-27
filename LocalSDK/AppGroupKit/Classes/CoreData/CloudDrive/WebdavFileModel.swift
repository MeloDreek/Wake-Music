//
//  WebdavFileModel.swift
//  AppGroupKit
//
//  Created by 张文 on 1/3/25.
//

import SmartCodable
import AppGroupKit

/// 远程WebDav文件模型
public struct WebdavFileModel: SmartCodableX, Equatable, Hashable {
    
    public init() {
        
    }
    
    public init(webdavUser: WebdavUserModel? = nil, fileName: String, filePath: String, mediaPlayURL: URL? = nil, fileSize: Int64, childrensCount: Int? = nil, fileExtension: String, isDirectory: Bool, creationDate: TimeInterval? = nil, modifiedDate: TimeInterval? = nil, isHidden: Bool, isReadOnly: Bool) {
        self.webdavUser = webdavUser
        self.fileName = fileName
        self.filePath = filePath
        self.mediaPlayURL = mediaPlayURL
        self.fileSize = fileSize
        self.childrensCount = childrensCount
        self.fileExtension = fileExtension
        self.isDirectory = isDirectory
        self.creationDate = creationDate
        self.modifiedDate = modifiedDate
        self.isHidden = isHidden
        self.isReadOnly = isReadOnly
    }
    
    /// 服务器信息
    public var webdavUser: WebdavUserModel?
    
    /// 文件名称，包含了扩展名
    public var fileName: String = ""
    
    /// 文件路径
    public var filePath: String = ""
    
    /// 文件路径
    public var mediaPlayURL: URL?
    
    /// 文件尺寸
    public var fileSize: Int64 = 0
    
    /// 子文件数量
    public var childrensCount: Int?
    
    /// 文件扩展名
    public var fileExtension: String = ""
    
    /// 是否为文件夹
    public var isDirectory: Bool = false
    
    /// 创建时间
    public var creationDate: TimeInterval?
    
    /// 修改时间
    public var modifiedDate: TimeInterval?
    
    /// 是否为隐藏文件
    public var isHidden: Bool = false
    
    /// 是否为只读
    public var isReadOnly: Bool = false
    
    /// 方便查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(webdavUser)
        hasher.combine(filePath)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: WebdavFileModel, rhs: WebdavFileModel) -> Bool {
        return lhs.webdavUser == rhs.webdavUser &&
                  lhs.filePath == rhs.filePath
    }
    
}

extension WebdavFileModel {
    /// 构造媒体URL
    private func webdavMediaPlayURL(_ originURL: URL?) -> URL? {
                
        guard let webdavUser = self.webdavUser else { return nil }
        
        if let fileURL = originURL {
            var commponents = URLComponents(url: fileURL, resolvingAgainstBaseURL: true)
            commponents?.user = webdavUser.username
            commponents?.password = webdavUser.password
            
            debugPrint("🔗媒体文件URL1 = \(commponents?.url)")
            
            return commponents?.url
        }else{
            // 设置协议
            let scheme = webdavUser.netProtocol.rawValue
            var baseURL = "\(scheme)://\(webdavUser.hostUrl)"
            
            // 如果有端口，添加端口信息
            if let port = webdavUser.port, port.count > 0 {
                baseURL.append(":" + port)
            }
            
            // 如果有用户名和密码，构造 URL 并进行编码
            if let username = webdavUser.username, let password = webdavUser.password {
                // 对用户名和密码进行 URL 编码
                let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? username
                let encodedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password
                
                baseURL = "\(scheme)://\(encodedUsername):\(encodedPassword)@\(webdavUser.hostUrl)"
            }
            
            // 如果有端口和路径，再将它们拼接
            if let port = webdavUser.port, port.count > 0 {
                baseURL.append(":" + port)
            }
            
            // 服务器路径
            if let path = webdavUser.path, path.count > 0 {
                baseURL.append(path.hasPrefix("/") ? path : ("/" + path))
            }
                        
            // 最后加上文件路径
            let newFilePath = self.filePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self.filePath
            baseURL.append(newFilePath)
            
            baseURL = baseURL.removingPercentEncoding ?? baseURL
            
            // 调试打印 URL
            debugPrint("🔗媒体文件URL2 = \(baseURL)")
            
            // 返回最终的 URL 对象
            return URL(string: baseURL)
        }
        
    }
     
    // 获取同名的LRC歌词路径
    public func getSameNameLRCFilePath() -> URL? {
        
        guard let mediaPlayURL = self.mediaPlayURL else { return nil }
        
        // 获取文件名并替换扩展名为 .lrc
        let lrcFileName = mediaPlayURL.deletingPathExtension().lastPathComponent + ".lrc"
        
        // 获取 LRC 文件的完整路径
        let lrcFilePath = mediaPlayURL.deletingLastPathComponent().appendingPathComponent(lrcFileName)
        
        return lrcFilePath
    }
    
}
