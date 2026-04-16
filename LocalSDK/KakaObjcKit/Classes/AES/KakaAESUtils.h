//
//  KakaAESUtils.h
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2022/4/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KakaAESUtils : NSObject

/**
 * AES加密
 * @param encryptKey   加密秘钥
 * @param ivKey        偏移秘钥
 * @param encryptData  需要加密的二进制数据
 */
+ (NSData *)encryptWithKey:(NSString *)encryptKey andIvKey:(NSString *)ivKey andEncryptData:(NSData *)encryptData;

/**
 * AES加密
 * @param encryptKey   加密秘钥
 * @param ivKey        偏移秘钥
 * @param encryptText  需要加密的字符串
 */
+ (NSString *)encryptWithKey:(NSString *)encryptKey andIvKey:(NSString *)ivKey andEncryptText:(NSString *)encryptText;

/**
 * AES解密
 * @param decryptKey   解密秘钥
 * @param ivKey        偏移秘钥
 * @param decryptData  需要解密的二进制数据
 */
+ (NSData *)decryptWithKey:(NSString *)decryptKey andIvKey:(NSString *)ivKey andDecryptData:(NSData *)decryptData;

/**
 * AES解密
 * @param decryptKey   解密秘钥
 * @param ivKey        偏移秘钥
 * @param decryptText  需要解密的字符串
 */
+ (NSString *)decryptWithKey:(NSString *)decryptKey andIvKey:(NSString *)ivKey andDecryptText:(NSString *)decryptText;

@end



NS_ASSUME_NONNULL_END
