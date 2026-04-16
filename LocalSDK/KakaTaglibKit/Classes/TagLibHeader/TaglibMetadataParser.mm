//
//  TaglibMetadataParser.m
//  KakaTaglibKit
//
//  Created by 张文 on 11/5/24.
//

#import "TaglibMetadataParser.h"
#import <tag.h>
#import <tstring.h>
#import <fileref.h>
#import <tpropertymap.h>
#import <id3v1tag.h>
#import <id3v2tag.h>
#import <audioproperties.h>
#import <apetag.h>
#import <tvariant.h>
#import <attachedpictureframe.h>

#import <synchronizedlyricsframe.h>
#import <unsynchronizedlyricsframe.h>

#import <apefile.h>
#import <asffile.h>
#import <dsdifffile.h>
#import <dsffile.h>
#import <flacfile.h>
#import <itfile.h>
#import <modfile.h>
#import <mp4file.h>
#import <mpcfile.h>
#import <mpegfile.h>
#import <oggfile.h>
#import <opusfile.h>
#import <speexfile.h>
#import <vorbisfile.h>
#import <rifffile.h>
#import <wavfile.h>
#import <aifffile.h>
#import <s3mfile.h>
#import <apeitem.h>
#import <trueaudiofile.h>
#import <wavpackfile.h>
#import <xmfile.h>


@implementation TaglibMetadataParser

+ (MetadataTagModel *)readMetadataWithFileURL:(NSURL *)fileURL readType:(TaglibReaderType)readType {
    if (!fileURL.isFileURL) {
        NSLog(@"Error: The provided URL is not a file URL.");
        return nil;
    }
    
    const char *filePath = [fileURL.path UTF8String];
    TagLib::FileRef file(filePath);
    
    if (!file.isNull() && file.tag()) {
        
        TagLib::Tag *tag = file.tag();
        
        MetadataTagModel *metadataModel = [[MetadataTagModel alloc] init];
        metadataModel.fileURL = fileURL;
        
        // 1️⃣基础标签
        metadataModel.title = [NSString stringWithCString:tag->title().toCString(true) encoding:NSUTF8StringEncoding];
        metadataModel.artist = [NSString stringWithCString:tag->artist().toCString(true) encoding:NSUTF8StringEncoding];
        metadataModel.album = [NSString stringWithCString:tag->album().toCString(true) encoding:NSUTF8StringEncoding];
        metadataModel.genre = [NSString stringWithCString:tag->genre().toCString(true) encoding:NSUTF8StringEncoding];
        metadataModel.comment = [NSString stringWithCString:tag->comment().toCString(true) encoding:NSUTF8StringEncoding];
        
        metadataModel.year = tag->year();
        metadataModel.track = tag->track();
        
        // 2️⃣获取音频属性（比特率、采样率、时长）
        if (file.audioProperties()) {
            TagLib::AudioProperties *properties = file.audioProperties();
            metadataModel.bitrate = properties->bitrate() * 1000;
            metadataModel.sampleRate = properties->sampleRate();
            metadataModel.durationSeconds = properties->lengthInSeconds();
            metadataModel.channel = properties->channels();
        }
        
        if (readType == TaglibReaderTypeAll) {
            // 封面
            metadataModel.coverArt = [self extractCoverArtFromURL:fileURL];
            
            // 歌词
            metadataModel.lyricModel = [self extractLyricsFromURL:fileURL];
        }else if (readType == TaglibReaderTypeBasicCover) {
            // 封面
            metadataModel.coverArt = [self extractCoverArtFromURL:fileURL];
            
        }else if (readType == TaglibReaderTypeBasic) {
            
        }
        
        return metadataModel;
    } else {
        NSLog(@"Error: Failed to read metadata from file.");
        return nil;
    }
}

/*
 else if (auto itFile = dynamic_cast<TagLib::IT::File *>(file.file())) {
    //        id3v2Tag = itFile->tag();
} else if (auto modFile = dynamic_cast<TagLib::Mod::File *>(file.file())) {
    //        id3v2Tag = modFile->tag();
} else if (auto s3mFile = dynamic_cast<TagLib::S3M::File *>(file.file())) {
    //        id3v2Tag = s3mFile->tag();
} else if (auto xmFile = dynamic_cast<TagLib::XM::File *>(file.file())) {
    //        id3v2Tag = xmFile->tag();
}
*/

// 解析歌词
+ (LyricLineModel *)extractLyricsFromURL:(NSURL *)fileURL {
    
    if (!fileURL.isFileURL) {
        NSLog(@"Error: The provided URL is not a file URL.");
        return nil;
    }
    
    const char *filePath = [fileURL.path UTF8String];
    TagLib::FileRef file(filePath);
    
    if (file.isNull() || !file.tag()) {
        return nil;
    }
    
    LyricLineModel *lyricModel = [LyricLineModel new];
    
    TagLib::ID3v1::Tag *id3v1Tag = nullptr;
    TagLib::ID3v2::Tag *id3v2Tag = nullptr;
    TagLib::APE::Tag *apeTag = nullptr;
    
    if (auto apeFile = dynamic_cast<TagLib::APE::File *>(file.file())) {
        // 7️⃣ APE
        if (apeFile->hasAPETag()) {
            apeTag = apeFile->APETag();
        }else if (apeFile->hasID3v1Tag()) {
            id3v1Tag = apeFile->ID3v1Tag();
        }
    }else if (auto mpegFile = dynamic_cast<TagLib::MPEG::File *>(file.file())) {
        // 1️⃣ MPEG
        if (mpegFile->hasID3v2Tag()) {
            id3v2Tag = mpegFile->ID3v2Tag();
        }else if (mpegFile->hasID3v1Tag()) {
            id3v1Tag = mpegFile->ID3v1Tag();
        }
    } else if (auto flacFile = dynamic_cast<TagLib::FLAC::File *>(file.file())) {
        // 2️⃣ FLAC
        if (flacFile->hasID3v2Tag()) {
            id3v2Tag = flacFile->ID3v2Tag();
        }else if (flacFile->hasXiphComment()){
            if (auto vorbisTag = flacFile->xiphComment()) {
                TagLib::String lyrics = vorbisTag->fieldListMap()["LYRICS"].toString();
                if (!lyrics.isEmpty()) { // 检查歌词是否为空
                    NSString *unsyncedLyrics = [NSString stringWithCString:lyrics.toCString(true) encoding:NSUTF8StringEncoding];
                    lyricModel = [self parseSynchronizedLyrics:unsyncedLyrics];
                }
                
                return lyricModel;
            }
        }else if (flacFile->hasID3v1Tag()) {
            id3v1Tag = flacFile->ID3v1Tag();
        }
    }else if (auto wavFile = dynamic_cast<TagLib::RIFF::WAV::File *>(file.file())) {
        // 3️⃣ WAV
        if (wavFile->hasID3v2Tag()) {
            id3v2Tag = wavFile->ID3v2Tag();
        }else if (auto infoTag = wavFile->InfoTag()) {
            TagLib::String lyrics = infoTag->fieldListMap()["LYRICS"].toCString();
            if (lyrics.isEmpty()) {
                lyrics = infoTag->fieldListMap()["ICMT"].toCString();
                NSString *onString = [NSString stringWithCString:lyrics.toCString(true) encoding:NSUTF8StringEncoding];
                lyricModel = [self parseSynchronizedLyrics:onString];
            }else{
                NSString *unsyncedLyrics = [NSString stringWithCString:lyrics.toCString(true) encoding:NSUTF8StringEncoding];
                lyricModel = [self parseSynchronizedLyrics:unsyncedLyrics];
            }
            
            return lyricModel;
        }
    } else if (auto dsdFile = dynamic_cast<TagLib::DSDIFF::File *>(file.file())) {
        // 4️⃣ DSDIFF
        if (dsdFile->hasID3v2Tag()) {
            id3v2Tag = dsdFile->ID3v2Tag();
        }else if (dsdFile->hasDIINTag()) {
            
        }
    }  else if (auto aiffFile = dynamic_cast<TagLib::RIFF::AIFF::File *>(file.file())) {
        // 5️⃣ AIFF
        if (aiffFile->hasID3v2Tag()) {
            id3v2Tag = aiffFile->tag();
        }
    } else if (auto trueFile = dynamic_cast<TagLib::TrueAudio::File *>(file.file())) {
        // 6️⃣ TrueAudio
        if (trueFile->hasID3v2Tag()) {
            id3v2Tag = trueFile->ID3v2Tag();
        }else if (trueFile->hasID3v1Tag()) {
            id3v1Tag = trueFile->ID3v1Tag();
        }
        
    }else if (auto dsfFile = dynamic_cast<TagLib::DSF::File *>(file.file())) {
        // 7️⃣ DSF
        id3v2Tag = dsfFile->tag();
    } else if (auto mpcFile = dynamic_cast<TagLib::MPC::File *>(file.file())) {
        // 8️⃣ MPC
        if (mpcFile->hasID3v1Tag()) {
            id3v1Tag = mpcFile->ID3v1Tag();
        }
    } else if (auto wavpackFile = dynamic_cast<TagLib::WavPack::File *>(file.file())) {
        // 9️⃣ WavPack
        if (wavpackFile->hasID3v1Tag()) {
            id3v1Tag = wavpackFile->ID3v1Tag();
        }
    }else if (auto mp4File = dynamic_cast<TagLib::MP4::File *>(file.file())) {
        // 1️⃣0️⃣ MP4（ALAC、AAC）
        TagLib::MP4::Tag *mp4Tag = mp4File->tag();
        if (mp4Tag) {
            // 1. 检查标准的©lyr标签
            TagLib::MP4::Item lyricsItem = mp4Tag->item("©lyr");
            if (lyricsItem.isValid() && lyricsItem.toStringList().size() > 0) {
                NSString *lyrics = [NSString stringWithUTF8String:lyricsItem.toStringList().toString().toCString(true)];
                lyricModel = [self parseSynchronizedLyrics:lyrics];
                NSLog(@"✅MP4歌词1 = %@", lyrics);
            } else {
                // 2. 如果©lyr为空，检查自定义标签
                const TagLib::MP4::ItemMap &items = mp4Tag->itemMap();
                for (const auto &itemPair : items) {
                    const TagLib::String &key = itemPair.first;
                    TagLib::MP4::Item item = itemPair.second;

                    NSString *keyString = [NSString stringWithUTF8String:key.toCString(true)];
                    if (item.isValid() && item.toStringList().size() > 0) {
                        NSString *valueString = [NSString stringWithUTF8String:item.toStringList().toString().toCString(true)];
                        if ([keyString isEqualToString:@"©lyr"]) {
                            lyricModel = [self parseSynchronizedLyrics:valueString];
                        }
//                        NSLog(@"✅MP4歌词2 Key: %@, Value: %@", keyString, valueString);
                    }
                }
            }
            
            return lyricModel;
        }
    }else if (auto oggFile = dynamic_cast<TagLib::Ogg::File *>(file.file())) {
        // 1️⃣1️⃣ OGG（Vorbis、Opus、Speex）
        if (auto vorbisTag = dynamic_cast<TagLib::Ogg::Vorbis::File *>(oggFile)) {
                // 处理 Vorbis 格式的 OGG 文件
                if (auto tag = vorbisTag->tag()) {
                    const TagLib::String &lyrics = tag->properties()["LYRICS"].toString();
                    if (!lyrics.isEmpty()) {
                        NSString *lyricsString = [NSString stringWithUTF8String:lyrics.toCString(true)];
//                        NSLog(@"✅OGG Vorbis 歌词 = %@", lyricsString);
                        lyricModel = [self parseSynchronizedLyrics:lyricsString];
                    }
                }
            } else if (auto opusTag = dynamic_cast<TagLib::Ogg::Opus::File *>(oggFile)) {
                // 处理 Opus 格式的 OGG 文件
                if (auto tag = opusTag->tag()) {
                    const TagLib::String &lyrics = tag->properties()["LYRICS"].toString();
                    if (!lyrics.isEmpty()) {
                        NSString *lyricsString = [NSString stringWithUTF8String:lyrics.toCString(true)];
                        NSLog(@"✅OGG Opus 歌词 = %@", lyricsString);
                        lyricModel = [self parseSynchronizedLyrics:lyricsString];
                    }
                }
            } else if (auto speexFile = dynamic_cast<TagLib::Ogg::Speex::File *>(oggFile)) {
                // 处理 Speex 格式的 OGG 文件
                if (auto tag = speexFile->tag()) {
                    const TagLib::String &lyrics = tag->properties()["LYRICS"].toString();
                    if (!lyrics.isEmpty()) {
                        NSString *lyricsString = [NSString stringWithUTF8String:lyrics.toCString(true)];
//                        NSLog(@"✅OGG Speex 歌词 = %@", lyricsString);
                        lyricModel = [self parseSynchronizedLyrics:lyricsString];
                    }
                }
            } else {
                NSLog(@"Unsupported OGG subtype.");
            }
            return lyricModel;
    }else if (auto asfFile = dynamic_cast<TagLib::ASF::File *>(file.file())) {
        // 1️⃣2️⃣ ASF
        const TagLib::ASF::Tag *tag = asfFile->tag();
        const TagLib::ASF::AttributeListMap &attributes = tag->attributeListMap();
        for (const auto &attributePair : attributes) {
            const TagLib::String &key = attributePair.first; // 键名
            const TagLib::ASF::AttributeList &values = attributePair.second; // 值列表

            // 可能的歌词键
            if (key == "WM/LYRICS" || key == "WM/Lyrics") {
                // 取第一个值作为歌词
                if (!values.isEmpty()) {
                    const TagLib::String &lyricString = values.front().toString();
                    NSString *lyrics = [NSString stringWithUTF8String:lyricString.toCString(true)];
//                    NSLog(@"✅ASF 歌词 = %@", lyrics);

                    // 转换为模型格式
                    lyricModel = [self parseSynchronizedLyrics:lyrics];
                    return lyricModel;
                }
            }
        }
    }
//    else if (auto itFile = dynamic_cast<TagLib::IT::File *>(file.file())) {
//        const TagLib::IT::Properties *itProperties = dynamic_cast<const TagLib::IT::Properties *>(itFile->audioProperties());
//
//        if (itProperties && (itProperties->special() & TagLib::IT::Properties::MessageAttached)) {
//            // 检查是否附加了消息
//            TagLib::ByteVector message = itFile->message(); // 获取 IT 文件的 Message 字段
//            if (!message.isEmpty()) {
//                // 转换 Message 字段为 NSString 格式
//                NSString *lyrics = [NSString stringWithUTF8String:message.toCString()];
//                lyricModel = [self parseSynchronizedLyrics:lyrics];
//                NSLog(@"✅ IT 文件解析歌词: %@", lyrics);
//            } else {
//                NSLog(@"❌ IT 文件的 Message 字段为空。");
//            }
//        } else {
//            NSLog(@"❌ IT 文件没有附加消息字段。");
//        }
//    }

    
    
    // 解析IDV2标签的数据
    if (id3v2Tag) {
        const TagLib::String &lyrics = id3v2Tag->properties()["LYRICS"].toString();
        if (!lyrics.isEmpty()) {
            NSString *lyricsString = [NSString stringWithUTF8String:lyrics.toCString(true)];
//            NSLog(@"✅IDV2 歌词 = %@", lyricsString);
            lyricModel = [self parseSynchronizedLyrics:lyricsString];
            return lyricModel;
        }
        
        // 1.1 读取 SYLT 框架（同步歌词）
        auto syltFrames = id3v2Tag->frameList("SYLT");
        if (!syltFrames.isEmpty()) {
            if (auto syltFrame = dynamic_cast<TagLib::ID3v2::SynchronizedLyricsFrame *>(syltFrames.front())) {
                const auto &lyricsList = syltFrame->synchedText();
                
                for (size_t i = 0; i < lyricsList.size(); ++i) {
                    const auto &lyricEntry = lyricsList[i];
                    
                    NSMutableArray <LyricInfo *>*lyricArray = [NSMutableArray array];
                    if (!lyricEntry.text.isEmpty()) { // 检查歌词是否为空
                        
                        lyricModel.isNoneTime = NO;

                        LyricInfo *info = [LyricInfo new];
                        NSString *fullLyric = [NSString stringWithCString:lyricEntry.text.toCString(true) encoding:NSUTF8StringEncoding];
                        
                        info.fullLyric = fullLyric;
                        info.realLyric = fullLyric;
                        info.startTimestamp = lyricEntry.time; // 毫秒
                        
                        if (i + 1 < lyricsList.size()) {
                            info.endTimestamp = lyricsList[i + 1].time; // 下一行的开始时间作为结束时间
                        } else {
                            info.endTimestamp = lyricArray.lastObject.startTimestamp + 3000.0;
                        }
                        
                        [lyricArray addObject:info];
                    }
                    lyricModel.lyrics = lyricArray;
                }
            }
            
            return lyricModel;
        }
        
        
        // 1.2 读取 USLT 框架（非同步歌词），如果没有找到 SYLT 同步歌词
        if ((lyricModel.lyrics.count) == 0) {
            auto usltFrames = id3v2Tag->frameList("USLT");
            if (!usltFrames.isEmpty()) {
                if (auto usltFrame = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame *>(usltFrames.front())) {
                    TagLib::String lyricsText = usltFrame->text();
                    if (!lyricsText.isEmpty()) { // 检查歌词是否为空
                        NSString *lyricStr = [NSString stringWithCString:lyricsText.toCString(true) encoding:NSUTF8StringEncoding];
                        lyricModel = [self parseSynchronizedLyrics:lyricStr];
                    }
                }
            }
            
            return lyricModel;
        }
        
    }
    
    if (apeTag) {
        // 尝试读取歌词字段
        TagLib::String lyrics = apeTag->itemListMap().value("LYRICS").toString();
        if (lyrics.isEmpty()) {
            lyrics = apeTag->itemListMap().value("LYRICS_UNSYNCR").toString();
        }
        
        if (!lyrics.isEmpty()) {
            NSString *lyricStr = [NSString stringWithCString:lyrics.toCString(true) encoding:NSUTF8StringEncoding];
            lyricModel = [self parseSynchronizedLyrics:lyricStr];
            NSLog(@"✅ APE 歌词 = %@", lyricStr);
        }
        
        return lyricModel;
    }

    
    // 最后才尝试IDV1标签
    if (id3v1Tag) {
        // 1. IDV1读取评论数据
        TagLib::String lyricsText = id3v1Tag->comment();
        if (!lyricsText.isEmpty()) { // 检查歌词是否为空
            NSString *lyricStr = [NSString stringWithCString:lyricsText.toCString(true) encoding:NSUTF8StringEncoding];
            lyricModel = [self parseSynchronizedLyrics:lyricStr];
        }
        
        return lyricModel;
    }
    
    return lyricModel;
}



/// 读取封面
+ (KakaImage *)extractCoverArtFromURL:(NSURL *)fileURL {
    if (!fileURL.isFileURL) {
        NSLog(@"Error: The provided URL is not a file URL.");
        return nil;
    }
    
    const char *filePath = [fileURL.path UTF8String];
    TagLib::FileRef file(filePath);
    
    if (!file.isNull() && file.tag()) {
        TagLib::Tag *tag = file.tag();
        
        // 尝试从文件的元数据中获取封面图
        TagLib::PropertyMap properties = file.properties();
        TagLib::StringList names = file.complexPropertyKeys();
        
        KakaImage *coverImage;
        
        for (const auto &name : names) {
            const auto& propertiesList = file.complexProperties(name);
            for (const auto &property : propertiesList) {
                for (const auto &[key, value] : property) {
                    
                    if (value.type() == TagLib::Variant::ByteVector) {
                        // 获取封面图字节流
                        TagLib::ByteVector pictureData = value.value<TagLib::ByteVector>();
                        NSData *imageData = [NSData dataWithBytes:pictureData.data() length:pictureData.size()];
#if TARGET_OS_OSX
                        coverImage = [[NSImage alloc] initWithData:imageData];
#else
                        coverImage = [UIImage imageWithData:imageData];
#endif
                        break;
                    }
                    
                }
            }
        }
        
        return coverImage;
    }else{
        NSLog(@"Error: Failed to extract cover art from the file.");
        return nil;  // 如果没有封面图，返回 nil
    }
    
}


/*
 1. [分钟:秒.毫秒] 歌词
 2. [分钟:秒] 歌词
 3. [分钟:秒:毫秒] 歌词
 */
+ (LyricLineModel *)parseSynchronizedLyrics:(NSString *)lyricsText {
    if (lyricsText.length < 3) {
        return nil;
    }
    
    NSMutableArray<LyricInfo *> *lyricArray = [NSMutableArray array];
    NSArray<NSString *> *lines = [lyricsText componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    // 支持更广泛时间戳格式的正则表达式
    NSRegularExpression *timeRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[(\\d{2}):(\\d{2})(\\.\\d+)?\\]|\\[(\\d{2})\\.(\\d+)\\]" options:0 error:nil];
    
    LyricLineModel *lyricModel = [[LyricLineModel alloc] init];
    
    for (NSString *line in lines) {
        if ([line isEqualToString:@""] || line.length == 0) {
            continue;
        }
        
        // 处理文件标签
        if ([line hasPrefix:@"[ar:"]) {
            lyricModel.artist = [line substringWithRange:NSMakeRange(4, line.length - 5)];
        } else if ([line hasPrefix:@"[ti:"]) {
            lyricModel.title = [line substringWithRange:NSMakeRange(4, line.length - 5)];
        } else if ([line hasPrefix:@"[al:"]) {
            lyricModel.album = [line substringWithRange:NSMakeRange(4, line.length - 5)];
        } else if ([line hasPrefix:@"[by:"]) {
            lyricModel.creater = [line substringWithRange:NSMakeRange(4, line.length - 5)];
        } else if ([line hasPrefix:@"offset:"]) {
            lyricModel.offset = [[line substringFromIndex:7] doubleValue]; // 转换为毫秒
        } else if ([line hasPrefix:@"[offset:"]) {
            lyricModel.offset = [[line substringFromIndex:8] doubleValue]; // 转换为毫秒
        } else if ([line hasPrefix:@"t_time:"] || [line hasPrefix:@"[t_time:"]) {
            BOOL isSeconds = [line containsString:@"[t_time"];
            int count = isSeconds ? 8 : 7;
            lyricModel.totalTime = [[line substringFromIndex:count] doubleValue] * (isSeconds ? 1 : 1000); // 总时长毫秒
        } else if ([line hasPrefix:@"[kuwo:"] || [line hasPrefix:@"[ver:"] || [line isEqualToString:@"[offset:0]"]) {
            // 过滤掉无用标签
        } else {
            NSArray<NSTextCheckingResult *> *matches = [timeRegex matchesInString:line options:0 range:NSMakeRange(0, line.length)];
            
            LyricInfo *lyric = [[LyricInfo alloc] init];
            
            if (matches.count == 0) {
                // 处理无时间戳的歌词
                lyricModel.isNoneTime = YES;
                lyric.fullLyric = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                [lyricArray addObject:lyric];
                continue;
            } else {
                // 处理带时间戳的歌词
                lyricModel.isNoneTime = NO;
                NSMutableArray<NSNumber *> *parsedTimes = [NSMutableArray array];
                for (NSTextCheckingResult *match in matches) {
                    double time = 0.0;
                    
                    if ([match rangeAtIndex:1].location != NSNotFound) { // [mm:ss(.sss)] 格式
                        NSString *minute = [line substringWithRange:[match rangeAtIndex:1]];
                        NSString *second = [line substringWithRange:[match rangeAtIndex:2]];
                        NSString *fraction = ([match rangeAtIndex:3].location != NSNotFound) ? [line substringWithRange:[match rangeAtIndex:3]] : @"";
                        time = (minute.doubleValue * 60) + second.doubleValue + fraction.doubleValue;
                    } else if ([match rangeAtIndex:4].location != NSNotFound) { // [mm.ss(.sss)] 格式
                        NSString *minute = [line substringWithRange:[match rangeAtIndex:4]];
                        NSString *secondFraction = [line substringWithRange:[match rangeAtIndex:5]];
                        time = minute.doubleValue * 60 + secondFraction.doubleValue / pow(10, secondFraction.length);
                    }
                    
                    [parsedTimes addObject:@(time)];
                }
                
                // 设置开始时间和结束时间
                if (parsedTimes.count > 0) {
                    lyric.startTimestamp = parsedTimes[0].doubleValue * 1000;
                    if (parsedTimes.count > 1) {
                        lyric.endTimestamp = parsedTimes[1].doubleValue * 1000; // 下一个时间戳作为结束时间
                    } else {
                        lyric.endTimestamp = lyric.startTimestamp + 3000.0; // 假设持续时间为3秒
                    }
                }
                
                // 提取歌词文本
                NSRange lastMatchRange = matches.lastObject.range;
                NSString *lyricText = [line substringFromIndex:NSMaxRange(lastMatchRange)];
                lyric.fullLyric = [lyricText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            }
            
            NSString *fullLyric = [lyric.fullLyric stringByReplacingOccurrencesOfString:@" " withString:@""];
            if (fullLyric.length > 0) {
                [lyricArray addObject:lyric];
            }
        }
    }
    
    lyricModel.lyrics = lyricArray;
    return lyricModel;
}



+ (BOOL)setTitle:(NSString *)title toFileURL:(NSURL *)fileURL {
    const char *filePath = [fileURL.path UTF8String];
    TagLib::FileRef file(filePath);
    if (file.isNull() || !file.tag()) {
        NSLog(@"Error: Unable to access file or tag.");
        return NO;
    }
    
    TagLib::String tagTitle(title.UTF8String, TagLib::String::UTF8);

    file.tag()->setTitle(tagTitle);
    bool success = file.save();
    return success;
}

+ (BOOL)setArtist:(NSString *)artist toFileURL:(NSURL *)fileURL {
    const char *filePath = [fileURL.path UTF8String];
    TagLib::FileRef file(filePath);
    if (file.isNull() || !file.tag()) {
        NSLog(@"Error: Unable to access file or tag.");
        return NO;
    }

    TagLib::String tagTitle(artist.UTF8String, TagLib::String::UTF8);

    file.tag()->setArtist(tagTitle);
    bool success = file.save();
    return success;
}

+ (BOOL)setAlbum:(NSString *)album toFileURL:(NSURL *)fileURL {
    const char *filePath = [fileURL.path UTF8String];
    TagLib::FileRef file(filePath);
    if (file.isNull() || !file.tag()) {
        NSLog(@"Error: Unable to access file or tag.");
        return NO;
    }

    TagLib::String tagTitle(album.UTF8String, TagLib::String::UTF8);

    file.tag()->setAlbum(tagTitle);
    bool success = file.save();
    return success;
}

+ (BOOL)setComment:(NSString *)comment toFileURL:(NSURL *)fileURL {
    const char *filePath = [fileURL.path UTF8String];
    TagLib::FileRef file(filePath);
    if (file.isNull() || !file.tag()) {
        NSLog(@"Error: Unable to access file or tag.");
        return NO;
    }

    TagLib::String tagTitle(comment.UTF8String, TagLib::String::UTF8);

    file.tag()->setComment(tagTitle);
    bool success = file.save();
    return success;
}

+ (BOOL)setTrack:(int)track toFileURL:(NSURL *)fileURL {
    const char *filePath = [fileURL.path UTF8String];
    TagLib::FileRef file(filePath);
    if (file.isNull() || !file.tag()) {
        NSLog(@"Error: Unable to access file or tag.");
        return NO;
    }

    file.tag()->setTrack(track);
    bool success = file.save();
    return success;
}

+ (BOOL)setYear:(int)year toFileURL:(NSURL *)fileURL {
    const char *filePath = [fileURL.path UTF8String];
    TagLib::FileRef file(filePath);
    if (file.isNull() || !file.tag()) {
        NSLog(@"Error: Unable to access file or tag.");
        return NO;
    }

    file.tag()->setYear(year);
    bool success = file.save();
    return success;
}

+ (BOOL)setGenre:(NSString *)genre toFileURL:(NSURL *)fileURL {
    const char *filePath = [fileURL.path UTF8String];
    TagLib::FileRef file(filePath);
    if (file.isNull() || !file.tag()) {
        NSLog(@"Error: Unable to access file or tag.");
        return NO;
    }

    TagLib::String tagTitle(genre.UTF8String, TagLib::String::UTF8);

    file.tag()->setGenre(tagTitle);
    bool success = file.save();
    return success;
}

+ (BOOL)setCoverArt:(KakaImage *)coverImage toFileURL:(NSURL *)fileURL {
    if (!fileURL.isFileURL) {
        NSLog(@"Error: The provided URL is not a file URL.");
        return NO;
    }
    
    const char *filePath = [fileURL.path UTF8String];
    TagLib::FileRef file(filePath);

    if (file.isNull() || !file.tag()) {
        NSLog(@"Error: Unable to access file or tag.");
        return NO;
    }
    
#if TARGET_OS_OSX
    // macOS 适配
    NSBitmapImageRep *bitmapRep = [coverImage representations].firstObject;
    NSData *imageData = [bitmapRep representationUsingType:NSBitmapImageFileTypeJPEG properties:@{NSImageCompressionFactor: @(0.1)}];
#else
    // iOS 版本
    NSData *imageData = UIImageJPEGRepresentation(coverImage, 0.1);
#endif
    
    // 构建封面数据的 VariantMap，仅包含 data 键
    TagLib::VariantMap pictureProperty;
    pictureProperty["data"] = TagLib::ByteVector((const char *)[imageData bytes], [imageData length]);

    TagLib::List<TagLib::VariantMap> pictureList;
    pictureList.append(pictureProperty);
    
    bool isSuccess = false;
        
    if (auto mpegFile = dynamic_cast<TagLib::MPEG::File *>(file.file())) {
        isSuccess = mpegFile->setComplexProperties("PICTURE", pictureList);
        mpegFile->save();
    } else if (auto flacFile = dynamic_cast<TagLib::FLAC::File *>(file.file())) {
        isSuccess = flacFile->setComplexProperties("PICTURE", pictureList);
        flacFile->save();
    } else if (auto dsdiffFile = dynamic_cast<TagLib::DSDIFF::File *>(file.file())) {
        isSuccess = dsdiffFile->setComplexProperties("PICTURE", pictureList);
        dsdiffFile->save();
    } else if (auto trueFile = dynamic_cast<TagLib::TrueAudio::File *>(file.file())) {
        isSuccess = trueFile->setComplexProperties("PICTURE", pictureList);
        trueFile->save();
    } else if (auto riffFile = dynamic_cast<TagLib::RIFF::AIFF::File *>(file.file())) {
        isSuccess = riffFile->setComplexProperties("PICTURE", pictureList);
        riffFile->save();
    } else if (auto dsdiffFile = dynamic_cast<TagLib::DSDIFF::File *>(file.file())) {
        isSuccess = dsdiffFile->setComplexProperties("PICTURE", pictureList);
        dsdiffFile->save();
    } else if (auto dsfFile = dynamic_cast<TagLib::DSF::File *>(file.file())) {
        isSuccess = dsfFile->setComplexProperties("PICTURE", pictureList);
        dsfFile->save();
    } else if (auto wavFile = dynamic_cast<TagLib::RIFF::WAV::File *>(file.file())) {
        isSuccess = wavFile->setComplexProperties("PICTURE", pictureList);
        wavFile->save();
    } else if (auto aiffFile = dynamic_cast<TagLib::RIFF::AIFF::File *>(file.file())) {
        isSuccess = aiffFile->setComplexProperties("PICTURE", pictureList);
        aiffFile->save();
    } else if (auto apeFile = dynamic_cast<TagLib::APE::File *>(file.file())) {
        isSuccess = apeFile->setComplexProperties("PICTURE", pictureList);
        apeFile->save();
    } else if (auto asfFile = dynamic_cast<TagLib::ASF::File *>(file.file())) {
        isSuccess = asfFile->setComplexProperties("PICTURE", pictureList);
        asfFile->save();
    } else if (auto oggFile = dynamic_cast<TagLib::Ogg::File *>(file.file())) {
        isSuccess = oggFile->setComplexProperties("PICTURE", pictureList);
        oggFile->save();
    } else if (auto wavpackFile = dynamic_cast<TagLib::WavPack::File *>(file.file())) {
        isSuccess = wavpackFile->setComplexProperties("PICTURE", pictureList);
        wavpackFile->save();
    } else if (auto xmFile = dynamic_cast<TagLib::XM::File *>(file.file())) {
        isSuccess = xmFile->setComplexProperties("PICTURE", pictureList);
        xmFile->save();
    } else if (auto s3mFile = dynamic_cast<TagLib::S3M::File *>(file.file())) {
        isSuccess = s3mFile->setComplexProperties("PICTURE", pictureList);
        s3mFile->save();
    } else if (auto itFile = dynamic_cast<TagLib::IT::File *>(file.file())) {
        isSuccess = itFile->setComplexProperties("PICTURE", pictureList);
        itFile->save();
    } else if (auto mpcFile = dynamic_cast<TagLib::MPC::File *>(file.file())) {
        isSuccess = mpcFile->setComplexProperties("PICTURE", pictureList);
        mpcFile->save();
    } else if (auto modFile = dynamic_cast<TagLib::Mod::File *>(file.file())) {
        isSuccess = modFile->setComplexProperties("PICTURE", pictureList);
        modFile->save();
    } else if (auto mp4File = dynamic_cast<TagLib::MP4::File *>(file.file())) {
        isSuccess = mp4File->setComplexProperties("PICTURE", pictureList);
        mp4File->save();
    }
    
    
    if (isSuccess) {
        return isSuccess;
    }else{
        if (file.tag()->setComplexProperties("PICTURE", pictureList)) {
            file.save();
            return YES;
        }else{
            NSLog(@"Error: Failed to set cover art.");
            return NO;
        }
    }

}

/// 写入歌词
+ (BOOL)setLyris:(NSString *)lyric toFileURL:(NSURL *)fileURL {
    if (!fileURL.isFileURL) {
        NSLog(@"Error: The provided URL is not a file URL.");
        return NO;
    }
    
    const char *filePath = [fileURL.path UTF8String];
    TagLib::FileRef file(filePath);
    
    if (file.isNull() || !file.tag()) {
        NSLog(@"Error: Unable to read the file or tag.");
        return NO;
    }
    
    // 识别文件类型并获取相应的标签
    TagLib::ID3v1::Tag *id3v1Tag = nullptr;
    TagLib::ID3v2::Tag *id3v2Tag = nullptr;
    TagLib::APE::Tag *apeTag = nullptr;
    
    TagLib::String lyricsTag(lyric.UTF8String, TagLib::String::UTF8);
    
    if (auto apeFile = dynamic_cast<TagLib::APE::File *>(file.file())) {
        // 7️⃣ APE
        if (apeFile->hasAPETag()) {
            apeTag = apeFile->APETag();
        }else if (apeFile->hasID3v1Tag()) {
            id3v1Tag = apeFile->ID3v1Tag();
        }
    }else if (auto mpegFile = dynamic_cast<TagLib::MPEG::File *>(file.file())) {
        // 1️⃣ MPEG
        if (mpegFile->hasID3v2Tag()) {
            id3v2Tag = mpegFile->ID3v2Tag();
        }else if (mpegFile->hasID3v1Tag()) {
            id3v1Tag = mpegFile->ID3v1Tag();
        }
    } else if (auto flacFile = dynamic_cast<TagLib::FLAC::File *>(file.file())) {
        // 2️⃣ FLAC
        if (flacFile->hasID3v2Tag()) {
            id3v2Tag = flacFile->ID3v2Tag();
        }else if (flacFile->hasXiphComment()){
            if (auto vorbisTag = flacFile->xiphComment()) {
                vorbisTag->removeFields("LYRICS");
                vorbisTag->addField("LYRICS", lyricsTag);
                
                bool success = file.save();
                return success;
            }
        }else if (flacFile->hasID3v1Tag()) {
            id3v1Tag = flacFile->ID3v1Tag();
        }
    }else if (auto wavFile = dynamic_cast<TagLib::RIFF::WAV::File *>(file.file())) {
        // 3️⃣ WAV
        if (wavFile->hasID3v2Tag()) {
            id3v2Tag = wavFile->ID3v2Tag();
        }else if (auto infoTag = wavFile->InfoTag()) {
            infoTag->fieldListMap()["LYRICS"] = lyricsTag;
            // 保存文件
            bool success = file.save();
            return success;
        }
    } else if (auto mp4File = dynamic_cast<TagLib::MP4::File *>(file.file())) {
        // 4️⃣ MP4
        TagLib::MP4::Tag *mp4Tag = mp4File->tag();
        mp4Tag->setItem("\251lyr", TagLib::MP4::Item(lyricsTag));
        bool success = mp4File->save();
        return success;
    } else if (auto dsdFile = dynamic_cast<TagLib::DSDIFF::File *>(file.file())) {
        // 5️⃣ DSDIFF
        if (dsdFile->hasID3v2Tag()) {
            id3v2Tag = dsdFile->ID3v2Tag();
        }
    }  else if (auto aiffFile = dynamic_cast<TagLib::RIFF::AIFF::File *>(file.file())) {
        // 6️⃣ AIFF
        if (aiffFile->hasID3v2Tag()) {
            id3v2Tag = aiffFile->tag();
        }
    } else if (auto trueFile = dynamic_cast<TagLib::TrueAudio::File *>(file.file())) {
        // 7️⃣ TrueAudio
        if (trueFile->hasID3v2Tag()) {
            id3v2Tag = trueFile->ID3v2Tag();
        }else if (trueFile->hasID3v1Tag()) {
            id3v1Tag = trueFile->ID3v1Tag();
        }
        
    } else if (auto dsfFile = dynamic_cast<TagLib::DSF::File *>(file.file())) {
        // 8️⃣ DSF
        id3v2Tag = dsfFile->tag();
    } else if (auto mpcFile = dynamic_cast<TagLib::MPC::File *>(file.file())) {
        // 9️⃣ MPC
        if (mpcFile->hasID3v1Tag()) {
            id3v1Tag = mpcFile->ID3v1Tag();
        }
    } else if (auto wavpackFile = dynamic_cast<TagLib::WavPack::File *>(file.file())) {
        // 1️⃣0️⃣ WavPack
        if (wavpackFile->hasID3v1Tag()) {
            id3v1Tag = wavpackFile->ID3v1Tag();
        }
    } else if (auto oggFile = dynamic_cast<TagLib::Ogg::File *>(file.file())) {
        // 1️⃣1️⃣ OGG(Opus、Opus、Speex)
        if (auto vorbisFile = dynamic_cast<TagLib::Ogg::Vorbis::File *>(oggFile)) {
            // Vorbis 格式
            if (auto tag = vorbisFile->tag()) {
                tag->addField("LYRICS", lyricsTag, true); // 添加或更新歌词字段
                bool success = file.save();
                NSLog(@"✅OGG Vorbis 写入歌词 = %@", @(success));
                return success;
            }
        } else if (auto opusFile = dynamic_cast<TagLib::Ogg::Opus::File *>(oggFile)) {
            // Opus 格式
            if (auto tag = opusFile->tag()) {
                tag->addField("LYRICS", lyricsTag, true); // 添加或更新歌词字段
                bool success = file.save();
                NSLog(@"✅OGG Opus 写入歌词 = %@", @(success));
                return success;
            }
        } else if (auto speexFile = dynamic_cast<TagLib::Ogg::Speex::File *>(oggFile)) {
            // Speex 格式
            if (auto tag = speexFile->tag()) {
                tag->addField("LYRICS", lyricsTag, true); // 添加或更新歌词字段
                bool success = file.save();
                NSLog(@"✅OGG Speex 写入歌词 = %@", @(success));
                return success;
            }
        } else {
            return NO;
            NSLog(@"Unsupported OGG subtype for writing lyrics.");
        }
    }else if (auto asfFile = dynamic_cast<TagLib::ASF::File *>(file.file())) {
        // 1️⃣2️⃣ ASF
        TagLib::ASF::Tag *tag = asfFile->tag();
        if (tag) {
            // 写入歌词到 WM/LYRICS 字段
            TagLib::ASF::Attribute lyricsAttribute(lyricsTag);

            // 设置到自定义属性 WM/LYRICS
            tag->setAttribute("WM/LYRICS", lyricsAttribute);

            // 保存文件
            bool success = asfFile->save();
            NSLog(@"ASF 写入歌词成功: %@", @(success));
            return success;
        }
    }
    
    // 写入歌词逻辑
    if (id3v2Tag) {
        // 检查是否已有 USLT 框架，若有则移除，避免重复
        auto usltFrames = id3v2Tag->frameList("USLT");
        
        if (!usltFrames.isEmpty()) {
            // 如果存在 "USLT"，移除旧的框架并写入新的歌词
            for (auto frame : usltFrames) {
                id3v2Tag->removeFrame(frame);
            }
            
            // 创建新的 USLT 框架并设置歌词文本
            auto usltFrame = new TagLib::ID3v2::UnsynchronizedLyricsFrame();
            usltFrame->setText(lyricsTag);
            
            // 将新的 USLT 框架添加到 ID3v2 标签中
            id3v2Tag->addFrame(usltFrame);
        }else{
            // 如果不存在 "USLT"，写入到 "LYRICS" 属性
            TagLib::PropertyMap properties = id3v2Tag->properties();
            properties.replace("LYRICS", lyricsTag);
            id3v2Tag->setProperties(properties);
            NSLog(@"✅ 写入到 LYRICS 属性");
        }
                
        // 保存文件
        bool success = file.save();
        return success;
                    
    } else if (apeTag) {
        // 设置APE歌词
        TagLib::APE::Item lyricItem("LYRICS", TagLib::StringList{lyricsTag});
        apeTag->setItem(lyricItem.key(), lyricItem);
        
        // 保存文件
        bool success = file.save();
        return success;
    } else if (id3v1Tag) {
        // 写入 ID3v1 标签的评论
        id3v1Tag->setComment(lyricsTag);
        
        // 保存文件
        bool success = file.save();
        return success;
    }else{
        return NO;
    }
    
}


@end


