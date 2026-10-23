//
//  APIManager.swift
//  Waketag
//
//  Created by Melo on 4/7/25.
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
    func requestNavidrome(navUser: NavidromeUserModel?, endpoint: String, method: HTTPMethod = .get, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.queryString, success: ((Data)->Void)? = nil, fail: ((KakaError)->Void)? = nil) {
        
        guard let navUser = navUser else {
            fail?(.unknowError)
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
                fail?(KakaError.custom(afError.errorDescription ?? afError.localizedDescription))
                break
            }
        }
        
    }

    // 创建一个Subsonic请求
    func requestSubsonic(navUser: NavidromeUserModel?, endpoint: String, method: HTTPMethod = .get, parameters: Parameters?, apiVersion: String = AppMeta.subsonicApiVersion, encoding: ParameterEncoding = URLEncoding.queryString, success: ((SubsonicResponse)->Void)? = nil, fail: ((KakaError)->Void)? = nil) {
        
        guard let navUser = navUser else {
            fail?(.unknowError)
            return
        }
        
        let url = navUser.hostUrl + endpoint + navUser.subsonicParams()
        
        self.frontSession.request(url, method: method, parameters: parameters, encoding: encoding, headers: .default).validate(statusCode: 200..<500).responseData { dataResult in
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
                    fail?(KakaError.custom(customError.localizedDescription))
                }
                                
                break
            case .failure(let error):
                let customError = NSError(domain: NSURLErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                fail?(KakaError.custom(customError.localizedDescription))
                break
            }
        }
        
    }

    // 下载
    func downloadMusic(model: MusicItemModel, targetFileURL: URL, progress: ((Double)->Void)? = nil, success: ((URL)->Void)? = nil, fail: ((KakaError)->Void)? = nil) {
                
        let destination: DownloadRequest.Destination = { _, response in
            return (targetFileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        var headers: HTTPHeaders = HTTPHeaders.default
        if let googleFile = model.googleFile, let googleUser = googleFile.googleUser {
            headers.add(name: "Authorization", value: "Bearer " + googleUser.accessToken)
        }
        
        AF.download(model.mediaPlayURL, headers: headers, to: destination).validate(statusCode: 200..<500).downloadProgress { progressValue in
            progress?(progressValue.fractionCompleted)
          }.responseURL { response in
            switch response.result {
            case .success(let fileURL):
                success?(fileURL)
                break
            case .failure(let error):
                DispatchQueue.main.asyncAfter(wallDeadline: .now() + 1) {
                    try? FileManager.default.removeItem(at: targetFileURL)
                    NotificationCenter.default.post(name: Notification.Name(rawValue: kLocalMusicChangedKey), object: nil)
                }
                fail?(KakaError.custom(error.errorDescription ?? error.localizedDescription))
                break
            }
        }
    }
    
    // 创建一个普通的请求
    func GET(requestURL: String, parameters: Parameters = Parameters.init(), success: ((Data)->Void)? = nil, fail: ((KakaError)->Void)? = nil) {
        
        let headers: HTTPHeaders = ["Content-Type": "text/plain"]

        self.frontSession.request(requestURL, method: .get, parameters: parameters, encoding: URLEncoding.queryString, headers: headers).responseData { response in
            switch response.result {
            case .success(let data):
                success?(data)
                break
            case .failure(let afError):
                debugPrint("afError = \(afError.localizedDescription)")
                let errMsg = afError.errorDescription ?? afError.localizedDescription
                fail?(KakaError.custom(errMsg))
                break
            }
        }
        
    }
    
    
    func POST(requestURL: String, parameters: Parameters = Parameters.init(), header: HTTPHeaders, success: ((Data)->Void)? = nil, fail: ((KakaError)->Void)? = nil) {
        
        self.frontSession.request(requestURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: header).responseData { response in
            switch response.result {
            case .success(let data):
                success?(data)
                break
            case .failure(let afError):
                debugPrint("afError = \(afError.localizedDescription)")
                let errMsg = afError.errorDescription ?? afError.localizedDescription
                fail?(KakaError.custom(errMsg))
                break
            }
        }
        
    }
    
}
