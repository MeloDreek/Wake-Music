//
//  NSURL+Permission.h
//  KakaTaglibKit
//
//  Created by 张文 on 12/22/24.
//

#import <Foundation/Foundation.h>
#import "TagLibHeader.h"


NS_ASSUME_NONNULL_BEGIN

@interface NSURL (Permission)

/// 是否为只读
- (BOOL)isReadOnly;

/// 设置为可读可写
- (BOOL)setReadableAndWritable;

@end


NS_ASSUME_NONNULL_END
