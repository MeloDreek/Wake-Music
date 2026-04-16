//
//  LyricLineModel.h
//  KakaTaglibKit
//
//  Created by 张文 on 11/5/24.
//

#import <Foundation/Foundation.h>


@class LyricInfo;
@interface LyricLineModel : NSObject

/// 没有时间属性
@property (nonatomic, assign) BOOL isNoneTime;

/// 歌名
@property (nonatomic, copy) NSString *title;

/// 歌手
@property (nonatomic, copy) NSString *artist;

/// 专辑
@property (nonatomic, copy) NSString *album;

/// 创建歌词的人
@property (nonatomic, copy) NSString *creater;

/// 总时长（毫秒）
@property (nonatomic, assign) NSTimeInterval totalTime;

/// 时间补偿值（毫秒），正值表示整体提前，负值相反。这是用于总体调整显示快慢的
@property (nonatomic, assign) int offset;

/// 每一行的歌词
@property (nonatomic, copy) NSArray <LyricInfo *>*lyrics;

@end

@interface LyricInfo : NSObject

/// 开始时间（毫秒）
@property (nonatomic, assign) NSTimeInterval startTimestamp;

/// 结束时间（毫秒）
@property (nonatomic, assign) NSTimeInterval endTimestamp;

/// 完整歌词
@property (nonatomic, copy) NSString *fullLyric;

/// 真正的歌词
@property (nonatomic, copy) NSString *realLyric;

/// 歌词译文
@property (nonatomic, copy) NSString *translatLyric;

@end
