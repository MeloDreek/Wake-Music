//
//  StringEncoder.m
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2022/5/4.
//

#import "StringEncoder.h"
#import "RandomNumberKey.h"

@implementation StringEncoder

+ (NSString *)privatePassKey {
    return Random_OCString(_153337243);
}

+ (NSString *)foreverPassKey {
    return Random_OCString(_2262129051);
}

+ (NSString *)userJsonKey {
    return Random_OCString(_365239537);
}

+ (NSString *)AES_KEY_BASE64 {
    return Random_OCString(_2021160683);
}

+ (NSString *)itoolsURL {
    return Random_OCString(_1280363605);
}

@end
