//
//  APIManager.swift
//  Mobie
//
//  Created by 张文 on 2/20/25.
//

import KakaFoundation
import AppGroupKit
import Alamofire
import SmartCodable

class APIManager {
    static let shared = APIManager()

    private(set) var frontSession: Alamofire.Session

    private init() {
        frontSession = Self.createSession()
    }
    
    func reconfigureSession() {
        frontSession = Self.createSession()
    }

    private static func createSession() -> Session {

      let configuration = URLSessionConfiguration.default
      configuration.timeoutIntervalForRequest = 30

      let retrier = RetryPolicy(retryLimit: 3)

      return Alamofire.Session(
        configuration: configuration, interceptor: retrier,
        eventMonitors: [])
    }
    
    /// 登录Navidrome
    func loginNavidrome(serverUrl: String, isLargeServer: Bool, username: String, password: String, completion: @escaping (Result<NavidromeUserModel, KakaError>) -> Void) {
        let urlStr = serverUrl + API.Navidrome.login
        
        guard let url = URL(string: urlStr) else {
            let kakaErr = KakaError.custom(AFError.invalidURL(url: serverUrl).errorDescription ?? serverUrl)
            completion(.failure(kakaErr))
            return
        }
        
        let parameters: [String: Any] = ["username": username, "password": password]

        self.frontSession.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default) { request in
            request.timeoutInterval = 10
        }.response(queue: .main) { response in
            switch response.result {
            case .success(let data):
                guard let data = data else {
                    completion(.failure(KakaError.custom("login failed")))
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8), var userModel = NavidromeUserModel.deserialize(from: responseString), !userModel.token.isEmpty {
                    debugPrint("登录Nav = \(responseString)")
                    userModel.username = username
                    userModel.password = password
                    userModel.hostUrl = serverUrl
                    userModel.isLargeServer = isLargeServer
                    
                    completion(.success(userModel))
                }else{
                    // 业务错误：包括账号密码错误
                    let errorMsg = String(data: data, encoding: .utf8) ?? "login failed"
                    completion(.failure(KakaError.custom(errorMsg)))
                }
                break
            case .failure(let error):
                // 请求错误                
                completion(.failure(KakaError.custom(error.errorDescription ?? error.localizedDescription)))
                break
            }
        }
        
    }

    // 创建一个Navidrome请求
    func requestNavidrome(navUser: NavidromeUserModel?, endpoint: String, method: HTTPMethod = .get, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.queryString, success: ((Data)->Void)? = nil, fail: ((Error)->Void)? = nil) {
        
        guard let navUser = navUser else {
            fail?(AFError.explicitlyCancelled)
            return
        }
        
        let url = navUser.hostUrl + endpoint
        let headers: HTTPHeaders = [API.NDAuthHeader: "Bearer \(navUser.token)",
                                    "x-nd-client-unique-id": AppMeta.identifier
                                    ]

        self.frontSession.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers).responseData { response in
            switch response.result {
            case .success(let data):
                success?(data)
                break
            case .failure(let afError):
                debugPrint("afError = \(afError.localizedDescription)")
                fail?(afError)
                break
            }
        }
        
    }

    // 创建一个Subsonic请求
    func requestSubsonic(navUser: NavidromeUserModel?, endpoint: String, method: HTTPMethod = .get, parameters: Parameters?, apiVersion: String = AppMeta.subsonicApiVersion, encoding: ParameterEncoding = URLEncoding.queryString, success: ((SubsonicResponse)->Void)? = nil, fail: ((Error)->Void)? = nil) {
        
        guard let navUser = navUser else {
            fail?(AFError.explicitlyCancelled)
            return
        }
        
        let url = navUser.hostUrl + endpoint + navUser.subsonicParams()
#if DEBUG
        if let parameters = parameters {
            var requestURL = url
            for subDict in parameters {
                let paramStr = "&" + subDict.key + "=" + "\(subDict.value)"
                requestURL = url + paramStr
            }
            
            debugPrint("parameters = \(parameters),\r\n requestURL = \(requestURL)")
        }
#endif
        
        self.frontSession.request(url, method: method, parameters: parameters, encoding: encoding, headers: .default).responseData { dataResult in
            switch dataResult.result {
            case .success(let data):
                let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String : Any]
                let subsonicDict = json?["subsonic-response"] as? [String: Any]
                let subsonicModel = SubsonicResponse.deserialize(from: subsonicDict)
                
                if let subsonicModel = subsonicModel, subsonicModel.isSuccess() {
//                    debugPrint("subsonicDict = \(subsonicDict?.keys)")
                    AppMeta.subsonicApiVersion = subsonicModel.version
                    success?(subsonicModel)
                }else{
                    let customError = NSError(domain: NSURLErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: subsonicModel?.error?.message ?? json?.description ?? "failed"])
                    fail?(customError)
                }
                                
                break
            case .failure(let error):
                let customError = NSError(domain: NSURLErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                fail?(customError)
                break
            }
        }
        
    }
    
    // 创建一个普通的请求
    func GET(requestURL: String, parameters: Parameters = Parameters.init(), success: ((Data)->Void)? = nil, fail: ((Error)->Void)? = nil) {
        
        let headers: HTTPHeaders = ["Content-Type": "text/plain"]

        self.frontSession.request(requestURL, method: .get, parameters: parameters, encoding: URLEncoding.queryString, headers: headers).responseData { response in
            switch response.result {
            case .success(let data):
                success?(data)
                break
            case .failure(let afError):
                debugPrint("afError = \(afError.localizedDescription)")
                fail?(afError)
                break
            }
        }
        
    }
    
    
    func POST(requestURL: String, parameters: Parameters = Parameters.init(), header: HTTPHeaders, success: ((Data)->Void)? = nil, fail: ((Error)->Void)? = nil) {
        
        self.frontSession.request(requestURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: header).responseData { response in
            switch response.result {
            case .success(let data):
                success?(data)
                break
            case .failure(let afError):
                debugPrint("afError = \(afError.localizedDescription)")
                fail?(afError)
                break
            }
        }
        
    }
    
    
    // 获取应用程序的信息
    func requestApplication(appID: String, success: ((AppStoreInfoModel)->Void)? = nil, fail:((String?)->Void)? = nil) {
        let regionCode = PhoneSetManager.regionCode().lowercased()
        let appstoreUrl = "https://itunes.apple.com/\(regionCode)/lookup?id=\(appID)"
        debugPrint("获取App信息 = \(appstoreUrl)")
        guard let vUrl = URL(string: appstoreUrl) else { return }

        self.frontSession.request(vUrl, method: .get, encoding: URLEncoding.queryString).responseData { response in
            switch response.result {
            case .success(let data):
                guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let results = dict["results"] as? [[String: Any]], results.count > 0 else {
                    
                    return
                }
                
                guard let model = AppStoreInfoModel.deserialize(from: results.first) else {
                    fail?(nil)
                    return
                }
                
                success?(model)
                
                break
            case .failure(let afError):
                fail?(afError.localizedDescription)
                break
            }
        }
    }
    
}
