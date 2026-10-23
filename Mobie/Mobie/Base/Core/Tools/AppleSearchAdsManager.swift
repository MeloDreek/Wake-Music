//
//  AppleSearchAdsManager.swift
//  Mobie
//
//  Created by 张文 on 12/19/25.
//

import KakaFoundation
import Alamofire
import AdServices
import SmartCodable

/// Apple返回的广告归因数据
private struct ADServerInfoModel: SmartCodableX {

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

final class AppleSearchAdsManager: NSObject {

    static let shared = AppleSearchAdsManager()

    // Apple 官方归因查询重试次数
    private var tokenRetryCount: Int = 0

    // 激活时仅向 Apple 官方接口查询归因，不向第三方发送安装或购买事件。
    func handleASAAttribution() {
        do {
            let token = try AAAttribution.attributionToken()

            fetchAdAttribution(token: token) { result in
                switch result {
                case .success:
                    break
                case .failure:
                    self.retryAdAttribution()
                }
            }
        } catch {
            perform(#selector(retryAdAttribution), with: nil, afterDelay: 0.3)
        }
    }
}

// 获取 Apple 官方 ASA 归因
extension AppleSearchAdsManager {

    private func fetchAdAttribution(token: String, completion: @escaping (Result<ADServerInfoModel, KakaError>) -> Void) {
        let url = "https://api-adservices.apple.com/api/v1/"
        let postData = token.data(using: .utf8, allowLossyConversion: true)

        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = postData

        AF.request(request).responseString { response in
            switch response.result {
            case .success(let responseString):
                guard let adModel = ADServerInfoModel.deserialize(from: responseString) else {
                    completion(.failure(KakaError.unknowError))
                    return
                }
                completion(.success(adModel))
            case .failure(let error):
                completion(.failure(KakaError.custom(error.errorDescription ?? error.localizedDescription)))
            }
        }
    }

    @objc private func retryAdAttribution() {
        tokenRetryCount += 1
        guard tokenRetryCount < 3 else { return }
        handleASAAttribution()
    }
}
