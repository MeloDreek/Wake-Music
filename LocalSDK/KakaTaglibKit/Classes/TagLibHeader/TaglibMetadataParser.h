//
//  TaglibMetadataParser.h
//  KakaTaglibKit
//
//  Created by 张文 on 11/5/24.
//

#import <Foundation/Foundation.h>
#import "MetadataTagModel.h"
#import "NSURL+Permission.h"

typedef NS_ENUM(NSUInteger, TaglibReaderType) {
    TaglibReaderTypeAll = 0,        // 基础信息，封面，歌词
    TaglibReaderTypeBasic = 1,      // 基础信息
    TaglibReaderTypeBasicCover = 2  // 基础信息+封面
};

/// 音乐标签解析器
@interface TaglibMetadataParser : NSObject

/// 解析完整的元数据
/// - Parameter fileURL: 文件路径
/// - Parameter readType: 读取信息的完整度
+ (MetadataTagModel *)readMetadataWithFileURL:(NSURL *)fileURL readType:(TaglibReaderType)readType;

/// 只读取文件封面
/// - Parameter fileURL: 文件路径
+ (KakaImage *)extractCoverArtFromURL:(NSURL *)fileURL;


/// 解析歌词
/// - Parameter fileURL: 歌词数字
+ (LyricLineModel *)extractLyricsFromURL:(NSURL *)fileURL;


/// 格式化歌词
/// - Parameter lyricsText: 格式化化后的歌词数组
+ (LyricLineModel *)parseSynchronizedLyrics:(NSString *)lyricsText;





/// 设置封面
/// - Parameters:
///   - fileURL: 文件路径
///   - coverImage: 新的封面图像
+ (BOOL)setCoverArt:(KakaImage *)coverImage toFileURL:(NSURL *)fileURL;

/// 设置标题
/// - Parameters:
///   - fileURL: 文件路径
///   - title: 新的标题
+ (BOOL)setTitle:(NSString *)title toFileURL:(NSURL *)fileURL;

/// 设置歌手
/// - Parameters:
///   - fileURL: 文件路径
///   - artist: 新的歌手名称
+ (BOOL)setArtist:(NSString *)artist toFileURL:(NSURL *)fileURL;

/// 设置专辑
/// - Parameters:
///   - fileURL: 文件路径
///   - album: 新的专辑名称
+ (BOOL)setAlbum:(NSString *)album toFileURL:(NSURL *)fileURL;

/// 设置流派
/// - Parameters:
///   - genre: 流派
///   - fileURL: 文件路径
+ (BOOL)setGenre:(NSString *)genre toFileURL:(NSURL *)fileURL;

/// 设置评论
/// - Parameters:
///   - comment: 评论
///   - fileURL: 文件路径
+ (BOOL)setComment:(NSString *)comment toFileURL:(NSURL *)fileURL;

/// 设置音轨顺序
/// - Parameters:
///   - track: 音轨数
///   - fileURL: 文件路径
+ (BOOL)setTrack:(int)track toFileURL:(NSURL *)fileURL;

/// 设置年代
/// - Parameters:
///   - year: 年代
///   - fileURL: 文件路径
+ (BOOL)setYear:(int)year toFileURL:(NSURL *)fileURL;


/// 设置歌词
/// - Parameters:
///   - lyric: 歌词内容
///   - fileURL: 目标文件夹
+ (BOOL)setLyris:(NSString *)lyric toFileURL:(NSURL *)fileURL;

@end

