//
//  StringEncoder.h
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2022/5/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StringEncoder : NSObject

+ (NSString *)privatePassKey;

+ (NSString *)foreverPassKey;

+ (NSString *)userJsonKey;

/// AES256密钥
+ (NSString *)AES_KEY_BASE64;

/// 爱思助手网址
+ (NSString *)itoolsURL;

@end

NS_ASSUME_NONNULL_END
