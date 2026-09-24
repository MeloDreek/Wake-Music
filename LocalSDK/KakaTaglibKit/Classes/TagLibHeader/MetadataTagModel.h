//
//  MetadataTagModel.h
//  KakaTaglibKit
//
//  Created by 张文 on 11/5/24.
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import "LyricLineModel.h"

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#define KakaImage NSImage
#else
#import <UIKit/UIKit.h>
#define KakaImage UIImage
#endif

@interface MetadataTagModel : NSObject

/// 文件URL
@property (nonatomic, strong, null_unspecified) NSURL *fileURL;

/// 歌名
@property (nonatomic, copy, null_unspecified) NSString *title;

/// 艺术家
@property (nonatomic, copy, null_unspecified) NSString *artist;

/// 专辑
@property (nonatomic, copy, null_unspecified) NSString *album;

/// 音乐流派
@property (nonatomic, copy, null_unspecified) NSString *genre;

/// 评论
@property (nonatomic, copy, null_unspecified) NSString *comment;

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
@property (nonatomic, strong, null_unspecified) KakaImage *coverArt;

/// 原始封面数据；适合缓存、传输，或按需解码为平台图像。
@property (nonatomic, copy, nullable) NSData *coverArtData;

/// 歌词信息
@property (nonatomic, strong, null_unspecified) LyricLineModel *lyricModel;


@end
