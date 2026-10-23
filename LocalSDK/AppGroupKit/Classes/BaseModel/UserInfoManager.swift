//
//  UserInfoManager.swift
//  AppGroupKit
//
//  Created by Kaka Inc. on 2023/12/1.
//

import KakaObjcKit
import CryptoKit
import KakaFoundation
import SmartCodable


/// 只参与本地的数据存储---远程头像单独获取
public class UserInfoManager: SmartCodableX, ObservableObject {
    
    static public var shared = UserInfoManager.read() ?? UserInfoManager()
    
    required public init() {
        let base64Key = StringEncoder.aes_KEY_BASE64()
        if let keyData = Data(base64Encoded: base64Key) {
            let aesKey = SymmetricKey(data: keyData)
            Self.aesPassKey = aesKey
        }
    }
    
    /// AES密钥
    @SmartIgnored public static var aesPassKey: SymmetricKey?
    
    /// 首次注册生成的时间戳ID
    public var cloudUserID: String = Date().convertString()
    
    /// 首次注册时的操作系统
    public var registerOsType : DeviceOSType?
    
    /// 头像在本地的名称
    public var localAvatarName: String? = avatarDefaultName
    
    /// 注册时的日期
    public var registerDate: TimeInterval = Date().timeIntervalSince1970
    
    /// 注册时的版本号
    public var registerVersion: String = "1.0.0"
    
    /// 上报了ASA关键词归因
    public var isPostAAAttribution: Bool = false
    
    /// 用户昵称
    @SmartPublished public var nickName = PhoneSetManager.regionCode() + "_" + Date().convertToDateString(dateFormat: "yyyyMMdd") {
        didSet {
            save()
        }
    }
    
    /// 首次创建文件的时间
    @SmartPublished public var firstFileDate: TimeInterval? {
        didSet {
            save()
        }
    }
    
    /// 首次连接远程音乐服的时间
    @SmartPublished public var firstRemoteDate: TimeInterval? {
        didSet {
            save()
        }
    }
    
    /// VIP 到期的 Unix 秒时间戳；旧版本缓存也可能是毫秒。
    @SmartPublished public var expireDate: TimeInterval? {
        didSet {
            save()
        }
    }

    public var membershipExpirationDate: Date? {
        guard let timestamp = expireDate, timestamp.isFinite, timestamp > 0 else { return nil }
        let seconds = timestamp >= 100_000_000_000 ? timestamp / 1000 : timestamp
        return Date(timeIntervalSince1970: seconds)
    }
    
    /// 是否处于免费试用期
    @SmartPublished public var isFreeTrail: Bool = false {
        didSet {
            save()
        }
    }
    
    /// 自动编辑的文件数量
    @SmartPublished public var autoEditFileCount: Int = 0 {
        didSet {
            save()
        }
    }
    
    /// 订阅状态
    @SmartPublished public var payStatus: PurchargeStatus = .normal {
        didSet {
            save()
        }
    }
    
    /// 订阅的内购ID
    @SmartPublished public var payGoodsId: String? {
        didSet {
            save()
        }
    }
    
    /// 付款的内购产品
    public func payedStoreModel() -> PurchaseStoreID? {
        guard let payGoodsId = self.payGoodsId else {
            return nil
        }
        
        let storeID = PurchaseStoreID(rawValue: payGoodsId)
        return storeID
    }
    
}



extension UserInfoManager {
    private class func kaka_UserCacheDefaultkey() -> String {
        return StringEncoder.userJsonKey()
    }
    
    private class func sharedUD() -> UserDefaults {
        let sharedUD = UserDefaults(suiteName: Application.wakeMusic.sharedGroupName()) ?? UserDefaults.standard
        return sharedUD
    }
    
    private class func read() -> UserInfoManager? {
        
        if Self.aesPassKey == nil {
            let base64Key = StringEncoder.aes_KEY_BASE64()
            if let keyData = Data(base64Encoded: base64Key) {
                let aesKey = SymmetricKey(data: keyData)
                Self.aesPassKey = aesKey
            }
        }

        let key = UserInfoManager.kaka_UserCacheDefaultkey()
        guard let encryDataStr = Self.sharedUD().string(forKey: kUserInfoKey) else { return nil }
                
        let userJsonStr = AESCryptoManager.decryptAES(string: encryDataStr ?? "", key: Self.aesPassKey)
          
        let model = UserInfoManager.deserialize(from: userJsonStr)
        return model
    }
    
    private func save() {
        
        if Self.aesPassKey == nil {
            let base64Key = StringEncoder.aes_KEY_BASE64()
            if let keyData = Data(base64Encoded: base64Key) {
                let aesKey = SymmetricKey(data: keyData)
                Self.aesPassKey = aesKey
            }
        }

        let userJsonStr = self.toJSONString() ?? ""
        let encryDataStr = AESCryptoManager.encryptAES(string: userJsonStr, key: Self.aesPassKey)
        
        Self.sharedUD().set(encryDataStr, forKey: UserInfoManager.kaka_UserCacheDefaultkey())
        Self.sharedUD().synchronize()
    }
    
    public class func reset() {
        let key = UserInfoManager.kaka_UserCacheDefaultkey()
        Self.sharedUD().set(nil, forKey: key)
        Self.sharedUD().synchronize()
        
        UserInfoManager.shared = UserInfoManager()
    }
    
}
