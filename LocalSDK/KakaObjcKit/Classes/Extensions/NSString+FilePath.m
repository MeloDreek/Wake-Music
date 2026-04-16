//
//  NSString+Path.m
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2022/5/4.
//

#import "NSString+FilePath.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (Path)

#pragma mark - Cache路径相关
+ (NSString *)appCacheDir
{
    NSString *cachesDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    return cachesDir;
}

- (NSString *)appendCacheDir
{
    return [[self.class appCacheDir] stringByAppendingPathComponent:self];
}

- (NSURL *)appendCacheURL
{
    return [NSURL fileURLWithPath:[self appendCacheDir]];
}

#pragma mark - Document路径相关
+ (NSString *)appDocumentDir
{
    NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    return docDir;
}

- (NSString *)appendDocumentDir
{
    return [[self.class appDocumentDir] stringByAppendingPathComponent:self];
}

- (NSURL *)appendDocumentURL
{
    return [NSURL fileURLWithPath:[self appendDocumentDir]];
}

- (NSString *)md5Str
{
    const char *str = [self UTF8String];
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];
    return filename;
}

@end

