// WaketagLibKit — Apple-platform wrapper around TagLib.
#import "TaglibMetadataParser.h"
#import <ImageIO/ImageIO.h>
#include <fileref.h>
#include <tpropertymap.h>
#include <tvariant.h>
#include <id3v2tag.h>
#include <id3v1tag.h>
#include <synchronizedlyricsframe.h>
#include <unsynchronizedlyricsframe.h>
#include <mpegfile.h>
#include <mpegproperties.h>
#include <flacfile.h>
#include <xiphcomment.h>
#include <wavfile.h>
#include <infotag.h>
#include <aifffile.h>
#include <dsffile.h>
#include <dsdifffile.h>
#include <trueaudiofile.h>
#include <apefile.h>
#include <apetag.h>
#include <apeitem.h>
#include <mp4tag.h>
#include <asftag.h>
#include <asfattribute.h>
#include <modtag.h>
#include <matroskatag.h>
#include <mpcfile.h>
#include <wavpackfile.h>
#include <array>
#include <mutex>
#include <algorithm>
#include <climits>
#include <cmath>
#include <cstring>

namespace {
constexpr NSUInteger MaxArtworkBytes = 32 * 1024 * 1024;
constexpr NSUInteger MaxLyricsBytes = 4 * 1024 * 1024;
constexpr NSUInteger MaxLyricLines = 20000;

// Bound lock memory during large scans; serialize edits/reads of the same path.
std::array<std::mutex, 64> fileLocks;
class FileAccess {
public:
    explicit FileAccess(NSURL *url) : url_(url), scoped_(url && url.isFileURL && [url startAccessingSecurityScopedResource]) {}
    ~FileAccess() { if(scoped_) [url_ stopAccessingSecurityScopedResource]; }
private:
    NSURL *__strong url_;
    bool scoped_;
};

template<typename Result, typename Action>
Result WithFile(NSURL *url, bool writing, bool audioProperties, Result failure, Action action) {
    if(!url || !url.isFileURL || !url.path.length) return failure;
    FileAccess access(url);
    NSURL *canonical = url.URLByResolvingSymlinksInPath.URLByStandardizingPath;
    std::lock_guard<std::mutex> lock(fileLocks[canonical.path.hash % fileLocks.size()]);
    NSNumber *regular = nil;
    if(![canonical getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil] || !regular.boolValue) return failure;
    NSNumber *fileSize = nil;
    if(![canonical getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil] || fileSize.unsignedLongLongValue == 0) return failure;
    if(writing && ![[NSFileManager defaultManager] isWritableFileAtPath:canonical.path]) return failure;
    const char *path = canonical.fileSystemRepresentation;
    if(!path) return failure;
    try {
        TagLib::FileRef file(path, audioProperties || writing, TagLib::AudioProperties::Average);
        if(file.isNull() || !file.file()->isValid() || !file.tag() || (writing && file.file()->readOnly())) return failure;
        // Tracker tags silently ignore most setters. Read them, but do not
        // report a successful edit when the format cannot store the field.
        if(writing && dynamic_cast<TagLib::Mod::Tag *>(file.tag())) return failure;
        // TagLib accepts empty/tag-only MPEG containers; these are not audio
        // files and must not be "repaired" into a successful tag write.
        if(auto mpeg = dynamic_cast<TagLib::MPEG::File *>(file.file()); mpeg && mpeg->firstFrameOffset() < 0) return failure;
        if(dynamic_cast<TagLib::RIFF::WAV::File *>(file.file()) || dynamic_cast<TagLib::RIFF::AIFF::File *>(file.file())) {
            if(audioProperties || writing) {
                auto props = file.audioProperties();
                if(!props || props->sampleRate() <= 0 || props->channels() <= 0) return failure;
            }
        }
        return action(file);
    } catch(const std::exception &) { return failure; }
      catch(...) { return failure; }
}

NSString *StringFromTag(const TagLib::String &value) {
    const auto utf8 = value.to8Bit(true);
    return [[NSString alloc] initWithBytes:utf8.data() length:utf8.size() encoding:NSUTF8StringEncoding] ?: @"";
}
TagLib::String StringToTag(NSString *value) {
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    if(!data.length) return TagLib::String();
    return TagLib::String(std::string(static_cast<const char *>(data.bytes), data.length), TagLib::String::UTF8);
}
double FiniteNumber(NSString *value) {
    double number = value.doubleValue;
    return std::isfinite(number) ? number : 0;
}
bool Save(TagLib::FileRef &file, bool id3Only = false) {
    if(id3Only) {
        if(auto f = dynamic_cast<TagLib::MPEG::File *>(file.file()))
            return f->save(TagLib::MPEG::File::ID3v2, TagLib::File::StripNone,
                           TagLib::ID3v2::v4, TagLib::File::DoNotDuplicate);
    }
    if(auto flac = dynamic_cast<TagLib::FLAC::File *>(file.file())) {
        // FLAC uses a 24-bit metadata-block length. Upstream drops an
        // oversized block while still returning success; refuse before save.
        constexpr unsigned int MaxFLACBlockBytes = 0xFFFFFF;
        if(auto xiph = flac->xiphComment(false); xiph && xiph->render(false).size() > MaxFLACBlockBytes) return false;
        for(auto picture : flac->pictureList())
            if(picture->render().size() > MaxFLACBlockBytes) return false;
    }
    TagLib::ID3v1::Tag *legacy = nullptr;
    if(auto f = dynamic_cast<TagLib::MPEG::File *>(file.file())) legacy = f->ID3v1Tag(false);
    else if(auto f = dynamic_cast<TagLib::FLAC::File *>(file.file())) legacy = f->ID3v1Tag(false);
    else if(auto f = dynamic_cast<TagLib::APE::File *>(file.file())) legacy = f->ID3v1Tag(false);
    else if(auto f = dynamic_cast<TagLib::MPC::File *>(file.file())) legacy = f->ID3v1Tag(false);
    else if(auto f = dynamic_cast<TagLib::WavPack::File *>(file.file())) legacy = f->ID3v1Tag(false);
    else if(auto f = dynamic_cast<TagLib::TrueAudio::File *>(file.file())) legacy = f->ID3v1Tag(false);
    // TagLib serializes ID3v1.1 with only 28 comment characters. Refuse an
    // unsafe legacy rewrite instead of silently losing a v1.0 comment tail.
    if(legacy && legacy->track() == 0 && legacy->comment().size() > 28) return false;
    // Default MPEG save duplicates ID3v2 into ID3v1, potentially overwriting
    // unrelated fields. Preserve independent containers instead.
    if(auto f = dynamic_cast<TagLib::MPEG::File *>(file.file()))
        return f->save(TagLib::MPEG::File::AllTags, TagLib::File::StripNone,
                       TagLib::ID3v2::v4, TagLib::File::DoNotDuplicate);
    return file.save();
}
TagLib::ID3v2::Tag *ID3Tag(TagLib::FileRef &file, bool create) {
    if(auto f = dynamic_cast<TagLib::MPEG::File *>(file.file())) return f->ID3v2Tag(create);
    if(auto f = dynamic_cast<TagLib::RIFF::WAV::File *>(file.file())) return f->ID3v2Tag();
    if(auto f = dynamic_cast<TagLib::RIFF::AIFF::File *>(file.file())) return f->tag();
    if(auto f = dynamic_cast<TagLib::DSF::File *>(file.file())) return f->tag();
    if(auto f = dynamic_cast<TagLib::DSDIFF::File *>(file.file())) return f->ID3v2Tag(create);
    if(auto f = dynamic_cast<TagLib::TrueAudio::File *>(file.file())) return f->ID3v2Tag(create);
    if(auto f = dynamic_cast<TagLib::FLAC::File *>(file.file())) return f->ID3v2Tag(false);
    return nullptr;
}
TagLib::Tag *NativeLyricsTag(TagLib::FileRef &file, bool create) {
    if(auto f = dynamic_cast<TagLib::FLAC::File *>(file.file())) return f->xiphComment(create);
    if(auto f = dynamic_cast<TagLib::APE::File *>(file.file())) return f->APETag(create);
    if(auto f = dynamic_cast<TagLib::MPC::File *>(file.file())) return f->APETag(create);
    if(auto f = dynamic_cast<TagLib::WavPack::File *>(file.file())) return f->APETag(create);
    if(auto tag = ID3Tag(file, create)) return tag;
    return file.tag();
}
void FinishTimedLyrics(NSMutableArray<LyricInfo *> *lines) {
    [lines sortUsingComparator:^NSComparisonResult(LyricInfo *a, LyricInfo *b) {
        if(a.startTimestamp == b.startTimestamp) return NSOrderedSame;
        return a.startTimestamp < b.startTimestamp ? NSOrderedAscending : NSOrderedDescending;
    }];
    // Equal timestamps share the next distinct time; linear even for duplicates.
    NSTimeInterval nextTime = 0, previousTime = -1;
    for(NSInteger index = (NSInteger)lines.count - 1; index >= 0; --index) {
        LyricInfo *line = lines[(NSUInteger)index];
        if(previousTime < 0) nextTime = line.startTimestamp + 3000;
        else if(line.startTimestamp < previousTime) nextTime = previousTime;
        line.endTimestamp = nextTime;
        previousTime = line.startTimestamp;
    }
}
LyricLineModel *UsableLyrics(NSString *text, bool timedOnly = false) {
    LyricLineModel *lyrics = [TaglibMetadataParser parseSynchronizedLyrics:text];
    if(timedOnly && lyrics.isNoneTime) return nil;
    static NSRegularExpression *brokenTimeOnly;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        brokenTimeOnly = [NSRegularExpression regularExpressionWithPattern:@"^(?:\\[\\d{1,4}:[^\\]]*\\]\\s*)+$" options:0 error:nil];
    });
    // Timestamp-only/whitespace placeholders must not mask another real lyric.
    for(LyricInfo *line in lyrics.lyrics) {
        NSString *value = [line.realLyric stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if(value.length && ![brokenTimeOnly firstMatchInString:value options:0 range:NSMakeRange(0, value.length)]) return lyrics;
    }
    return nil;
}
bool IsLyricsKey(const TagLib::String &key) {
    auto source = key.upper().to8Bit(true);
    source.erase(std::remove_if(source.begin(), source.end(), [](char c) {
        return c == ' ' || c == '_' || c == '-';
    }), source.end());
    return source == "LYRICS" || source == "UNSYNCEDLYRICS" || source == "LYRICSUNSYNCR"
        || source == "UNSYNCHRONIZEDLYRICS" || source == "SYNCEDLYRICS" || source == "SYNCHRONIZEDLYRICS";
}
LyricLineModel *ReadLyrics(TagLib::FileRef &file) {
    auto readTag = [](TagLib::Tag *tag) -> LyricLineModel * {
        if(!tag) return nil;
        if(auto asf = dynamic_cast<TagLib::ASF::Tag *>(tag)) {
            for(const char *key : {"WM/Lyrics", "WM/LYRICS"}) {
                for(const auto &attribute : asf->attributeListMap().value(key)) {
                    if(auto lyrics = UsableLyrics(StringFromTag(attribute.toString()))) return lyrics;
                }
            }
        }
        // Language variants must not be concatenated into one lyric stream.
        if(auto id3 = dynamic_cast<TagLib::ID3v2::Tag *>(tag)) {
            const auto frames = id3->frameList("USLT");
            for(bool preferred : {true, false}) {
                for(auto frame : frames) {
                    auto uslt = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame *>(frame);
                    if(!uslt) continue;
                    bool primary = uslt->description().isEmpty() || uslt->description().upper() == "LYRICS";
                    if(primary != preferred) continue;
                    if(auto lyrics = UsableLyrics(StringFromTag(uslt->text()))) return lyrics;
                }
            }
        }
        // Read the standard atom directly: a freeform atom with the same
        // property name must not overwrite it in the generic property map.
        if(auto mp4 = dynamic_cast<TagLib::MP4::Tag *>(tag)) {
            for(const auto &value : mp4->item("\251lyr").toStringList())
                if(auto lyrics = UsableLyrics(StringFromTag(value))) return lyrics;
            for(const auto &[key, item] : mp4->itemMap()) {
                NSString *name = StringFromTag(key);
                if(![name hasPrefix:@"----:"] || !IsLyricsKey(StringToTag([name componentsSeparatedByString:@":"].lastObject))) continue;
                for(const auto &value : item.toStringList())
                    if(auto lyrics = UsableLyrics(StringFromTag(value))) return lyrics;
            }
        }
        const auto props = tag->properties();
        // Prefer canonical LYRICS over aliases, preserving separate values.
        for(bool canonical : {true, false}) {
            for(const auto &[key, values] : props) {
                if((key == "LYRICS") != canonical || !IsLyricsKey(key)) continue;
                for(const auto &value : values)
                    if(auto lyrics = UsableLyrics(StringFromTag(value))) return lyrics;
            }
        }
        return nil;
    };
    if(auto lyrics = readTag(NativeLyricsTag(file, false))) return lyrics;
    auto id3 = ID3Tag(file, false);
    if(auto lyrics = readTag(id3)) return lyrics;
    if(id3) {
        for(auto frame : id3->frameList("SYLT")) {
            auto sylt = dynamic_cast<TagLib::ID3v2::SynchronizedLyricsFrame *>(frame);
            if(!sylt || sylt->type() != TagLib::ID3v2::SynchronizedLyricsFrame::Lyrics) continue;
            double scale = 1.0;
            if(sylt->timestampFormat() == TagLib::ID3v2::SynchronizedLyricsFrame::AbsoluteMpegFrames) {
                auto props = dynamic_cast<TagLib::MPEG::Properties *>(file.audioProperties());
                if(!props || props->sampleRate() <= 0) continue;
                int samples = props->layer() == 1 ? 384 :
                    (props->layer() == 3 && props->version() != TagLib::MPEG::Header::Version1 ? 576 : 1152);
                scale = samples * 1000.0 / props->sampleRate();
            } else if(sylt->timestampFormat() != TagLib::ID3v2::SynchronizedLyricsFrame::AbsoluteMilliseconds) continue;
            NSMutableArray<LyricInfo *> *lines = [NSMutableArray array];
            NSUInteger textBytes = 0;
            bool tooLarge = false;
            for(const auto &entry : sylt->synchedText()) {
                LyricInfo *line = [LyricInfo new];
                line.fullLyric = line.realLyric = StringFromTag(entry.text);
                textBytes += [line.fullLyric lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
                if(lines.count >= MaxLyricLines || textBytes > MaxLyricsBytes) { tooLarge = true; break; }
                line.startTimestamp = entry.time * scale;
                if([line.realLyric stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length) [lines addObject:line];
            }
            if(!tooLarge && lines.count) {
                FinishTimedLyrics(lines);
                LyricLineModel *model = [LyricLineModel new];
                model.isNoneTime = NO; model.lyrics = lines;
                return model;
            }
        }
    }
    if(auto f = dynamic_cast<TagLib::MPEG::File *>(file.file()))
        if(auto lyrics = readTag(f->APETag(false))) return lyrics;
    if(auto lyrics = readTag(file.tag())) return lyrics;
    if(auto wav = dynamic_cast<TagLib::RIFF::WAV::File *>(file.file())) {
        // Nonstandard but explicitly lyric-labelled RIFF INFO field.
        if(auto lyrics = UsableLyrics(StringFromTag(wav->InfoTag()->fieldText("ILYR")))) return lyrics;
        if(auto lyrics = UsableLyrics(StringFromTag(wav->InfoTag()->comment()), true)) return lyrics;
    }
    // Some older editors stored LRC in comments. Only accept real timed LRC;
    // ordinary descriptions, copyright notices and arbitrary text are not lyrics.
    if(id3) {
        for(const auto &[key, values] : id3->properties()) {
            auto name = key.upper();
            if(name != "COMMENT" && !name.startsWith("COMMENT:")) continue;
            for(const auto &value : values)
                if(auto lyrics = UsableLyrics(StringFromTag(value), true)) return lyrics;
        }
    }
    return UsableLyrics(StringFromTag(file.tag()->comment()), true);
}
NSString *ImageMIME(NSData *data, bool reading = false) {
    if(!data.length || data.length > MaxArtworkBytes) return nil;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, nullptr);
    if(!source) return nil;
    NSString *type = (__bridge NSString *)CGImageSourceGetType(source);
    NSString *mime = [type isEqualToString:@"public.png"] ? @"image/png" :
        ([type isEqualToString:@"public.jpeg"] ? @"image/jpeg" :
        ([type isEqualToString:@"com.compuserve.gif"] ? @"image/gif" :
        ([type isEqualToString:@"com.microsoft.bmp"] ? @"image/bmp" : nil)));
    // Reading is not limited to our four portable write formats. ImageIO can
    // also decode existing TIFF/HEIF/WebP artwork on supported OS versions.
    if(!mime && reading && type.length) mime = @"application/octet-stream";
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, nullptr));
    double width = [properties[(__bridge NSString *)kCGImagePropertyPixelWidth] doubleValue];
    double height = [properties[(__bridge NSString *)kCGImagePropertyPixelHeight] doubleValue];
    if(width <= 0 || height <= 0 || width * height > 100000000
       || CGImageSourceGetStatusAtIndex(source, 0) != kCGImageStatusComplete) mime = nil;
    CFRelease(source);
    return mime;
}
KakaImage *ArtworkImage(NSData *data);
NSData *ReadCoverData(TagLib::FileRef &file, KakaImage *__strong *decodedImage = nullptr) {
    auto pictures = file.complexProperties("PICTURE");
    auto appendAPE = [&](TagLib::APE::Tag *ape) {
        if(!ape) return;
        pictures.append(ape->complexProperties("PICTURE"));
        // A few editors omit the filename/NUL prefix from APE picture items.
        // TagLib recognizes raw JPEG/PNG, but not raw GIF/BMP/TIFF headers.
        // Try only the two explicit artwork fields, never arbitrary binary data.
        for(const char *key : {"COVER ART (FRONT)", "COVER ART (BACK)"}) {
            const auto item = ape->itemListMap().value(key);
            if(item.type() != TagLib::APE::Item::Binary) continue;
            const auto bytes = item.binaryData();
            if(bytes.isEmpty() || bytes.size() > MaxArtworkBytes) continue;
            NSData *raw = [NSData dataWithBytes:bytes.data() length:bytes.size()];
            if(!ImageMIME(raw, true)) continue;
            TagLib::VariantMap picture;
            picture["data"] = bytes;
            picture["pictureType"] = TagLib::String(strcmp(key, "COVER ART (FRONT)") == 0 ? "Front Cover" : "Back Cover");
            pictures.append(picture);
        }
    };
    if(auto flac = dynamic_cast<TagLib::FLAC::File *>(file.file())) {
        // FLAC::File returns only native PICTURE blocks, not pictures stored
        // in its Vorbis comments or older ID3v2 tag.
        if(auto xiph = flac->xiphComment(false)) pictures.append(xiph->complexProperties("PICTURE"));
        if(auto id3 = flac->ID3v2Tag(false)) pictures.append(id3->complexProperties("PICTURE"));
    }
    if(auto mpeg = dynamic_cast<TagLib::MPEG::File *>(file.file())) {
        appendAPE(mpeg->APETag(false));
    } else if(auto ape = dynamic_cast<TagLib::APE::Tag *>(NativeLyricsTag(file, false))) appendAPE(ape);
    // Never interpret other binary fields (e.g. GEOB) as cover art.
    for(bool frontOnly : {true, false}) {
        for(const auto &picture : pictures) {
            if(frontOnly && picture.value("pictureType").toString() != "Front Cover") continue;
            auto value = picture.value("data");
            if(value.type() != TagLib::Variant::ByteVector) continue;
            const auto bytes = value.value<TagLib::ByteVector>();
            if(bytes.isEmpty() || bytes.size() > MaxArtworkBytes) continue;
            NSData *data = [NSData dataWithBytes:bytes.data() length:bytes.size()];
            if(!ImageMIME(data, true)) continue;
            if(decodedImage) {
                KakaImage *image = ArtworkImage(data);
                if(!image) continue; // A damaged first picture must not mask a good later picture.
                *decodedImage = image;
            }
            return data;
        }
    }
    return nil;
}
KakaImage *ArtworkImage(NSData *data) {
    if(!data) return nil;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, nullptr);
    if(!source) return nil;
    NSDictionary *options = @{
        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @2048
    };
    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    if(!image) return nil;
#if TARGET_OS_OSX
    KakaImage *result = [[NSImage alloc] initWithCGImage:image size:NSZeroSize];
#else
    KakaImage *result = [UIImage imageWithCGImage:image];
#endif
    CGImageRelease(image);
    return result;
}
template<typename Setter>
BOOL SetText(NSString *value, NSURL *url, Setter setter) {
    if(!value || ![value canBeConvertedToEncoding:NSUTF8StringEncoding]) return NO;
    return WithFile<BOOL>(url, true, false, NO, [&](TagLib::FileRef &file) {
        auto tag = NativeLyricsTag(file, true);
        if(!tag) return (BOOL)NO;
        setter(tag, StringToTag(value)); return (BOOL)Save(file, true);
    });
}
}

@implementation TaglibMetadataParser
+ (MetadataTagModel *)readMetadataWithFileURL:(NSURL *)fileURL readType:(TaglibReaderType)readType {
    return WithFile<MetadataTagModel *>(fileURL, false, true, nil, [&](TagLib::FileRef &file) {
        MetadataTagModel *model = [MetadataTagModel new]; model.fileURL = fileURL;
        auto tag = file.tag();
        model.title = StringFromTag(tag->title()); model.artist = StringFromTag(tag->artist());
        model.album = StringFromTag(tag->album()); model.genre = StringFromTag(tag->genre());
        model.comment = StringFromTag(tag->comment()); model.year = tag->year(); model.track = tag->track();
        if(auto props = file.audioProperties()) {
            model.bitrate = (NSUInteger)std::max(0, props->bitrate()) * 1000;
            model.sampleRate = std::max(0, props->sampleRate());
            model.durationSeconds = std::max(0, props->lengthInSeconds());
            model.channel = std::max(0, props->channels());
        }
        if(readType == TaglibReaderTypeAll || readType == TaglibReaderTypeBasicCover) {
            KakaImage *image = nil;
            model.coverArtData = ReadCoverData(file, &image); model.coverArt = image;
        }
        if(readType == TaglibReaderTypeAll || readType == TaglibReaderTypeBasicLyrics) model.lyricModel = ReadLyrics(file);
        return model;
    });
}
+ (NSData *)extractCoverArtDataFromURL:(NSURL *)fileURL {
    return WithFile<NSData *>(fileURL, false, false, nil, [](TagLib::FileRef &file) { return ReadCoverData(file); });
}
+ (KakaImage *)extractCoverArtFromURL:(NSURL *)fileURL {
    return WithFile<KakaImage *>(fileURL, false, false, nil, [](TagLib::FileRef &file) {
        KakaImage *image = nil; ReadCoverData(file, &image); return image;
    });
}
+ (LyricLineModel *)extractLyricsFromURL:(NSURL *)fileURL {
    return WithFile<LyricLineModel *>(fileURL, false, true, nil, [](TagLib::FileRef &file) { return ReadLyrics(file); });
}
+ (LyricLineModel *)parseSynchronizedLyrics:(NSString *)lyricsText {
    if(!lyricsText.length || [lyricsText lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > MaxLyricsBytes) return nil;
    // A UTF-8 BOM commonly survives in text copied from an external LRC file.
    if([lyricsText hasPrefix:@"\uFEFF"]) lyricsText = [lyricsText substringFromIndex:1];
    // Bound tokenization as well as resulting objects. Splitting a 4 MiB
    // newline-only payload first could allocate millions of temporary strings.
    NSUInteger breaks = 0, brackets = 0;
    for(NSUInteger index = 0; index < lyricsText.length; ++index) {
        unichar c = [lyricsText characterAtIndex:index];
        if((c == '\n' || c == '\r') && ++breaks > MaxLyricLines * 2) return nil;
        if(c == '[' && ++brackets > MaxLyricLines + 512) return nil;
    }
    static NSRegularExpression *timeRegex, *metadataRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        timeRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[(\\d{1,4}):([0-5]?\\d)(?:[.:](\\d{1,3}))?\\]" options:0 error:nil];
        metadataRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\[([a-zA-Z_]+):(.*)\\]$" options:0 error:nil];
    });
    LyricLineModel *model = [LyricLineModel new];
    NSMutableArray<LyricInfo *> *timed = [NSMutableArray array], *plain = [NSMutableArray array];
    for(NSString *raw in [lyricsText componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *line = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if(!line.length) continue;
        NSTextCheckingResult *meta = [metadataRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        if(meta) {
            NSString *key = [[line substringWithRange:[meta rangeAtIndex:1]] lowercaseString];
            NSString *value = [line substringWithRange:[meta rangeAtIndex:2]];
            if([key isEqualToString:@"ar"]) model.artist = value;
            else if([key isEqualToString:@"ti"]) model.title = value;
            else if([key isEqualToString:@"al"]) model.album = value;
            else if([key isEqualToString:@"by"]) model.creater = value;
            else if([key isEqualToString:@"offset"]) model.offset = (int)std::clamp(FiniteNumber(value), (double)INT_MIN, (double)INT_MAX);
            else if([key isEqualToString:@"t_time"]) model.totalTime = std::max(0.0, FiniteNumber(value));
            else if([key isEqualToString:@"length"]) {
                NSArray<NSString *> *parts = [value componentsSeparatedByString:@":"];
                if(parts.count == 2) model.totalTime = std::max(0.0, FiniteNumber(parts[0]) * 60 + FiniteNumber(parts[1])) * 1000;
            }
            else if([@[@"re", @"ve", @"id", @"au", @"la", @"language", @"encoding", @"tool"] containsObject:key]) {
                // Recognized informational LRC tags, not displayed lyric lines.
            }
            else {
                // Bracketed lyric text such as [Chorus: repeat] is not LRC
                // metadata. Do not silently discard an unfamiliar label.
                meta = nil;
            }
            if(meta) continue;
        }
        if([line hasPrefix:@"offset:"]) { model.offset = (int)std::clamp(FiniteNumber([line substringFromIndex:7]), (double)INT_MIN, (double)INT_MAX); continue; }
        if([line hasPrefix:@"t_time:"]) { model.totalTime = std::max(0.0, FiniteNumber([line substringFromIndex:7]) * 1000); continue; }
        NSArray<NSTextCheckingResult *> *matches = [timeRegex matchesInString:line options:0 range:NSMakeRange(0, line.length)];
        NSMutableArray<NSTextCheckingResult *> *prefixes = [NSMutableArray array];
        NSUInteger cursor = 0;
        for(NSTextCheckingResult *match in matches) {
            if(match.range.location != cursor) break;
            [prefixes addObject:match]; cursor = NSMaxRange(match.range);
        }
        NSString *text = [[line substringFromIndex:cursor] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if(!prefixes.count) {
            if(plain.count >= MaxLyricLines) return nil;
            LyricInfo *info = [LyricInfo new]; info.fullLyric = info.realLyric = text; [plain addObject:info]; continue;
        }
        for(NSTextCheckingResult *match in prefixes) {
            if(timed.count >= MaxLyricLines) return nil;
            double seconds = [[line substringWithRange:[match rangeAtIndex:1]] doubleValue] * 60
                           + [[line substringWithRange:[match rangeAtIndex:2]] doubleValue];
            NSRange fraction = [match rangeAtIndex:3];
            if(fraction.location != NSNotFound) seconds += [[line substringWithRange:fraction] doubleValue] / std::pow(10.0, fraction.length);
            LyricInfo *info = [LyricInfo new]; info.fullLyric = info.realLyric = text;
            info.startTimestamp = seconds * 1000; [timed addObject:info];
        }
    }
    if(timed.count) { FinishTimedLyrics(timed); model.lyrics = timed; model.isNoneTime = NO; }
    else { model.lyrics = plain; model.isNoneTime = YES; }
    return model;
}
+ (BOOL)setTitle:(NSString *)v toFileURL:(NSURL *)url { return SetText(v, url, [](TagLib::Tag *t, const TagLib::String &s) { t->setTitle(s); }); }
+ (BOOL)setArtist:(NSString *)v toFileURL:(NSURL *)url { return SetText(v, url, [](TagLib::Tag *t, const TagLib::String &s) { t->setArtist(s); }); }
+ (BOOL)setAlbum:(NSString *)v toFileURL:(NSURL *)url { return SetText(v, url, [](TagLib::Tag *t, const TagLib::String &s) { t->setAlbum(s); }); }
+ (BOOL)setGenre:(NSString *)v toFileURL:(NSURL *)url { return SetText(v, url, [](TagLib::Tag *t, const TagLib::String &s) { t->setGenre(s); }); }
+ (BOOL)setComment:(NSString *)v toFileURL:(NSURL *)url { return SetText(v, url, [](TagLib::Tag *t, const TagLib::String &s) { t->setComment(s); }); }
+ (BOOL)setTrack:(int)v toFileURL:(NSURL *)url {
    if(v < 0) return NO;
    return WithFile<BOOL>(url, true, false, NO, [&](TagLib::FileRef &file) {
        auto tag = NativeLyricsTag(file, true); if(!tag) return (BOOL)NO;
        tag->setTrack(v); return (BOOL)Save(file, true);
    });
}
+ (BOOL)setYear:(int)v toFileURL:(NSURL *)url {
    if(v < 0) return NO;
    return WithFile<BOOL>(url, true, false, NO, [&](TagLib::FileRef &file) {
        auto tag = NativeLyricsTag(file, true); if(!tag) return (BOOL)NO;
        tag->setYear(v); return (BOOL)Save(file, true);
    });
}
+ (BOOL)setCoverArtData:(NSData *)data toFileURL:(NSURL *)url {
    NSString *mime = ImageMIME(data); if(!mime) return NO;
    return WithFile<BOOL>(url, true, false, NO, [&](TagLib::FileRef &file) {
        // Matroska's generic attachment API rewrites unrelated metadata;
        // leave this uncommon write path unsupported until preservation tested.
        if(dynamic_cast<TagLib::Matroska::Tag *>(file.tag())) return (BOOL)NO;
        TagLib::VariantMap front;
        front["data"] = TagLib::ByteVector(static_cast<const char *>(data.bytes), (unsigned int)data.length);
        front["mimeType"] = StringToTag(mime); front["pictureType"] = TagLib::String("Front Cover");
        // A legacy-only file may have no native writable tag yet. Target that
        // native tag explicitly rather than broadcasting into a TagUnion.
        const bool nativeFLAC = dynamic_cast<TagLib::FLAC::File *>(file.file()) != nullptr;
        auto tag = nativeFLAC ? nullptr : NativeLyricsTag(file, true);
        if(auto ape = dynamic_cast<TagLib::APE::Tag *>(tag)) {
            // Rebuilding all APE pictures would normalize (and can damage)
            // a filename-less back picture. Change only the front item.
            TagLib::ByteVector bytes(1, '\0');
            bytes.append(front.value("data").value<TagLib::ByteVector>());
            ape->setItem("COVER ART (FRONT)", TagLib::APE::Item("Cover Art (Front)", bytes, true));
            return (BOOL)Save(file, true);
        }
        auto existing = tag ? tag->complexProperties("PICTURE") : file.complexProperties("PICTURE");
        TagLib::List<TagLib::VariantMap> pictures; pictures.append(front);
        bool replacedUntyped = false;
        for(const auto &picture : existing) {
            auto type = picture.value("pictureType").toString();
            if(type == "Front Cover") continue;
            // MP4 has no roles. Replace its first artwork, preserve the rest.
            if(type.isEmpty() && !replacedUntyped) { replacedUntyped = true; continue; }
            pictures.append(picture);
        }
        bool changed = tag ? tag->setComplexProperties("PICTURE", pictures) : file.setComplexProperties("PICTURE", pictures);
        return (BOOL)(changed && Save(file, true));
    });
}
+ (BOOL)setCoverArt:(KakaImage *)image toFileURL:(NSURL *)url {
    if(!image) return NO;
#if TARGET_OS_OSX
    CGImageRef cgImage = [image CGImageForProposedRect:nullptr context:nil hints:nil];
#else
    // Normalize rotation/mirroring and CIImage-backed artwork before encoding.
    CGFloat width = image.size.width * image.scale, height = image.size.height * image.scale;
    if(!std::isfinite(width) || !std::isfinite(height) || width <= 0 || height <= 0 || width > 10000 || height > 10000) return NO;
    UIImage *normalized = image;
    if(!image.CGImage || image.imageOrientation != UIImageOrientationUp) {
#if TARGET_OS_WATCH
        // UIGraphicsImageRenderer is unavailable on watchOS.
        UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
        [image drawInRect:(CGRect){CGPointZero, image.size}];
        normalized = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
#else
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
        format.scale = image.scale;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:image.size format:format];
        normalized = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            [image drawInRect:(CGRect){CGPointZero, image.size}];
        }];
#endif
    }
    CGImageRef cgImage = normalized.CGImage;
#endif
    if(!cgImage || CGImageGetWidth(cgImage) > 10000 || CGImageGetHeight(cgImage) > 10000) return NO;
    CGImageRetain(cgImage);
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.png"), 1, nullptr);
    if(!dest) { CGImageRelease(cgImage); return NO; }
    CGImageDestinationAddImage(dest, cgImage, nullptr);
    CGImageRelease(cgImage);
    BOOL success = CGImageDestinationFinalize(dest); CFRelease(dest);
    return success && [self setCoverArtData:data toFileURL:url];
}
+ (BOOL)setLyrics:(NSString *)lyrics toFileURL:(NSURL *)url {
    if(!lyrics || ![lyrics canBeConvertedToEncoding:NSUTF8StringEncoding] || [lyrics lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > MaxLyricsBytes) return NO;
    return WithFile<BOOL>(url, true, false, NO, [&](TagLib::FileRef &file) {
        auto tag = NativeLyricsTag(file, true); if(!tag) return (BOOL)NO;
        if(auto id3 = dynamic_cast<TagLib::ID3v2::Tag *>(tag)) {
            TagLib::ID3v2::UnsynchronizedLyricsFrame *primary = nullptr;
            // Modify only the first default-language frame when replacing text.
            // Clearing lyrics removes default frames, not comments/SYLT/other descriptions.
            const auto frames = id3->frameList("USLT");
            for(auto frame : frames) {
                auto uslt = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame *>(frame);
                if(!uslt || (!uslt->description().isEmpty() && uslt->description().upper() != "LYRICS")) continue;
                if(!lyrics.length) id3->removeFrame(frame);
                else if(!primary) primary = uslt;
            }
            if(lyrics.length) {
                if(!primary) { primary = new TagLib::ID3v2::UnsynchronizedLyricsFrame(TagLib::String::UTF8); id3->addFrame(primary); }
                primary->setTextEncoding(TagLib::String::UTF8);
                primary->setText(StringToTag(lyrics));
            }
            return (BOOL)Save(file, true);
        }
        // Touch only the native lyrics field. A property-map round trip can
        // flatten ASF language/stream metadata or unrelated Matroska tags.
        if(auto xiph = dynamic_cast<TagLib::Ogg::XiphComment *>(tag)) {
            xiph->removeFields("LYRICS");
            if(lyrics.length) xiph->addField("LYRICS", StringToTag(lyrics));
        } else if(auto ape = dynamic_cast<TagLib::APE::Tag *>(tag)) {
            ape->removeItem("LYRICS");
            if(lyrics.length) ape->setItem("LYRICS", TagLib::APE::Item("LYRICS", TagLib::StringList(StringToTag(lyrics))));
        } else if(auto mp4 = dynamic_cast<TagLib::MP4::Tag *>(tag)) {
            mp4->removeItem("\251lyr");
            if(lyrics.length) mp4->setItem("\251lyr", TagLib::MP4::Item(TagLib::StringList(StringToTag(lyrics))));
        } else if(auto asf = dynamic_cast<TagLib::ASF::Tag *>(tag)) {
            asf->removeItem("WM/Lyrics"); asf->removeItem("WM/LYRICS");
            if(lyrics.length) asf->setAttribute("WM/Lyrics", TagLib::ASF::Attribute(StringToTag(lyrics)));
        } else { return (BOOL)NO; }
        return (BOOL)Save(file, true);
    });
}
+ (BOOL)setLyris:(NSString *)lyrics toFileURL:(NSURL *)url { return [self setLyrics:lyrics toFileURL:url]; }
@end
