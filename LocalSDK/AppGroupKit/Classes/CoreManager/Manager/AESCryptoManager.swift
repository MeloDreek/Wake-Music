//
//  AESCryptoManager.swift
//  KakaFoundation
//
//  Created by Melo Dreek on 2023/7/14.
//
import CryptoKit

public class AESCryptoManager {
    
    /// 专门针对字符串的AES加密
    /// - Parameters:
    ///   - string: 需要加密的字符串
    ///   - key: 密钥
    /// - Returns: 密文
    public static func encryptAES(string: String, key: SymmetricKey?) -> String? {
        
        guard let vKey = key else { return string }
        
        if let data = string.data(using: .utf8) {
            do {
                let sealedBox = try AES.GCM.seal(data, using: vKey)
                let encryptedData = sealedBox.combined // 包含无法用UTF-8编码表示的字节
                return encryptedData?.base64EncodedString()
            } catch {
                return nil
            }
        } else {
            return nil
        }
        
    }
    
    /// 专门针对字符串的AES加密
    /// - Parameters:
    ///   - string: 需要解密的字符串
    ///   - key: 密钥
    /// - Returns: 解密后的明文
    public static func decryptAES(string: String, key: SymmetricKey?) -> String? {
        
        guard let vKey = key else { return string }
        
        if let data = Data(base64Encoded: string) {
            do {
                let sealedBox = try AES.GCM.SealedBox(combined: data)
                let decryptedData = try AES.GCM.open(sealedBox, using: vKey)
                return String(data: decryptedData, encoding: .utf8)
            } catch {
                return nil
            }
        } else {
            return nil
        }
    }
    
    
    /// AES二进制加密 ==> 适用于文件流
    /// - Parameters:
    ///   - data: 需要加密的内容
    ///   - key: AES密钥
    /// - Returns: 加密结果
    public static func encryptAES(data: Data, key: SymmetricKey?) -> Data? {
        
        guard let vKey = key else { return data }

        do {
            let sealedBox = try AES.GCM.seal(data, using: vKey)
            let resultData = sealedBox.combined
            return resultData
        } catch {
            return nil
        }
        
    }
    
    /// AES二进制解密 ==> 适用于文件流
    /// - Parameters:
    ///   - data: 需要解密的内容
    ///   - key: AES密钥
    /// - Returns: 解密结果
    public static func decryptAES(data: Data, key: SymmetricKey?) -> Data? {
        
        guard let vKey = key else { return data }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: vKey)
        } catch {
            return nil
        }
    }
    
}
