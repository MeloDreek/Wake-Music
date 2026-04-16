//
//  KakaAESUtils+App.m
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2022/4/4.
//

#import "KakaAESUtils+Kaka.h"

@implementation KakaAESUtils (Kaka)

#define EncryptKey  @"Ph?ayCyBkP!*n!h7ImSYnpP7wC[yfR60u&gap%ktsDRd]&x0E1h/nJqf&t*】FS5DD//8NBp》95q《【b]KeW!cqx(2vv6$Hy6》*vQ9"
#define IvKey       @"SX【1↔ox《w!》5(g9G0+7XgCZEX4)EDAvC^】VR)n1VJS【c8SIJd】0QtkZlWn+X《?gYx1ajTn$hph】WRz*Ok#yD+Fz]ySZydE*k9u02"

/**
 * AES加密_Police
 * @param encryptData  需要加密的二进制数据
 */
+ (NSData *)encryptWithData:(NSData *)encryptData
{
    if (encryptData.length == 0) {
        return encryptData;
    }
    return [KakaAESUtils encryptWithKey:EncryptKey andIvKey:IvKey andEncryptData:encryptData];
}

/**
 * AES加密_Police
 * @param encryptText  需要加密的字符串
 */
+ (NSString *)encryptWithText:(NSString *)encryptText
{
    if (encryptText.length == 0) {
        return encryptText;
    }
    NSData *encryptTextData = [encryptText dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encryptData = [KakaAESUtils encryptWithData:encryptTextData];
    NSString *base64String = [encryptData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    return base64String;
}

/**
 * AES解密_Police
 * @param decryptData  需要解密的二进制数据
 */
+ (NSData *)decryptWithData:(NSData *)decryptData
{
    if (decryptData.length == 0) {
        return decryptData;
    }
    return [KakaAESUtils decryptWithKey:EncryptKey andIvKey:IvKey andDecryptData:decryptData];
}

/**
 * AES解密_Police
 * @param decryptText  需要解密的字符串
 */
+ (NSString *)decryptWithText:(NSString *)decryptText
{
    if (decryptText.length == 0) {
        return decryptText;
    }
    NSData * base64Data = [[NSData alloc] initWithBase64EncodedString:decryptText options:NSDataBase64DecodingIgnoreUnknownCharacters];
    base64Data = [KakaAESUtils decryptWithData:base64Data];
    NSString *base64String = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
    return  base64String;
}

@end
