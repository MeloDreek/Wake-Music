//
//  KakaAESUtils+App.h
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2022/4/4.
//

#import "KakaAESUtils.h"

NS_ASSUME_NONNULL_BEGIN

@interface KakaAESUtils (Kaka)

/**
 * AES加密_Project
 * @param encryptData  需要加密的二进制数据
 */
+ (NSData *)encryptWithData:(NSData *)encryptData;

/**
 * AES加密_Project
 * @param encryptText  需要加密的字符串
 */
+ (NSString *)encryptWithText:(NSString *)encryptText;

/**
 * AES解密_Project
 * @param decryptData  需要解密的二进制数据
 */
+ (NSData *)decryptWithData:(NSData *)decryptData;

/**
 * AES解密_Project
 * @param decryptText  需要解密的字符串
 */
+ (NSString *)decryptWithText:(NSString *)decryptText;

@end

NS_ASSUME_NONNULL_END
