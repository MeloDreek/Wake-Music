//
//  NavidromeUserModel.swift
//  AppGroupKit
//
//  Created by 张文 on 2/21/25.
//

import SmartCodable
import CryptoKit

// Navidrome用户模型
public struct NavidromeUserModel: SmartCodableX, Equatable, Hashable {
    
    public init() { }
    
    public init(id: String, customName: String, hostUrl: String, name: String = "", isAdmin: Bool, subsonicSalt: String, subsonicToken: String, lastFMApiKey: String, token: String, isLargeServer: Bool, username: String, password: String) {
        self.id = id
        self.customName = customName
        self.hostUrl = hostUrl
        self.name = name
        self.isAdmin = isAdmin
        self.subsonicSalt = subsonicSalt
        self.subsonicToken = subsonicToken
        self.lastFMApiKey = lastFMApiKey
        self.token = token
        self.isLargeServer = isLargeServer
        self.username = username
        self.password = password
    }
    
    /// ID
    public var id: String = ""
    
    /// 自定义名称
    public var customName: String = ""
    
    /// 网址
    public var hostUrl: String = ""
    
    /// 用户昵称
    public var name = ""
    
    /// 是否为管理员
    public var isAdmin: Bool = false
    
    /// sub盐
    public var subsonicSalt: String = ""
    
    /// subToken
    public var subsonicToken: String = ""
    
    /// LastFM的key
    public var lastFMApiKey: String = ""
    
    /// token
    public var token: String = ""
    
    /// 是否为大型服
    public var isLargeServer: Bool = false
    
    /// 用户名称
    public var username: String = ""
    
    /// 密码
    public var password: String = ""
    
    // 拼接Sub
    public func subsonicParams() -> String {
        var components = URLComponents()
        components.queryItems = subsonicQueryItems
        return "?" + (components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
    }

    private var subsonicQueryItems: [URLQueryItem] {
        [URLQueryItem(name: "u", value: username),
         URLQueryItem(name: "t", value: subsonicToken),
         URLQueryItem(name: "s", value: subsonicSalt),
         URLQueryItem(name: "v", value: "1.16.1"),
         URLQueryItem(name: "c", value: AppMeta.name),
         URLQueryItem(name: "f", value: "json")]
    }

    public func subsonicURL(endpoint: String, parameters: [URLQueryItem] = []) -> URL? {
        guard var components = URLComponents(string: hostUrl),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host != nil else { return nil }
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/").map(String.init).joined(separator: "/")
        components.path = "/" + ([components.path, endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))].filter { !$0.isEmpty }.joined(separator: "/"))
        components.user = nil
        components.password = nil
        components.fragment = nil
        components.queryItems = subsonicQueryItems + parameters
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }

    /// Opaque account namespace, independent of tokens and the server's local user ID.
    public var accountIdentity: String {
        var components = URLComponents(string: hostUrl.trimmingCharacters(in: .whitespacesAndNewlines))
        let scheme = components?.scheme?.lowercased()
        let host = components?.host?.lowercased()
        components?.scheme = scheme
        components?.host = host
        if (components?.scheme == "https" && components?.port == 443) || (components?.scheme == "http" && components?.port == 80) { components?.port = nil }
        components?.query = nil
        components?.fragment = nil
        components?.user = nil
        components?.password = nil
        let path = components?.path ?? ""
        components?.path = path == "/" ? "" : path.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        let value = (components?.string ?? hostUrl) + "\u{0}" + username
        return SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(hostUrl)
    }
    
    public static func == (lhs: NavidromeUserModel, rhs: NavidromeUserModel) -> Bool {
        return lhs.id == rhs.id &&
        lhs.hostUrl == rhs.hostUrl
    }
    
}

/*
 {\"id\":\"dbea1a25-a3cd-4915-bee1-81f1c1f63a75\",\"isAdmin\":false,\"name\":\"melodreek\",\"subsonicSalt\":\"90ca15\",\"subsonicToken\":\"fe8bbe21a304ca3f5e543c4019294f2f\",\"token\":\"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhZG0iOmZhbHNlLCJleHAiOjE3NDAxMzE4OTYsImlhdCI6MTc0MDA0NTQ5NiwiaXNzIjoiTkQiLCJzdWIiOiJtZWxvZHJlZWsiLCJ1aWQiOiJkYmVhMWEyNS1hM2NkLTQ5MTUtYmVlMS04MWYxYzFmNjNhNzUifQ.Af9hI15vdqnYAScAxhJQOrA1zht7hg8-gBLzYguVjZU\",\"username\":\"melodreek\"}"
 */
