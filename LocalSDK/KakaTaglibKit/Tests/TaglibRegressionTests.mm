#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "TaglibMetadataParser.h"

#include <cmath>
#include <cstring>
#include <atomic>
#include <fileref.h>
#include <mpegfile.h>
#include <flacfile.h>
#include <flacpicture.h>
#include <vorbisfile.h>
#include <opusfile.h>
#include <wavfile.h>
#include <aifffile.h>
#include <trueaudiofile.h>
#include <wavpackfile.h>
#include <asffile.h>
#include <asfpicture.h>
#include <asfattribute.h>
#include <dsffile.h>
#include <dsdifffile.h>
#include <apefile.h>
#include <mpcfile.h>
#include <id3v2tag.h>
#include <id3v1tag.h>
#include <attachedpictureframe.h>
#include <synchronizedlyricsframe.h>
#include <unsynchronizedlyricsframe.h>
#include <infotag.h>
#include <xiphcomment.h>
#include <apetag.h>
#include <apeitem.h>
#include <unistd.h>

static NSUInteger checks = 0;
static NSUInteger failures = 0;

static void Check(BOOL condition, NSString *description) {
    ++checks;
    if (!condition) {
        ++failures;
        fprintf(stderr, "FAIL %s\n", description.UTF8String);
    }
}

static void Equal(NSString *actual, NSString *expected, NSString *description) {
    Check([actual isEqualToString:expected],
          [NSString stringWithFormat:@"%@: expected <%@>, got <%@>", description, expected, actual]);
}

static TagLib::ByteVector Bytes(NSData *data) {
    return TagLib::ByteVector(static_cast<const char *>(data.bytes),
                              static_cast<unsigned int>(data.length));
}

static NSData *Data(const TagLib::ByteVector &bytes) {
    return [NSData dataWithBytes:bytes.data() length:bytes.size()];
}

static NSData *MakeImage(NSBitmapImageFileType type, unsigned char red) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:nullptr pixelsWide:3 pixelsHigh:2
        bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:9 bitsPerPixel:24];
    unsigned char *pixels = bitmap.bitmapData;
    for (int i = 0; i < 6; ++i) {
        pixels[i * 3] = red;
        pixels[i * 3 + 1] = static_cast<unsigned char>(i * 30);
        pixels[i * 3 + 2] = 120;
    }
    return [bitmap representationUsingType:type properties:@{}];
}

static TagLib::ID3v2::Tag *ID3(TagLib::File *file) {
    if (auto *f = dynamic_cast<TagLib::MPEG::File *>(file)) return f->ID3v2Tag(true);
    if (auto *f = dynamic_cast<TagLib::RIFF::WAV::File *>(file)) return f->ID3v2Tag();
    if (auto *f = dynamic_cast<TagLib::RIFF::AIFF::File *>(file)) return f->tag();
    if (auto *f = dynamic_cast<TagLib::TrueAudio::File *>(file)) return f->ID3v2Tag(true);
    if (auto *f = dynamic_cast<TagLib::DSF::File *>(file)) return f->tag();
    if (auto *f = dynamic_cast<TagLib::DSDIFF::File *>(file)) return f->ID3v2Tag(true);
    return nullptr;
}

static TagLib::APE::Tag *APE(TagLib::File *file) {
    if (auto *f = dynamic_cast<TagLib::WavPack::File *>(file)) return f->APETag(true);
    if (auto *f = dynamic_cast<TagLib::APE::File *>(file)) return f->APETag(true);
    if (auto *f = dynamic_cast<TagLib::MPC::File *>(file)) return f->APETag(true);
    return nullptr;
}

static TagLib::Ogg::XiphComment *Xiph(TagLib::File *file) {
    if (auto *f = dynamic_cast<TagLib::Ogg::Vorbis::File *>(file)) return f->tag();
    if (auto *f = dynamic_cast<TagLib::Ogg::Opus::File *>(file)) return f->tag();
    return nullptr;
}

// Deliberately insert a back cover before the front cover. Reader implementations
// that blindly return the first picture will fail even though both decode.
static BOOL SeedTypedCovers(NSURL *url, NSData *back, NSData *front) {
    TagLib::FileRef ref(url.fileSystemRepresentation);
    if (ref.isNull()) return NO;
    if (auto *tag = ID3(ref.file())) {
        tag->removeFrames("APIC");
        for (int i = 0; i < 2; ++i) {
            auto *picture = new TagLib::ID3v2::AttachedPictureFrame;
            picture->setType(i == 0 ? TagLib::ID3v2::AttachedPictureFrame::BackCover
                                    : TagLib::ID3v2::AttachedPictureFrame::FrontCover);
            picture->setMimeType(i == 0 ? "image/png" : "image/jpeg");
            picture->setDescription(i == 0 ? "preserve-back" : "replace-front");
            picture->setPicture(Bytes(i == 0 ? back : front));
            tag->addFrame(picture);
        }
    } else if (auto *flac = dynamic_cast<TagLib::FLAC::File *>(ref.file())) {
        flac->removePictures();
        for (int i = 0; i < 2; ++i) {
            auto *picture = new TagLib::FLAC::Picture;
            picture->setType(i == 0 ? TagLib::FLAC::Picture::BackCover : TagLib::FLAC::Picture::FrontCover);
            picture->setMimeType(i == 0 ? "image/png" : "image/jpeg");
            picture->setDescription(i == 0 ? "preserve-back" : "replace-front");
            picture->setData(Bytes(i == 0 ? back : front));
            flac->addPicture(picture);
        }
    } else if (auto *tag = Xiph(ref.file())) {
        tag->removeAllPictures();
        for (int i = 0; i < 2; ++i) {
            auto *picture = new TagLib::FLAC::Picture;
            picture->setType(i == 0 ? TagLib::FLAC::Picture::BackCover : TagLib::FLAC::Picture::FrontCover);
            picture->setMimeType(i == 0 ? "image/png" : "image/jpeg");
            picture->setDescription(i == 0 ? "preserve-back" : "replace-front");
            picture->setData(Bytes(i == 0 ? back : front));
            tag->addPicture(picture);
        }
    } else if (auto *asf = dynamic_cast<TagLib::ASF::File *>(ref.file())) {
        asf->tag()->removeItem("WM/Picture");
        for (int i = 0; i < 2; ++i) {
            TagLib::ASF::Picture picture;
            picture.setType(i == 0 ? TagLib::ASF::Picture::BackCover : TagLib::ASF::Picture::FrontCover);
            picture.setMimeType(i == 0 ? "image/png" : "image/jpeg");
            picture.setDescription(i == 0 ? "preserve-back" : "replace-front");
            picture.setPicture(Bytes(i == 0 ? back : front));
            asf->tag()->addAttribute("WM/Picture", TagLib::ASF::Attribute(picture));
        }
    } else if (auto *tag = APE(ref.file())) {
        TagLib::ByteVector backBytes("back.png", 9);
        backBytes.append(Bytes(back));
        tag->setItem("Cover Art (Back)", TagLib::APE::Item("Cover Art (Back)", backBytes, true));
        TagLib::ByteVector frontBytes("front.jpg", 10);
        frontBytes.append(Bytes(front));
        tag->setItem("Cover Art (Front)", TagLib::APE::Item("Cover Art (Front)", frontBytes, true));
    } else {
        return NO; // MP4 does not distinguish front/back picture types.
    }
    return ref.save();
}

static NSData *ReadBackCover(NSURL *url) {
    TagLib::FileRef ref(url.fileSystemRepresentation);
    if (ref.isNull()) return nil;
    if (auto *tag = ID3(ref.file())) {
        for (auto *frame : tag->frameList("APIC")) {
            auto *picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(frame);
            if (picture && picture->type() == TagLib::ID3v2::AttachedPictureFrame::BackCover)
                return Data(picture->picture());
        }
    } else if (auto *flac = dynamic_cast<TagLib::FLAC::File *>(ref.file())) {
        for (auto *picture : flac->pictureList())
            if (picture->type() == TagLib::FLAC::Picture::BackCover) return Data(picture->data());
    } else if (auto *tag = Xiph(ref.file())) {
        for (auto *picture : tag->pictureList())
            if (picture->type() == TagLib::FLAC::Picture::BackCover) return Data(picture->data());
    } else if (auto *asf = dynamic_cast<TagLib::ASF::File *>(ref.file())) {
        for (const auto &attribute : asf->tag()->attributeListMap()["WM/Picture"]) {
            const auto picture = attribute.toPicture();
            if (picture.isValid() && picture.type() == TagLib::ASF::Picture::BackCover)
                return Data(picture.picture());
        }
    } else if (auto *tag = APE(ref.file())) {
        auto bytes = tag->itemListMap()["COVER ART (BACK)"].binaryData();
        const int delimiter = bytes.find(TagLib::ByteVector(1, '\0'));
        if (delimiter >= 0) return Data(bytes.mid(static_cast<unsigned int>(delimiter + 1)));
    }
    return nil;
}

static void TestLyricsParser(void) {
    Check([TaglibMetadataParser parseSynchronizedLyrics:nil] == nil, @"Nil lyrics return nil");
    NSString *text = @"[ti:曲名🌙]\n[ar:歌手]\n[al:专辑]\n[by:作者]\n[offset:+150]\n"
                      "[00:03.5]最后\n[00:01.01][00:02.001]重复\n[00:01.01]同刻";
    LyricLineModel *model = [TaglibMetadataParser parseSynchronizedLyrics:text];
    Check(model != nil, @"LRC parser returns model");
    Equal(model.title, @"曲名🌙", @"LRC title");
    Equal(model.artist, @"歌手", @"LRC artist");
    Equal(model.album, @"专辑", @"LRC album");
    Check(model.offset == 150, @"LRC offset is stored, not applied");
    Check(!model.isNoneTime, @"LRC timed flag");
    Check(model.lyrics.count == 4, @"LRC multiple timestamp prefixes expand into four rows");
    const double starts[] = {1010, 1010, 2001, 3500};
    const double ends[] = {2001, 2001, 3500, 6500};
    for (NSUInteger i = 0; i < MIN(model.lyrics.count, 4u); ++i) {
        Check(std::abs(model.lyrics[i].startTimestamp - starts[i]) < 0.01,
              [NSString stringWithFormat:@"LRC sorted timestamp %lu", (unsigned long)i]);
        Check(std::abs(model.lyrics[i].endTimestamp - ends[i]) < 0.01,
              [NSString stringWithFormat:@"LRC next greater end timestamp %lu", (unsigned long)i]);
    }
    NSUInteger repeated = 0;
    for (LyricInfo *line in model.lyrics) if ([line.realLyric isEqualToString:@"重复"]) ++repeated;
    Check(repeated == 2, @"LRC repeated text copied for each timestamp");

    NSArray<NSString *> *malformed = @[@"[", @"]", @"[]", @"[00]text", @"[00:]text", @"[:01]text",
        @"[00:xx]text", @"[00:01", @"[00:01.2][broken]line", @"[99:99.999]line",
        @"[offset:not-a-number]", @"[999999999999999999999999999999:01.999]overflow",
        @"[00:01.000]\n[garbage]\nplain", @"", @"plain lyrics\n第二行"];
    for (NSString *input in malformed) {
        @try {
            LyricLineModel *parsed = [TaglibMetadataParser parseSynchronizedLyrics:input];
            for (LyricInfo *line in parsed.lyrics) {
                Check(std::isfinite(line.startTimestamp) && std::isfinite(line.endTimestamp),
                      @"Malformed LRC never produces non-finite times");
            }
            Check(YES, @"Malformed LRC did not throw");
        } @catch (NSException *exception) {
            Check(NO, [NSString stringWithFormat:@"Malformed LRC threw %@ for %@", exception.name, input]);
        }
    }
    LyricLineModel *plain = [TaglibMetadataParser parseSynchronizedLyrics:@"第一行\nsecond line"];
    Check(plain.isNoneTime, @"Plain lyrics carry untimed flag");
    Check(plain.lyrics.count == 2, @"Plain lyrics retain both lines");

    NSMutableString *manyPrefixes = [NSMutableString string];
    NSMutableString *manyLines = [NSMutableString string];
    NSMutableString *manyPlain = [NSMutableString string];
    for (NSUInteger i = 0; i < 20001; ++i) {
        [manyPrefixes appendString:@"[00:01.00]"];
        [manyLines appendString:@"[00:01.00]bounded\n"];
        [manyPlain appendString:@"plain\n"];
    }
    [manyPrefixes appendString:@"bounded"];
    for (NSString *largeInput in @[manyPrefixes, manyLines, manyPlain]) {
        LyricLineModel *bounded = [TaglibMetadataParser parseSynchronizedLyrics:largeInput];
        Check(bounded == nil || bounded.lyrics.count <= 20000, @"LRC expansion is bounded to 20,000 events");
    }
}

static void TestInvalidURLs(NSURL *directory, NSData *png) {
    NSFileManager *manager = NSFileManager.defaultManager;
    NSURL *empty = [directory URLByAppendingPathComponent:@"empty.mp3"];
    NSURL *corrupt = [directory URLByAppendingPathComponent:@"corrupt.flac"];
    NSURL *corruptMP3 = [directory URLByAppendingPathComponent:@"corrupt.mp3"];
    NSURL *shellWAV = [directory URLByAppendingPathComponent:@"header-only.wav"];
    Check([[NSData data] writeToURL:empty atomically:YES], @"Create empty synthetic input");
    Check([[@"Not a media file: 随机文本" dataUsingEncoding:NSUTF8StringEncoding]
           writeToURL:corrupt atomically:YES], @"Create corrupt synthetic input");
    Check([[@"Not MPEG audio: 随机文本" dataUsingEncoding:NSUTF8StringEncoding]
           writeToURL:corruptMP3 atomically:YES], @"Create corrupt MPEG input");
    Check([[NSData dataWithBytes:"RIFF\x04\0\0\0WAVE" length:12] writeToURL:shellWAV atomically:YES], @"Create header-only WAV input");
    NSArray *inputs = @[empty, corrupt, corruptMP3, shellWAV, directory,
        [directory URLByAppendingPathComponent:@"missing.mp3"],
        [NSURL URLWithString:@"https://example.invalid/synthetic.mp3"], NSNull.null];
    for (id value in inputs) {
        NSURL *url = value == NSNull.null ? nil : value;
        NSString *label = url ? url.lastPathComponent : @"nil";
        NSData *before = url.isFileURL ? [NSData dataWithContentsOfURL:url] : nil;
        Check([TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeAll] == nil,
              [@"Invalid metadata URL " stringByAppendingString:label]);
        Check([TaglibMetadataParser extractCoverArtDataFromURL:url] == nil,
              [@"Invalid cover URL " stringByAppendingString:label]);
        Check([TaglibMetadataParser extractCoverArtFromURL:url] == nil,
              [@"Invalid decoded-cover URL " stringByAppendingString:label]);
        Check([TaglibMetadataParser extractLyricsFromURL:url] == nil,
              [@"Invalid lyric URL " stringByAppendingString:label]);
        Check(![TaglibMetadataParser setTitle:@"test" toFileURL:url], @"Invalid title target rejected");
        Check(![TaglibMetadataParser setArtist:@"test" toFileURL:url], @"Invalid artist target rejected");
        Check(![TaglibMetadataParser setAlbum:@"test" toFileURL:url], @"Invalid album target rejected");
        Check(![TaglibMetadataParser setGenre:@"test" toFileURL:url], @"Invalid genre target rejected");
        Check(![TaglibMetadataParser setComment:@"test" toFileURL:url], @"Invalid comment target rejected");
        Check(![TaglibMetadataParser setTrack:1 toFileURL:url], @"Invalid track target rejected");
        Check(![TaglibMetadataParser setYear:2026 toFileURL:url], @"Invalid year target rejected");
        Check(![TaglibMetadataParser setLyris:@"test" toFileURL:url], @"Invalid lyric target rejected");
        Check(![TaglibMetadataParser setCoverArtData:png toFileURL:url], @"Invalid cover target rejected");
        if (before) Check([[NSData dataWithContentsOfURL:url] isEqualToData:before],
                          [@"Invalid writes do not change bytes: " stringByAppendingString:label]);
    }
    Check(![manager fileExistsAtPath:[directory URLByAppendingPathComponent:@"missing.mp3"].path],
          @"Rejected setters do not create missing files");
}

// Exercise writers independently: writing a title first would hide bugs where
// cover/lyrics setters cannot create a missing ID3v2 or APE destination tag.
static void TestUntaggedWriters(NSURL *source, NSData *png) {
    NSURL *base = [source URLByDeletingPathExtension];
    NSURL *cover = [[base URLByAppendingPathExtension:@"cover-first"] URLByAppendingPathExtension:source.pathExtension];
    NSURL *lyric = [[base URLByAppendingPathExtension:@"lyrics-first"] URLByAppendingPathExtension:source.pathExtension];
    NSFileManager *manager = NSFileManager.defaultManager;
    NSError *error = nil;
    Check([manager copyItemAtURL:source toURL:cover error:&error], @"Copy untouched cover-only fixture");
    error = nil;
    Check([manager copyItemAtURL:source toURL:lyric error:&error], @"Copy untouched lyric-only fixture");
    Check([TaglibMetadataParser setCoverArtData:png toFileURL:cover],
          [source.pathExtension stringByAppendingString:@" cover writer creates missing tags"]);
    Check([[TaglibMetadataParser extractCoverArtDataFromURL:cover] isEqualToData:png],
          [source.pathExtension stringByAppendingString:@" cover-only file reopens"]);
    Check([TaglibMetadataParser setLyrics:@"[00:01.20]首次歌词" toFileURL:lyric],
          [source.pathExtension stringByAppendingString:@" lyric writer creates missing tags"]);
    LyricLineModel *model = [TaglibMetadataParser extractLyricsFromURL:lyric];
    Check(model.lyrics.count == 1, [source.pathExtension stringByAppendingString:@" lyric-only file reopens"]);
    if (model.lyrics.count == 1) Equal(model.lyrics[0].realLyric, @"首次歌词", @"First-write Unicode lyric");
}

static void TestHybridFlac(NSURL *source, NSData *png) {
    if (![source.pathExtension isEqualToString:@"flac"]) return;
    NSURL *url = [[[source URLByDeletingPathExtension] URLByAppendingPathExtension:@"hybrid"]
                  URLByAppendingPathExtension:@"flac"];
    Check([NSFileManager.defaultManager copyItemAtURL:source toURL:url error:nil], @"Copy hybrid FLAC fixture");
    {
        TagLib::FLAC::File file(url.fileSystemRepresentation);
        file.ID3v2Tag(true)->setComment("legacy unrelated ID3v2");
        file.xiphComment(true)->addField("LYRICS", TagLib::String("[00:01.00]native lyrics", TagLib::String::UTF8));
        auto *picture = new TagLib::FLAC::Picture;
        picture->setType(TagLib::FLAC::Picture::FrontCover);
        picture->setMimeType("image/png");
        picture->setData(Bytes(png));
        file.addPicture(picture);
        Check(file.save(), @"Save hybrid FLAC fixture");
    }
    LyricLineModel *lyrics = [TaglibMetadataParser extractLyricsFromURL:url];
    Check(lyrics.lyrics.count == 1, @"FLAC legacy ID3 does not hide native Xiph lyrics");
    if (lyrics.lyrics.count == 1) Equal(lyrics.lyrics[0].realLyric, @"native lyrics", @"FLAC native lyric text");
    Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:png],
          @"FLAC legacy ID3 does not hide native pictures");
}

static void TestSecondaryTagPreservation(NSURL *source) {
    NSString *extension = source.pathExtension;
    if (![@[@"mp3", @"wav", @"wv"] containsObject:extension]) return;
    NSURL *url = [[[source URLByDeletingPathExtension] URLByAppendingPathExtension:@"mixed-tags"]
                  URLByAppendingPathExtension:extension];
    Check([NSFileManager.defaultManager copyItemAtURL:source toURL:url error:nil], @"Copy mixed-tag fixture");
    {
        TagLib::FileRef ref(url.fileSystemRepresentation);
        if (auto *mpeg = dynamic_cast<TagLib::MPEG::File *>(ref.file())) {
            mpeg->ID3v2Tag(true)->setTitle("primary title");
            mpeg->ID3v1Tag(true)->setComment("secondary sentinel");
            Check(mpeg->save(TagLib::MPEG::File::AllTags, TagLib::File::StripNone,
                  TagLib::ID3v2::v4, TagLib::File::DoNotDuplicate), @"Save mixed MP3 fixture");
        } else if (auto *wav = dynamic_cast<TagLib::RIFF::WAV::File *>(ref.file())) {
            wav->ID3v2Tag()->setTitle("primary title");
            wav->InfoTag()->setComment("secondary sentinel");
            wav->InfoTag()->setArtist("secondary artist");
            Check(wav->save(), @"Save mixed WAV fixture");
        } else if (auto *wavpack = dynamic_cast<TagLib::WavPack::File *>(ref.file())) {
            wavpack->APETag(true)->setTitle("primary title");
            wavpack->ID3v1Tag(true)->setComment("secondary sentinel");
            Check(wavpack->save(), @"Save mixed WavPack fixture");
        }
    }
    MetadataTagModel *before = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeBasic];
    Equal(before.comment, @"secondary sentinel", [extension stringByAppendingString:@" secondary comment initially visible"]);
    Check([TaglibMetadataParser setLyris:@"[00:01.00]preserve others" toFileURL:url], @"Write mixed-tag lyrics");
    MetadataTagModel *after = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeBasic];
    Equal(after.comment, @"secondary sentinel", [extension stringByAppendingString:@" lyric write preserves secondary comment"]);
    if ([extension isEqualToString:@"wav"])
        Equal(after.artist, @"secondary artist", @"WAV lyric write preserves INFO-only artist");
    TagLib::FileRef ref(url.fileSystemRepresentation);
    TagLib::String nativeComment;
    if (auto *mpeg = dynamic_cast<TagLib::MPEG::File *>(ref.file()))
        nativeComment = mpeg->ID3v1Tag(true)->comment();
    else if (auto *wav = dynamic_cast<TagLib::RIFF::WAV::File *>(ref.file()))
        nativeComment = wav->InfoTag()->comment();
    else if (auto *wavpack = dynamic_cast<TagLib::WavPack::File *>(ref.file()))
        nativeComment = wavpack->ID3v1Tag(true)->comment();
    Check(nativeComment == "secondary sentinel", [extension stringByAppendingString:@" native secondary tag preserved"]);
}

static void TestSynchronizedID3Lyrics(NSURL *source) {
    if (![source.pathExtension isEqualToString:@"mp3"]) return;
    NSURL *url = [[[source URLByDeletingPathExtension] URLByAppendingPathExtension:@"sylt"]
                  URLByAppendingPathExtension:@"mp3"];
    Check([NSFileManager.defaultManager copyItemAtURL:source toURL:url error:nil], @"Copy SYLT fixture");
    {
        TagLib::MPEG::File file(url.fileSystemRepresentation);
        auto *frame = new TagLib::ID3v2::SynchronizedLyricsFrame(TagLib::String::UTF8);
        frame->setType(TagLib::ID3v2::SynchronizedLyricsFrame::Lyrics);
        frame->setTimestampFormat(TagLib::ID3v2::SynchronizedLyricsFrame::AbsoluteMilliseconds);
        frame->setLanguage("eng");
        TagLib::ID3v2::SynchronizedLyricsFrame::SynchedTextList text;
        text.append({1000, "first"});
        text.append({2000, "second"});
        text.append({3000, "last"});
        frame->setSynchedText(text);
        file.ID3v2Tag(true)->addFrame(frame);
        Check(file.save(), @"Save SYLT fixture");
    }
    LyricLineModel *model = [TaglibMetadataParser extractLyricsFromURL:url];
    Check(model.lyrics.count == 3, @"SYLT retains all three events including final event");
    if (model.lyrics.count == 3) {
        Equal(model.lyrics[2].realLyric, @"last", @"SYLT final text");
        Check(model.lyrics[2].startTimestamp == 3000 && model.lyrics[2].endTimestamp == 6000,
              @"SYLT final event gets three-second end");
    }
}

static void TestReadOnlyAndDrawingImage(NSURL *source, NSData *png) {
    if (![source.pathExtension isEqualToString:@"mp3"]) return;
    NSURL *url = [[[source URLByDeletingPathExtension] URLByAppendingPathExtension:@"readonly"]
                  URLByAppendingPathExtension:@"mp3"];
    NSFileManager *manager = NSFileManager.defaultManager;
    Check([manager copyItemAtURL:source toURL:url error:nil], @"Copy read-only fixture");
    NSData *before = [NSData dataWithContentsOfURL:url];
    Check([manager setAttributes:@{NSFilePosixPermissions: @0444} ofItemAtPath:url.path error:nil], @"Make synthetic fixture read-only");
    Check(![TaglibMetadataParser setCoverArtData:png toFileURL:url], @"Read-only cover write rejected");
    Check(![TaglibMetadataParser setTitle:@"change" toFileURL:url], @"Read-only title write rejected");
    Check(![TaglibMetadataParser setLyris:@"change" toFileURL:url], @"Read-only lyric write rejected");
    Check([[NSData dataWithContentsOfURL:url] isEqualToData:before], @"Read-only fixture bytes preserved");
    NSNumber *permissions = [manager attributesOfItemAtPath:url.path error:nil][NSFilePosixPermissions];
    Check((permissions.unsignedIntegerValue & 0777) == 0444, @"Writers do not change read-only permissions");
    Check([manager setAttributes:@{NSFilePosixPermissions: @0644} ofItemAtPath:url.path error:nil], @"Restore synthetic fixture permissions");

    NSImage *drawing = [NSImage imageWithSize:NSMakeSize(8, 8) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        [NSColor.redColor setFill];
        NSRectFill(rect);
        return YES;
    }];
    @try {
        Check([TaglibMetadataParser setCoverArt:drawing toFileURL:url], @"Non-bitmap NSImage writes a cover");
        Check([TaglibMetadataParser extractCoverArtFromURL:url] != nil, @"Non-bitmap NSImage cover decodes");
    } @catch (NSException *exception) {
        Check(NO, [@"Non-bitmap NSImage conversion threw " stringByAppendingString:exception.name]);
    }
}

static void TestMultilingualUSLT(NSURL *source) {
    if (![source.pathExtension isEqualToString:@"mp3"]) return;
    NSURL *url = [[[source URLByDeletingPathExtension] URLByAppendingPathExtension:@"multilingual"]
                  URLByAppendingPathExtension:@"mp3"];
    Check([NSFileManager.defaultManager copyItemAtURL:source toURL:url error:nil], @"Copy multilingual lyric fixture");
    {
        TagLib::MPEG::File file(url.fileSystemRepresentation);
        const char *languages[] = {"eng", "zho", "fra"};
        const char *texts[] = {"primary old", "secondary language", "described translation"};
        for (int i = 0; i < 3; ++i) {
            auto *frame = new TagLib::ID3v2::UnsynchronizedLyricsFrame(TagLib::String::UTF8);
            frame->setLanguage(languages[i]);
            frame->setDescription(i == 2 ? "translation" : "");
            frame->setText(texts[i]);
            file.ID3v2Tag(true)->addFrame(frame);
        }
        Check(file.save(), @"Save multilingual lyric fixture");
    }
    Check([TaglibMetadataParser setLyrics:@"[00:01.00]updated primary" toFileURL:url], @"Update primary multilingual lyrics");
    LyricLineModel *read = [TaglibMetadataParser extractLyricsFromURL:url];
    Check(read.lyrics.count == 1, @"Read updated primary lyric");
    if (read.lyrics.count == 1) Equal(read.lyrics[0].realLyric, @"updated primary", @"Updated primary is selected");
    TagLib::MPEG::File file(url.fileSystemRepresentation);
    const auto frames = file.ID3v2Tag(true)->frameList("USLT");
    Check(frames.size() == 3, @"USLT update preserves other language/description frames");
    BOOL english = NO, chinese = NO, french = NO;
    for (auto *base : frames) {
        auto *frame = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame *>(base);
        if (!frame) continue;
        if (frame->language() == "eng") english = frame->text() == "[00:01.00]updated primary";
        if (frame->language() == "zho") chinese = frame->text() == "secondary language" && frame->description().isEmpty();
        if (frame->language() == "fra") french = frame->text() == "described translation" && frame->description() == "translation";
    }
    Check(english, @"Primary USLT preserves its language while updating text");
    Check(chinese, @"Secondary-language USLT remains unchanged");
    Check(french, @"Described translation USLT remains unchanged");
    Check([TaglibMetadataParser setLyrics:@"" toFileURL:url], @"Clear canonical USLT frames");
    TagLib::MPEG::File cleared(url.fileSystemRepresentation);
    const auto remaining = cleared.ID3v2Tag(true)->frameList("USLT");
    Check(remaining.size() == 1, @"Clearing removes both canonical USLT frames and preserves translation");
    if (remaining.size() == 1) {
        auto *translation = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame *>(remaining.front());
        Check(translation && translation->description() == "translation" && translation->text() == "described translation",
              @"Clearing canonical lyrics keeps described translation intact");
    }
}

static void TestMixedMPEGArtwork(NSURL *source, NSData *png, NSData *jpeg, NSData *back) {
    if (![source.pathExtension isEqualToString:@"mp3"]) return;
    NSURL *url = [[[source URLByDeletingPathExtension] URLByAppendingPathExtension:@"mixed-artwork"]
                  URLByAppendingPathExtension:@"mp3"];
    Check([NSFileManager.defaultManager copyItemAtURL:source toURL:url error:nil], @"Copy mixed MPEG artwork fixture");
    TagLib::ByteVector backBytes("back.png", 9);
    backBytes.append(Bytes(back));
    {
        TagLib::MPEG::File file(url.fileSystemRepresentation);
        auto *frame = new TagLib::ID3v2::AttachedPictureFrame;
        frame->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);
        frame->setMimeType("image/jpeg");
        frame->setPicture(Bytes(jpeg));
        file.ID3v2Tag(true)->addFrame(frame);
        file.APETag(true)->setItem("Cover Art (Back)", TagLib::APE::Item("Cover Art (Back)", backBytes, true));
        file.APETag(true)->setComment("APE sentinel");
        Check(file.save(), @"Save mixed APIC and APE artwork fixture");
    }
    Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:jpeg], @"Mixed MPEG reads ID3 front artwork");
    Check([TaglibMetadataParser setCoverArtData:png toFileURL:url], @"Mixed MPEG updates ID3 front artwork");
    Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:png], @"Mixed MPEG front artwork updated");
    TagLib::MPEG::File file(url.fileSystemRepresentation);
    Check(file.APETag(true)->itemListMap()["COVER ART (BACK)"].binaryData() == backBytes,
          @"MPEG artwork write preserves APE back artwork bytes and filename");
    Check(file.APETag(true)->comment() == "APE sentinel", @"MPEG artwork write preserves APE comment");
}

static NSData *LegacyV1Tag(BOOL longComment) {
    unsigned char bytes[128] = {};
    memcpy(bytes, "TAG", 3);
    memcpy(bytes + 3, "legacy title", 12);
    memcpy(bytes + 33, "legacy artist", 13);
    memcpy(bytes + 63, "legacy album", 12);
    memcpy(bytes + 93, "1998", 4);
    const char *comment = longComment ? "123456789012345678901234567890" : "short legacy comment";
    memcpy(bytes + 97, comment, strlen(comment));
    bytes[127] = 255;
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

static NSURL *MakeLegacyOnlyFixture(NSURL *source, BOOL longComment, NSString *variant = nil) {
    NSURL *url = [[[source URLByDeletingPathExtension]
                  URLByAppendingPathExtension:variant ?: (longComment ? @"raw-id3v1-long" : @"raw-id3v1-short")]
                  URLByAppendingPathExtension:source.pathExtension];
    if (![NSFileManager.defaultManager copyItemAtURL:source toURL:url error:nil]) {
        Check(NO, @"Copy legacy-only fixture");
        return nil;
    }
    BOOL stripped = NO;
    {
        TagLib::FileRef ref(url.fileSystemRepresentation);
        if (auto *file = dynamic_cast<TagLib::MPEG::File *>(ref.file())) {
            stripped = file->strip();
        } else if (auto *file = dynamic_cast<TagLib::WavPack::File *>(ref.file())) {
            file->strip(); stripped = file->save();
        } else if (auto *file = dynamic_cast<TagLib::APE::File *>(ref.file())) {
            file->strip(); stripped = file->save();
        } else if (auto *file = dynamic_cast<TagLib::MPC::File *>(ref.file())) {
            file->strip(); stripped = file->save();
        } else if (auto *file = dynamic_cast<TagLib::TrueAudio::File *>(ref.file())) {
            file->strip(); stripped = file->save();
        }
    }
    Check(stripped, [source.pathExtension stringByAppendingString:@" remove native tags from disposable copy"]);
    if (!stripped) return nil;
    NSMutableData *data = [[NSData dataWithContentsOfURL:url] mutableCopy];
    [data appendData:LegacyV1Tag(longComment)];
    Check([data writeToURL:url atomically:YES], @"Append exact raw ID3v1.0 bytes");
    return url;
}

static BOOL HasLegacyTail(NSURL *url, NSData *tail) {
    NSData *bytes = [NSData dataWithContentsOfURL:url];
    return bytes.length >= 128 && [[bytes subdataWithRange:NSMakeRange(bytes.length - 128, 128)] isEqualToData:tail];
}

static void TestLongLegacyComment(NSURL *source, NSData *png) {
    NSString *extension = source.pathExtension;
    if (![@[@"mp3", @"wv"] containsObject:extension]) return;
    NSURL *url = MakeLegacyOnlyFixture(source, YES);
    if (!url) return;
    NSData *tail = LegacyV1Tag(YES);
    MetadataTagModel *initial = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeBasic];
    Equal(initial.comment, @"123456789012345678901234567890", @"Read full 30-byte ID3v1.0 comment");
    Check(initial.track == 0, @"Raw ID3v1.0 has no track field");
    if ([extension isEqualToString:@"mp3"]) {
        Check([TaglibMetadataParser setTitle:@"现代标题 🌙" toFileURL:url], @"MP3 title writes alongside long legacy comment");
        Check(HasLegacyTail(url, tail), @"MP3 title write preserves all128 raw ID3v1 bytes");
        Check([TaglibMetadataParser setLyrics:@"[00:01.00]modern lyrics" toFileURL:url], @"MP3 lyrics write alongside long legacy comment");
        Check(HasLegacyTail(url, tail), @"MP3 lyrics write preserves all128 raw ID3v1 bytes");
        Check([TaglibMetadataParser setCoverArtData:png toFileURL:url], @"MP3 artwork write alongside long legacy comment");
        Check(HasLegacyTail(url, tail), @"MP3 artwork write preserves all128 raw ID3v1 bytes");
        MetadataTagModel *after = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeAll];
        Equal(after.title, @"现代标题 🌙", @"MP3 native title takes precedence over legacy title");
        Equal(after.comment, initial.comment, @"MP3 long legacy comment remains readable");
        Check(after.lyricModel.lyrics.count == 1 && after.coverArt != nil, @"MP3 modern artwork and lyrics readable");
    } else {
        NSData *before = [NSData dataWithContentsOfURL:url];
        Check(![TaglibMetadataParser setTitle:@"change" toFileURL:url], @"WavPack unsafe legacy title rewrite refused");
        Check(![TaglibMetadataParser setArtist:@"change" toFileURL:url], @"WavPack unsafe legacy artist rewrite refused");
        Check(![TaglibMetadataParser setAlbum:@"change" toFileURL:url], @"WavPack unsafe legacy album rewrite refused");
        Check(![TaglibMetadataParser setGenre:@"change" toFileURL:url], @"WavPack unsafe legacy genre rewrite refused");
        Check(![TaglibMetadataParser setComment:@"change" toFileURL:url], @"WavPack unsafe legacy comment rewrite refused");
        Check(![TaglibMetadataParser setTrack:7 toFileURL:url], @"WavPack unsafe legacy track rewrite refused");
        Check(![TaglibMetadataParser setYear:2026 toFileURL:url], @"WavPack unsafe legacy year rewrite refused");
        Check(![TaglibMetadataParser setLyrics:@"change" toFileURL:url], @"WavPack unsafe legacy lyric rewrite refused");
        Check(![TaglibMetadataParser setCoverArtData:png toFileURL:url], @"WavPack unsafe legacy artwork rewrite refused");
        Check([[NSData dataWithContentsOfURL:url] isEqualToData:before], @"Refused WavPack edits preserve every file byte");
    }
}

static void TestLegacyOnlyUnicodePromotion(NSURL *source) {
    if (![@[@"wv", @"tta", @"ape", @"mpc"] containsObject:source.pathExtension]) return;
    NSURL *url = MakeLegacyOnlyFixture(source, NO);
    if (!url) return;
    {
        TagLib::FileRef ref(url.fileSystemRepresentation);
        BOOL onlyLegacy = NO;
        if (auto *file = dynamic_cast<TagLib::WavPack::File *>(ref.file())) onlyLegacy = file->hasID3v1Tag() && !file->hasAPETag();
        else if (auto *file = dynamic_cast<TagLib::APE::File *>(ref.file())) onlyLegacy = file->hasID3v1Tag() && !file->hasAPETag();
        else if (auto *file = dynamic_cast<TagLib::MPC::File *>(ref.file())) onlyLegacy = file->hasID3v1Tag() && !file->hasAPETag();
        else if (auto *file = dynamic_cast<TagLib::TrueAudio::File *>(ref.file())) onlyLegacy = file->hasID3v1Tag() && !file->hasID3v2Tag();
        Check(onlyLegacy, [source.pathExtension stringByAppendingString:@" starts with ID3v1 only"]);
    }
    Check([TaglibMetadataParser setTitle:@"新标题 🌙" toFileURL:url], @"Promote legacy-only title to native Unicode tag");
    Check([TaglibMetadataParser setArtist:@"艺术家 Björk" toFileURL:url], @"Promote legacy-only artist to native Unicode tag");
    Check([TaglibMetadataParser setAlbum:@"专辑 Ω" toFileURL:url], @"Promote legacy-only album to native Unicode tag");
    MetadataTagModel *metadata = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeBasic];
    Equal(metadata.title, @"新标题 🌙", [source.pathExtension stringByAppendingString:@" legacy-only Unicode title roundtrip"]);
    Equal(metadata.artist, @"艺术家 Björk", [source.pathExtension stringByAppendingString:@" legacy-only Unicode artist roundtrip"]);
    Equal(metadata.album, @"专辑 Ω", [source.pathExtension stringByAppendingString:@" legacy-only Unicode album roundtrip"]);
    Equal(metadata.comment, @"short legacy comment", @"Short legacy comment survives native tag creation");
}

static void TestConcurrentAccess(NSURL *source) {
    if (![source.pathExtension isEqualToString:@"mp3"]) return;
    NSURL *url = [[[source URLByDeletingPathExtension] URLByAppendingPathExtension:@"concurrent"]
                  URLByAppendingPathExtension:@"mp3"];
    Check([NSFileManager.defaultManager copyItemAtURL:source toURL:url error:nil], @"Copy concurrent access fixture");
    std::atomic<unsigned int> errors{0};
    auto *counter = &errors;
    dispatch_apply(64, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        @autoreleasepool {
            @try {
                NSString *title = [NSString stringWithFormat:@"并发标题 %zu", index];
                if (![TaglibMetadataParser setTitle:title toFileURL:url]) ++*counter;
                MetadataTagModel *metadata = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeBasic];
                if (!metadata || ![metadata.title hasPrefix:@"并发标题 "] || metadata.sampleRate == 0) ++*counter;
            } @catch (NSException *) {
                ++*counter;
            }
        }
    });
    Check(errors.load() == 0, @"64 concurrent same-file reads and edits complete without corruption or exceptions");
    MetadataTagModel *metadata = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeBasic];
    Check(metadata != nil && [metadata.title hasPrefix:@"并发标题 "] && metadata.sampleRate > 0,
          @"Concurrent access leaves a readable audio file");
}

static void TestRoundTrip(NSURL *url, NSData *png, NSData *jpeg, NSData *back) {
    const NSUInteger before = failures;
    NSString *format = url.pathExtension.uppercaseString;
    MetadataTagModel *initial = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeBasic];
    Check(initial != nil, [format stringByAppendingString:@" initially readable without user tags"]);
    Check(initial.title.length == 0 && initial.artist.length == 0, [format stringByAppendingString:@" initial tags empty"]);
    Check(initial.sampleRate > 0 && initial.channel > 0, [format stringByAppendingString:@" audio properties"]);
    Check(![TaglibMetadataParser setTitle:nil toFileURL:url], @"Nil title rejected");
    Check(![TaglibMetadataParser setArtist:nil toFileURL:url], @"Nil artist rejected");
    Check(![TaglibMetadataParser setAlbum:nil toFileURL:url], @"Nil album rejected");
    Check(![TaglibMetadataParser setGenre:nil toFileURL:url], @"Nil genre rejected");
    Check(![TaglibMetadataParser setComment:nil toFileURL:url], @"Nil comment rejected");
    Check(![TaglibMetadataParser setLyris:nil toFileURL:url], @"Nil lyrics rejected");
    Check(![TaglibMetadataParser setLyrics:nil toFileURL:url], @"Nil lyrics rejected by corrected spelling API");
    Check(![TaglibMetadataParser setCoverArtData:nil toFileURL:url], @"Nil cover data rejected");
    Check(![TaglibMetadataParser setCoverArt:nil toFileURL:url], @"Nil image rejected");

    NSString *title = @"月光 🌙 café — 日本語";
    NSString *artist = @"歌手 / Björk";
    NSString *album = @"专辑 Ω";
    NSString *genre = @"电子・Ambient";
    NSString *comment = @"保留备注 ✓\nsecond line";
    NSString *lyrics = @"[ti:月光]\n[offset:-75]\n[00:00.10][00:00.90]你好 🌏\n[00:00.50]世界";
    Check([TaglibMetadataParser setTitle:title toFileURL:url], [format stringByAppendingString:@" set title"]);
    Check([TaglibMetadataParser setArtist:artist toFileURL:url], [format stringByAppendingString:@" set artist"]);
    Check([TaglibMetadataParser setAlbum:album toFileURL:url], [format stringByAppendingString:@" set album"]);
    Check([TaglibMetadataParser setGenre:genre toFileURL:url], [format stringByAppendingString:@" set genre"]);
    Check([TaglibMetadataParser setComment:comment toFileURL:url], [format stringByAppendingString:@" set comment"]);
    Check([TaglibMetadataParser setTrack:7 toFileURL:url], [format stringByAppendingString:@" set track"]);
    Check([TaglibMetadataParser setYear:2026 toFileURL:url], [format stringByAppendingString:@" set year"]);
    Check(![TaglibMetadataParser setTrack:-1 toFileURL:url], [format stringByAppendingString:@" reject negative track"]);
    Check(![TaglibMetadataParser setYear:-1 toFileURL:url], [format stringByAppendingString:@" reject negative year"]);
    Check([TaglibMetadataParser setLyris:lyrics toFileURL:url], [format stringByAppendingString:@" set lyrics legacy API"]);

    BOOL typed = ![url.pathExtension isEqualToString:@"m4a"];
    if (typed) {
        Check(SeedTypedCovers(url, back, jpeg), [format stringByAppendingString:@" seed typed covers"]);
        Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:jpeg],
              [format stringByAppendingString:@" selects front cover when back appears first"]);
    }
    Check([TaglibMetadataParser setCoverArtData:png toFileURL:url], [format stringByAppendingString:@" write PNG cover"]);
    Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:png],
          [format stringByAppendingString:@" PNG bytes preserved exactly"]);
    if (typed) Check([ReadBackCover(url) isEqualToData:back], [format stringByAppendingString:@" PNG write preserves back cover"]);
    Check([TaglibMetadataParser setCoverArtData:jpeg toFileURL:url], [format stringByAppendingString:@" write JPEG cover"]);
    Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:jpeg],
          [format stringByAppendingString:@" JPEG bytes preserved exactly"]);
    if (typed) Check([ReadBackCover(url) isEqualToData:back], [format stringByAppendingString:@" JPEG write preserves back cover"]);
    Check([TaglibMetadataParser extractCoverArtFromURL:url] != nil, [format stringByAppendingString:@" cover decodes"]);

    Check(![TaglibMetadataParser setCoverArtData:[NSData data] toFileURL:url], @"Empty cover rejected");
    Check(![TaglibMetadataParser setCoverArtData:[@"invalid" dataUsingEncoding:NSUTF8StringEncoding] toFileURL:url], @"Corrupt cover rejected");
    Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:jpeg], @"Rejected cover writes preserve existing image");

    MetadataTagModel *all = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeAll];
    Equal(all.title, title, [format stringByAppendingString:@" title round trip"]);
    Equal(all.artist, artist, [format stringByAppendingString:@" artist round trip"]);
    Equal(all.album, album, [format stringByAppendingString:@" album round trip"]);
    Equal(all.genre, genre, [format stringByAppendingString:@" genre round trip"]);
    Equal(all.comment, comment, [format stringByAppendingString:@" comment round trip"]);
    Check(all.track == 7 && all.year == 2026, [format stringByAppendingString:@" numeric tags preserved"]);
    Check(all.coverArt != nil && all.lyricModel != nil, [format stringByAppendingString:@" all mode includes optional data"]);
    LyricLineModel *lyric = [TaglibMetadataParser extractLyricsFromURL:url];
    Check(lyric.lyrics.count == 3 && lyric.offset == -75, [format stringByAppendingString:@" lyric round trip"]);
    if (lyric.lyrics.count >= 3) {
        Equal(lyric.lyrics[0].realLyric, @"你好 🌏", [format stringByAppendingString:@" Unicode lyrics"]);
        Check(std::abs(lyric.lyrics[0].startTimestamp - 100) < 0.01, @"Persisted lyric first timestamp");
        Check(std::abs(lyric.lyrics[1].startTimestamp - 500) < 0.01, @"Persisted lyric sorted second timestamp");
        Check(std::abs(lyric.lyrics[2].startTimestamp - 900) < 0.01, @"Persisted lyric repeated timestamp");
    }

    MetadataTagModel *basic = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeBasic];
    Check(basic.coverArt == nil && basic.lyricModel == nil, [format stringByAppendingString:@" basic read mode"]);
    MetadataTagModel *cover = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeBasicCover];
    Check(cover.coverArt != nil && cover.lyricModel == nil, [format stringByAppendingString:@" cover read mode"]);
    MetadataTagModel *lyricOnly = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeBasicLyrics];
    Check(lyricOnly.coverArt == nil && lyricOnly.lyricModel != nil, [format stringByAppendingString:@" lyrics read mode"]);

    NSImage *image = [[NSImage alloc] initWithData:png];
    Check([TaglibMetadataParser setCoverArt:image toFileURL:url], [format stringByAppendingString:@" legacy image API"]);
    Check([TaglibMetadataParser extractCoverArtFromURL:url] != nil, @"Image API writes a decodable cover");
    if (typed) Check([ReadBackCover(url) isEqualToData:back], @"Image API preserves back cover");
    fprintf(stdout, "%s %s\n", failures == before ? "PASS" : "FAIL", format.UTF8String);
}

#include "TaglibFallbackRegressionTests.inc"

static NSArray<NSString *> *CorpusValidNames(void) {
    return @[@"empty10ms.dsf", @"empty10ms.dff", @"click.mpc", @"mac-399.ape", @"no-tags.mka"];
}

static NSArray<NSString *> *CorpusMalformedNames(void) {
    return @[@"segfault.mpc", @"segfault2.mpc", @"infloop.mpc", @"zerodiv.mpc", @"longloop.ape", @"zerodiv.ape"];
}

static void TestUpstreamCorpus(NSURL *directory, NSData *png, NSData *jpeg, NSData *back) {
    for (NSString *name in CorpusValidNames()) {
        NSURL *url = [directory URLByAppendingPathComponent:name];
        if ([name hasSuffix:@".mka"]) {
            NSData *before = [NSData dataWithContentsOfURL:url];
            MetadataTagModel *metadata = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeAll];
            Check(metadata != nil && metadata.sampleRate > 0 && metadata.channel > 0, @"Matroska audio metadata read");
            Check([TaglibMetadataParser extractCoverArtDataFromURL:url] == nil, @"Untagged Matroska artwork absent");
            Check([TaglibMetadataParser extractLyricsFromURL:url] == nil, @"Untagged Matroska lyrics absent");
            Check([[NSData dataWithContentsOfURL:url] isEqualToData:before], @"Matroska read-only probe preserves bytes");
            fprintf(stdout, "PROBED MKA read-only\n");
        } else {
            TestUntaggedWriters(url, png);
            TestLegacyOnlyUnicodePromotion(url);
            TestNativeArtworkCreation(url, png);
            TestRoundTrip(url, png, jpeg, back);
        }
    }
    for (NSString *name in CorpusMalformedNames()) {
        NSURL *url = [directory URLByAppendingPathComponent:name];
        NSData *before = [NSData dataWithContentsOfURL:url];
        fprintf(stdout, "Probe malformed %s (10-second watchdog)\n", name.UTF8String);
        fflush(stdout);
        alarm(10);
        (void)[TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeAll];
        (void)[TaglibMetadataParser extractCoverArtDataFromURL:url];
        (void)[TaglibMetadataParser extractLyricsFromURL:url];
        alarm(0);
        Check([[NSData dataWithContentsOfURL:url] isEqualToData:before],
              [@"Malformed read preserves bytes: " stringByAppendingString:name]);
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        BOOL corpusMode = argc == 3 && strcmp(argv[2], "--upstream") == 0;
        if (argc != 2 && !corpusMode) {
            fprintf(stderr, "Usage: taglib-regression TEMP_FIXTURES_DIRECTORY [--upstream]\n");
            return 2;
        }
        NSURL *directory = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]] isDirectory:YES];
        if (![directory.lastPathComponent hasPrefix:@"fixtures."]) {
            fprintf(stderr, "Refusing to mutate a directory not named fixtures.*\n");
            return 2;
        }
        NSError *error = nil;
        NSArray<NSURL *> *inputs = [NSFileManager.defaultManager contentsOfDirectoryAtURL:directory
            includingPropertiesForKeys:@[NSURLIsRegularFileKey, NSURLIsSymbolicLinkKey] options:0 error:&error];
        if (error || inputs.count == 0) {
            fprintf(stderr, "Cannot read generated fixtures directory.\n");
            return 2;
        }
        if (corpusMode && inputs.count != CorpusValidNames().count + CorpusMalformedNames().count) {
            fprintf(stderr, "Incomplete upstream fixture manifest.\n");
            return 2;
        }
        for (NSURL *input in inputs) {
            NSNumber *regular = nil;
            NSNumber *symlink = nil;
            [input getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
            [input getResourceValue:&symlink forKey:NSURLIsSymbolicLinkKey error:nil];
            BOOL allowedName = corpusMode ? [CorpusValidNames() containsObject:input.lastPathComponent] ||
                [CorpusMalformedNames() containsObject:input.lastPathComponent] : [input.lastPathComponent hasPrefix:@"synthetic."];
            if (!allowedName || !regular.boolValue || symlink.boolValue) {
                fprintf(stderr, "Refusing input outside the temporary fixture manifest.\n");
                return 2;
            }
        }
        NSData *png = MakeImage(NSBitmapImageFileTypePNG, 230);
        NSData *jpeg = MakeImage(NSBitmapImageFileTypeJPEG, 80);
        NSData *back = MakeImage(NSBitmapImageFileTypePNG, 10);
        Check(png.length > 0 && jpeg.length > 0 && back.length > 0, @"Synthetic images generated");
        if (corpusMode) {
            TestUpstreamCorpus(directory, png, jpeg, back);
            fprintf(stdout, "Upstream checks: %lu, failures: %lu, writable formats: 4, read-only format: 1, malformed files: 6\n",
                    (unsigned long)checks, (unsigned long)failures);
            return failures == 0 ? 0 : 1;
        }
        TestLyricsParser();
        for (NSURL *input in [inputs sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
            return [a.path compare:b.path];
        }]) {
            @autoreleasepool {
                TestUntaggedWriters(input, png);
                TestHybridFlac(input, png);
                TestSecondaryTagPreservation(input);
                TestSynchronizedID3Lyrics(input);
                TestReadOnlyAndDrawingImage(input, png);
                TestMultilingualUSLT(input);
                TestMixedMPEGArtwork(input, png, jpeg, back);
                TestLongLegacyComment(input, png);
                TestLegacyOnlyUnicodePromotion(input);
                TestConcurrentAccess(input);
                TestFallbackCompatibility(input, png, jpeg, back);
                TestRoundTrip(input, png, jpeg, back);
            }
        }
        TestInvalidURLs(directory, png);
        fprintf(stdout, "Checks: %lu, failures: %lu, formats: %lu\n",
                (unsigned long)checks, (unsigned long)failures, (unsigned long)inputs.count);
        return failures == 0 ? 0 : 1;
    }
}
