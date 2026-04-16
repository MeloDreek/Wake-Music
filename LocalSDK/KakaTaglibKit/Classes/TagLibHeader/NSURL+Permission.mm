//
//  NSURL+Permission.m
//  KakaTaglibKit
//
//  Created by 张文 on 12/22/24.
//

#import "NSURL+Permission.h"
#include <sys/_types/_s_ifmt.h>

@implementation NSURL (Permission)

- (BOOL)isReadOnly {
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.path error:&error];
    
    if (error) {
        DebugLog(@"Error getting file attributes: %@", error.localizedDescription);
        return NO; // 如果无法获取属性，默认认为不是只读
    }
    
    NSNumber *filePermissions = attributes[NSFilePosixPermissions];
    if (filePermissions) {
        NSInteger permissions = filePermissions.integerValue;
        // 1、检查 owner 是否有写权限
        BOOL isWritable = (permissions & S_IWUSR) != 0;
        
//         2、检查 owner、staff、everyone 是否有写权限
//        BOOL isWritable = permissions & S_IWUSR || permissions & S_IWGRP || permissions & S_IWOTH;
        return !isWritable; // 如果不可写，则为只读
    }
    
    return NO; // 如果没有权限信息，默认认为不是只读
}

- (BOOL)setReadableAndWritable {
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.path error:&error];
    
    if (error) {
        DebugLog(@"Error getting file attributes: %@", error.localizedDescription);
        return NO;
    }
    
    NSNumber *filePermissions = attributes[NSFilePosixPermissions];
    if (filePermissions) {
        NSInteger permissions = filePermissions.integerValue;
        
        // 1、修改 owner（用户）的权限：确保读写权限
        permissions |= (S_IWUSR | S_IRUSR); // 设置用户读写权限
        
//         2、添加owner、staff和其他组的读写权限
//        permissions |= (S_IWUSR | S_IRUSR); // 用户读写权限
//        permissions |= (S_IWGRP | S_IRGRP); // 组读写权限
//        permissions |= (S_IWOTH | S_IROTH); // 其他读写权限
        
        NSDictionary *newAttributes = @{NSFilePosixPermissions: @(permissions)};
        [[NSFileManager defaultManager] setAttributes:newAttributes ofItemAtPath:self.path error:&error];
        
        if (error) {
            DebugLog(@"Error setting file attributes: %@", error.localizedDescription);
            return NO;
        }
        
        DebugLog(@"✅已经设置为读写权限");
        return YES;
    }
    
    return NO; // 如果权限信息不存在，返回失败
}

@end
