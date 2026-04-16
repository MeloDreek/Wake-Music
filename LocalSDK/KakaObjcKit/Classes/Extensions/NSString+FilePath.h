//
//  NSString+Path.h
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2022/5/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Path)

/// Document文件夹路径
+ (NSString *)appDocumentDir;

/// document后拼接文件路径
- (NSString *)appendDocumentDir;

/// Document的URL
- (NSURL *)appendDocumentURL;

+ (NSString *)appCacheDir;
- (NSString *)appendCacheDir;
- (NSURL *)appendCacheURL;

- (NSString *)md5Str;

@end

NS_ASSUME_NONNULL_END
