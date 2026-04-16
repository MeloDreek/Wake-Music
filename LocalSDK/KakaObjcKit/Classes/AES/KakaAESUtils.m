//
//  KakaAESUtils.m
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2022/4/4.
//

#import "KakaAESUtils.h"
#import <CommonCrypto/CommonCrypto.h>
#import <CommonCrypto/CommonDigest.h>

@implementation KakaAESUtils

/**
 * AES加密
 * @param encryptKey   加密秘钥
 * @param ivKey        偏移秘钥
 * @param encryptData  需要加密的二进制数据
 */
+ (NSData *)encryptWithKey:(NSString *)encryptKey andIvKey:(NSString *)ivKey andEncryptData:(NSData *)encryptData
{
    encryptKey = [KakaAESUtils checkAESKey:encryptKey];
    ivKey = [KakaAESUtils checkAESKey:ivKey];
    //16位偏移，仅限于CBC模式需要
    NSData *initVector = [ivKey dataUsingEncoding:NSUTF8StringEncoding];
    //公钥
    char keyPtr[kCCKeySizeAES128+1];
    memset(keyPtr, 0, sizeof(keyPtr));
    [encryptKey getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    //数据长度
    NSUInteger dataLength = encryptData.length;
    //加密输出缓冲区大小
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    //加密输出缓冲区
    void *buffer = malloc(bufferSize);
    //实际输出大小
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,//kCCEncrypt代表加密
                                          kCCAlgorithmAES,//加密算法
                                          kCCOptionPKCS7Padding,//CBC -> PKCS7Padding，ECB -> kCCOptionPKCS7Padding|kCCOptionECBMode
                                          keyPtr,
                                          kCCBlockSizeAES128,//密钥长度128
                                          initVector.bytes,//偏移字符串,ECB模式传NULL
                                          encryptData.bytes,//编码内容
                                          dataLength,
                                          buffer,
                                          bufferSize,
                                          &numBytesEncrypted);
    if (cryptStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    free(buffer);
    return nil;
}

/**
 * AES加密
 * @param encryptKey   加密秘钥
 * @param ivKey        偏移秘钥
 * @param encryptText  需要加密的字符串
 */
+ (NSString *)encryptWithKey:(NSString *)encryptKey andIvKey:(NSString *)ivKey andEncryptText:(NSString *)encryptText
{
    encryptKey = [KakaAESUtils checkAESKey:encryptKey];
    ivKey = [KakaAESUtils checkAESKey:ivKey];
    NSData *data = [encryptText dataUsingEncoding:NSUTF8StringEncoding];
    //对数据进行加密
    NSData *result = [KakaAESUtils encryptWithKey:encryptKey andIvKey:ivKey andEncryptData:data];
    //转换为2进制字符串
    if (result && result.length > 0) {
        Byte *datas = (Byte*)[result bytes];
        NSMutableString *output = [NSMutableString stringWithCapacity:result.length * 2];
        for(int i = 0; i < result.length; i++){
            [output appendFormat:@"%02x", datas[i]];
        }
        return output;
    }
    return nil;
}

/**
 * AES解密
 * @param decryptKey   解密秘钥
 * @param ivKey        偏移秘钥
 * @param decryptData  需要解密的二进制数据
 */
+ (NSData *)decryptWithKey:(NSString *)decryptKey andIvKey:(NSString *)ivKey andDecryptData:(NSData *)decryptData
{
    decryptKey = [KakaAESUtils checkAESKey:decryptKey];
    ivKey = [KakaAESUtils checkAESKey:ivKey];
    //16位偏移，仅限于CBC模式需要
    NSData *initVector = [ivKey dataUsingEncoding:NSUTF8StringEncoding];
    //公钥
    char keyPtr[kCCKeySizeAES128+1];
    memset(keyPtr, 0, sizeof(keyPtr));
    [decryptKey getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    //数据长度
    NSUInteger dataLength = decryptData.length;
    //加密输出缓冲区大小
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    //加密输出缓冲区
    void *buffer = malloc(bufferSize);
    //实际输出大小
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt,//kCCDecrypt代表解密
                                          kCCAlgorithmAES,//加密算法
                                          kCCOptionPKCS7Padding,//CBC -> PKCS7Padding，ECB -> kCCOptionPKCS7Padding|kCCOptionECBMode
                                          keyPtr,
                                          kCCBlockSizeAES128,//密钥长度128
                                          initVector.bytes,//偏移字符串,ECB模式传NULL
                                          decryptData.bytes,//编码内容
                                          dataLength,
                                          buffer,
                                          bufferSize,
                                          &numBytesDecrypted);
    if (cryptStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    free(buffer);
    return nil;
}

/**
 * AES解密
 * @param decryptKey   解密秘钥
 * @param ivKey        偏移秘钥
 * @param decryptText  需要解密的字符串
 */
+ (NSString *)decryptWithKey:(NSString *)decryptKey andIvKey:(NSString *)ivKey andDecryptText:(NSString *)decryptText
{
    decryptKey = [KakaAESUtils checkAESKey:decryptKey];
    ivKey = [KakaAESUtils checkAESKey:ivKey];
    //转换为2进制Data
    NSMutableData *data = [NSMutableData dataWithCapacity:decryptText.length / 2];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    int i;
    for (i=0; i < [decryptText length] / 2; i++) {
        byte_chars[0] = [decryptText characterAtIndex:i*2];
        byte_chars[1] = [decryptText characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [data appendBytes:&whole_byte length:1];
    }
    
    //对数据进行解密
    NSData* result = [KakaAESUtils decryptWithKey:decryptKey andIvKey:ivKey andDecryptData:data];
    if (result && result.length > 0) {
        return [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
    }
    return nil;
}
/**
 * 加密key检查
 * aesKey 加密Key
 * 前后端统一加密key，具体操作按照项目要求
 */
+ (NSString *)checkAESKey:(NSString *)AES_Key
{
    if (AES_Key.length < 16) {
        NSMutableArray *array = [NSMutableArray arrayWithArray:@[AES_Key]];
        while (array.count <= 16 - AES_Key.length) {
            [array insertObject:@"0" atIndex:0];
        }
        AES_Key = [array componentsJoinedByString:@""];
    }
    return AES_Key;
}

@end

