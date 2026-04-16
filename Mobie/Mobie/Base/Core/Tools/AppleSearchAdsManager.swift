//
//  AppleSearchAdsManager.swift
//  Mobie
//
//  Created by 张文 on 12/19/25.
//

import KakaFoundation
import AppGroupKit
import Alamofire
import AdServices
import SmartCodable

/// Apple返回的广告归因数据
struct ADServerInfoModel: SmartCodable {

    /// 来自ASA的安装 = true
    var attribution: Bool = false

    /// Organization ID（即 Campaign Group ID）
    var orgId: Int64?

    /// Campaign ID
    var campaignId: Int64?

    /// Ad Group ID
    var adGroupId: Int64?

    /// 广告变体 ID（仅 CPP 广告提供）
    var adId: Int64?

    /// 关键词 ID（仅 Search Results keyword 广告提供）
    var keywordId: Int64?

    /// 国家或地区（ISO 2 位）
    var countryOrRegion: String?

    /// 转化类型：Download / Redownload / PreOrder
    var conversionType: String?

    /// 归因类型：Click / View
    var claimType: String?

    /// 点击时间（仅 claimType = Click 时存在）
    var clickDate: Date?

    /// 展示时间（仅 claimType = View 时存在）
    var impressionDate: Date?
    
}

/// 量江湖返回的广告归因详细信息，包括具体的关键词
struct AdAttributionResult: SmartCodable {

    /// 是否归因成功
    var attribution: Bool = false

    /// Organization ID
    var orgId: Int64 = 0

    /// Organization 名称
    var orgName: String?

    /// Campaign ID
    var campaignId: Int64 = 0

    /// Campaign 名称
    var campaignName: String?

    /// Ad Group ID
    var adGroupId: Int64 = 0

    /// Ad Group 名称
    var adGroupName: String?

    /// 广告 ID
    var adId: Int64? = 0

    /// 关键词 ID
    var keywordId: Int64?

    /// 关键词
    var keyword: String?

    /// 国家或地区（ISO 2 位）
    var countryOrRegion: String?

    /// 转化类型：Download / Redownload / PreOrder
    var conversionType: String?

    /// 归因类型：Click / View
    var claimType: String?
    
}

/// 上报归因事件的参数模型
struct PostbackParameter: SmartCodable {
    
    /// 软件ID
    var app_id: String = Application.wakeMusic.appstoreID()
    
    /// 用户ID
    var user_id: String = UserInfoManager.shared.cloudUserID
    
    /// 事件名称
    var event_name: String = "install"
    
    /// 秒，时间戳
    var event_time: String = Date().convertString(false)
    
    /// 事件价值，单位：RMB
    var event_value: Double? = 0
    
    /// 版本号
    var app_ver: String? = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String
    
    /// 国家代码，US
    var country_code: String = PhoneSetManager.regionCode()
    
    /// 省份，Henan
    var province: String?
    
    /// 城市，Zhengzhou
    var city: String?
    
    /// 操作系统版本
    var os_version: String = UIDevice.current.systemVersion
    
    /// 设备类型
    var device_model: String = UIDevice.current.model
    
    /// 归因 JSON 数据包，URL Encode 编码；当事件为 install 时必需，其他事件时可选
    var attribution_payload: String?
    
    
    /// 构造参数
    static func parameters(eventType: ASAEventType, eventValue: Double = 0, model: ADServerInfoModel?) -> Parameters {
        
        var newModel = PostbackParameter()
        newModel.event_name = eventType.rawValue
        
        if let adModel = model, eventType == .install {
            newModel.event_value = nil
            newModel.attribution_payload = "urlencode(\(adModel.toJSONString() ?? ""))"
        }else{
            newModel.event_value = eventValue
            newModel.attribution_payload = nil
        }
        
        let jsonDic = newModel.toDictionary() ?? Parameters()
        
        return jsonDic
    }
    
}

enum ASAEventType: String {
    case install = "install"      // 激活/上报归因
    case purchase = "purchase"   // 购买事件
}

class AppleSearchAdsManager: NSObject {
    
    static let shared = AppleSearchAdsManager()
    
    // 广告归因重试次数
    private var tokenRetryCount: Int = 0
    
    // 广告归因重试次数
    private var postRetryCount: Int = 0
    
    // 激活时实施广告归因
    func handleASAAttribution() {
        do {
            let token = try AAAttribution.attributionToken()
            
            AppleSearchAdsManager.shared.fetchAdAttribution(token: token) { result in
                switch result {
                case .success(let adModel):
                    if adModel.attribution {
                        self.postbackAdAttribution(eventType: .install, eventValue: 0, admodel: adModel)
                    }
                    break
                case .failure(_):
                    self.retryAdAttribution()
                    break
                }
            }
            
        } catch {
            let errorMsg = "AD Token = \(error.localizedDescription)"
            debugPrint("获取广告归因失败 = \(errorMsg)")
                        
            self.perform(#selector(retryAdAttribution), with: nil, afterDelay: 0.3)
        }
    }
    
}

// 获取ASA归因
extension AppleSearchAdsManager {
    // 获取广告归因信息
    private func fetchAdAttribution(token: String, completion: @escaping (Result<ADServerInfoModel, KakaError>) -> Void) {
        let url = "https://api-adservices.apple.com/api/v1/"
        let postData = token.data(using: .utf8, allowLossyConversion: true)

        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = postData

        AF.request(request).validate(statusCode: 200..<300).responseString { response in
            switch response.result {
            case .success(let responseString):
                debugPrint("🍎ADServer广告归因 = \(responseString)")
                guard let adModel = ADServerInfoModel.deserialize(from: responseString) else {
                    completion(.failure(KakaError.unknowError))
                    return
                }
                
                completion(.success(adModel))
                
                break
            case .failure(let error):
                completion(.failure(KakaError.custom(error.errorDescription ?? error.localizedDescription)))
                break
            }
        }
    }
    
    // 重试获取广告归因
    @objc private func retryAdAttribution() {
        self.tokenRetryCount += 1
        if self.tokenRetryCount >= 3 {
            return
        }
        
        self.handleASAAttribution()
    }
}

// MARK: 上报事件
extension AppleSearchAdsManager {
    // 上报广告归因数据给量江湖
    func postbackAdAttribution(eventType: ASAEventType, eventValue: Double = 0, admodel: ADServerInfoModel?) {
        let url = URL(string: "https://cdn4.liangjianghu.com/v2/postback")!
        let header = HTTPHeaders([HTTPHeader(name: "x-api-key", value: LiangjianghuKey)])
        let param = PostbackParameter.parameters(eventType: eventType, eventValue: eventValue, model: admodel)
        
        AF.request(url, method: .get, parameters: param, headers: header).responseData { response in
            switch response.result {
            case .success(let data):
                let responseJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                debugPrint("✅ 上报广告归因 = \(responseJson ?? [:])")
                let error_code = responseJson?["error_code"] as? Int
                if error_code == 0 {
                    if eventType == .install {
                        UserInfoManager.shared.isPostAAAttribution = true
                    }
                    debugPrint("✅ 上报广告归因成功")
                }else{
                    DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.3) {
                        self.retryPostAttribution(eventType: eventType, eventValue: eventValue, admodel: admodel)
                    }
                }

                break
            case .failure(_):
                DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.3) {
                    self.retryPostAttribution(eventType: eventType, eventValue: eventValue, admodel: admodel)
                }
                break
            }
        }
        
    }
    
    // 重试上报广告归因
    private func retryPostAttribution(eventType: ASAEventType, eventValue: Double = 0, admodel: ADServerInfoModel?) {
        self.postRetryCount += 1
        if self.postRetryCount >= 3 {
            return
        }
        
        self.postbackAdAttribution(eventType: eventType, eventValue: eventValue, admodel: admodel)
    }
    
}

// MARK: 其他
extension AppleSearchAdsManager {
    // 获取关键词信息详细
    func getDetialAdAttribution(_ model: ADServerInfoModel) {
        
        let url = URL(string: "https://cdn4.liangjianghu.com/v2/adservices")!
        
        var request = URLRequest(url: url)
        request.method = .post
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(LiangjianghuKey, forHTTPHeaderField: "x-api-key")
        
        let bodyArray = [model].compactMap { $0.toDictionary() }
        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyArray)
        
        AF.request(request).responseString { response in
            switch response.result {
            case .success(let responseString):
                debugPrint("✅ 获取关键词信息详细 = \(responseString)")
                guard let resultModel = AdAttributionResult.deserialize(from: responseString) else {
                    return
                }
                
                debugPrint("✅获取关键词信息详细：\(resultModel)")
                break
            case .failure(let error):
                debugPrint("❌ 获取关键词信息详细 = \(error)")
                break
            }
        }
        
    }
}
