//
//  MetadataTagModel.h
//  KakaTaglibKit
//
//  Created by 张文 on 11/5/24.
//

#import <Foundation/Foundation.h>
#import "LyricLineModel.h"

#if TARGET_OS_OSX
#define KakaImage NSImage
#else
#define KakaImage UIImage
#endif

@interface MetadataTagModel : NSObject

/// 文件URL
@property (nonatomic, strong) NSURL *fileURL;

/// 歌名
@property (nonatomic, copy) NSString *title;

/// 艺术家
@property (nonatomic, copy) NSString *artist;

/// 专辑
@property (nonatomic, copy) NSString *album;

/// 音乐流派
@property (nonatomic, copy) NSString *genre;

/// 评论
@property (nonatomic, copy) NSString *comment;

/// 年代
@property (nonatomic, assign) NSUInteger year;

/// 音轨，也就是CD上的顺序
@property (nonatomic, assign) NSUInteger track;

/// 音频比特率：比特每秒（bps）
@property (nonatomic, assign) NSUInteger bitrate;

/// 音频采样率：赫兹（Hz）
@property (nonatomic, assign) NSUInteger sampleRate;

/// 时间
@property (nonatomic, assign) NSUInteger durationSeconds;

/// 音频通道数（int）
@property (nonatomic, assign) NSUInteger channel;

/// 封面
@property (nonatomic, strong) KakaImage *coverArt;

/// 歌词信息
@property (nonatomic, strong) LyricLineModel *lyricModel;


@end
