// Included by the standalone Objective-C++ harness after its shared helpers.
#include <textidentificationframe.h>
#include <mp4file.h>
#include <mp4tag.h>
#include <mp4item.h>
#include <dsdiffdiintag.h>
#include <tvariant.h>

static NSURL *FallbackFixture(NSURL *source, NSString *variant) {
    NSURL *url = [[[source URLByDeletingPathExtension] URLByAppendingPathExtension:variant]
                  URLByAppendingPathExtension:source.pathExtension];
    BOOL copied = [NSFileManager.defaultManager copyItemAtURL:source toURL:url error:nil];
    Check(copied, [@"Copy fallback fixture " stringByAppendingString:variant]);
    return copied ? url : nil;
}

static TagLib::String TagText(NSString *text) {
    return TagLib::String(text.UTF8String, TagLib::String::UTF8);
}

static void ExpectLyric(NSURL *url, NSString *text, NSString *label) {
    LyricLineModel *model = [TaglibMetadataParser extractLyricsFromURL:url];
    BOOL found = NO;
    for (LyricInfo *line in model.lyrics) if ([line.realLyric isEqualToString:text]) found = YES;
    Check(found, [label stringByAppendingString:@" exposes stored lyric text"]);
}

static TagLib::ID3v2::UnsynchronizedLyricsFrame *USLT(NSString *text, NSString *description) {
    auto *frame = new TagLib::ID3v2::UnsynchronizedLyricsFrame(TagLib::String::UTF8);
    frame->setLanguage("eng");
    frame->setDescription(TagText(description));
    frame->setText(TagText(text));
    return frame;
}

static void TestLyricFieldAliases(NSURL *source) {
    NSString *extension = source.pathExtension;
    if (![@[@"mp3", @"wv", @"ogg"] containsObject:extension]) return;
    NSArray<NSString *> *aliases = @[@"LYRICS", @"UNSYNCEDLYRICS", @"UNSYNCED LYRICS", @"UNSYNCED_LYRICS", @"LYRICS_UNSYNCR"];
    for (NSUInteger index = 0; index < aliases.count; ++index) {
        NSString *alias = aliases[index];
        NSURL *url = FallbackFixture(source, [NSString stringWithFormat:@"lyric-alias-%lu", (unsigned long)index]);
        if (!url) continue;
        {
            TagLib::FileRef file(url.fileSystemRepresentation);
            if (auto *mpeg = dynamic_cast<TagLib::MPEG::File *>(file.file())) {
                auto *frame = new TagLib::ID3v2::UserTextIdentificationFrame(TagLib::String::UTF8);
                frame->setDescription(TagText(alias));
                frame->setText("[00:01.00]alias payload");
                mpeg->ID3v2Tag(true)->addFrame(frame);
            } else if (auto *tag = APE(file.file())) {
                tag->setItem(TagText(alias), TagLib::APE::Item(TagText(alias), TagLib::StringList("[00:01.00]alias payload")));
            } else if (auto *tag = Xiph(file.file())) {
                tag->addField(TagText(alias), "[00:01.00]alias payload");
            }
            Check(file.save(), @"Save lyric alias fixture");
        }
        NSString *label = [NSString stringWithFormat:@"%@ %@", extension, alias];
        ExpectLyric(url, @"alias payload", label);
        Check([TaglibMetadataParser setLyrics:@"[00:02.00]canonical replacement" toFileURL:url], @"Canonical lyric replacement succeeds over alias");
        ExpectLyric(url, @"canonical replacement", [label stringByAppendingString:@" canonical priority"]);
    }
}

static void TestUSLTCandidates(NSURL *source) {
    if (![source.pathExtension isEqualToString:@"mp3"]) return;
    NSURL *described = FallbackFixture(source, @"described-uslt");
    if (described) {
        {
            TagLib::MPEG::File file(described.fileSystemRepresentation);
            file.ID3v2Tag(true)->addFrame(USLT(@"[00:01.00]described payload", @"English original"));
            Check(file.save(), @"Save described-only USLT fixture");
        }
        ExpectLyric(described, @"described payload", @"Described-only USLT fallback");
        Check([TaglibMetadataParser setLyrics:@"[00:02.00]canonical payload" toFileURL:described], @"Write canonical lyrics beside described USLT");
        ExpectLyric(described, @"canonical payload", @"Canonical USLT priority over description fallback");
        TagLib::MPEG::File file(described.fileSystemRepresentation);
        auto *old = TagLib::ID3v2::UnsynchronizedLyricsFrame::findByDescription(file.ID3v2Tag(true), "English original");
        Check(old && old->text() == "[00:01.00]described payload", @"Canonical USLT write preserves described original");
    }
    NSArray<NSString *> *unusable = @[@"[00:01.00]\n[00:02.00]", @"[00:xx]\n[99:xx]", @"[ti:metadata only]", @"   \n\t"];
    for (NSUInteger index = 0; index < unusable.count; ++index) {
        NSURL *url = FallbackFixture(source, [NSString stringWithFormat:@"uslt-candidate-%lu", (unsigned long)index]);
        if (!url) continue;
        {
            TagLib::MPEG::File file(url.fileSystemRepresentation);
            file.ID3v2Tag(true)->addFrame(USLT(unusable[index], @""));
            file.ID3v2Tag(true)->addFrame(USLT(@"[00:03.00]usable later candidate", @"LYRICS"));
            Check(file.save(), @"Save unusable-first USLT fixture");
        }
        ExpectLyric(url, @"usable later candidate", [NSString stringWithFormat:@"USLT candidate %lu fallback", (unsigned long)index]);
    }
}

static void TestMP4FreeformLyrics(NSURL *source) {
    if (![source.pathExtension isEqualToString:@"m4a"]) return;
    NSURL *url = FallbackFixture(source, @"freeform-lyrics");
    if (!url) return;
    {
        TagLib::MP4::File file(url.fileSystemRepresentation);
        file.tag()->setItem("----:com.apple.iTunes:LYRICS", TagLib::MP4::Item(TagLib::StringList("[00:01.00]freeform payload")));
        Check(file.save(), @"Save MP4 freeform lyric fixture");
    }
    ExpectLyric(url, @"freeform payload", @"MP4 iTunes freeform LYRICS fallback");
    Check([TaglibMetadataParser setLyrics:@"[00:02.00]standard payload" toFileURL:url], @"Write standard MP4 lyrics");
    ExpectLyric(url, @"standard payload", @"MP4 standard atom priority");
    TagLib::MP4::File file(url.fileSystemRepresentation);
    Check(file.tag()->item("----:com.apple.iTunes:LYRICS").toStringList().toString() == "[00:01.00]freeform payload",
          @"MP4 standard write preserves original freeform lyrics");
}

static void TestLegacyTimedComments(NSURL *source) {
    if (![@[@"wav", @"mp3"] containsObject:source.pathExtension]) return;
    for (BOOL timed : {YES, NO}) {
        NSURL *url = FallbackFixture(source, timed ? @"timed-comment" : @"ordinary-comment");
        if (!url) continue;
        {
            TagLib::FileRef file(url.fileSystemRepresentation);
            if (auto *wav = dynamic_cast<TagLib::RIFF::WAV::File *>(file.file())) {
                wav->ID3v2Tag()->setTitle("unrelated primary metadata");
                wav->InfoTag()->setComment(timed ? "[00:01.00]legacy timed payload" : "recording engineer notes");
            } else {
                file.tag()->setComment(timed ? "[00:01.00]legacy timed payload" : "recording engineer notes");
            }
            Check(file.save(), @"Save legacy comment fixture");
        }
        if (timed) ExpectLyric(url, @"legacy timed payload", [source.pathExtension stringByAppendingString:@" timed comment fallback"]);
        else Check([TaglibMetadataParser extractLyricsFromURL:url] == nil, @"Ordinary comment is never interpreted as lyrics");
        if (timed) {
            Check([TaglibMetadataParser setLyrics:@"[00:02.00]new canonical" toFileURL:url], @"Write lyrics beside timed legacy comment");
            ExpectLyric(url, @"new canonical", @"Canonical lyrics outrank legacy comment");
            MetadataTagModel *metadata = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeBasic];
            Equal(metadata.comment, @"[00:01.00]legacy timed payload", @"Lyrics write preserves legacy comment");
        }
    }
    if ([source.pathExtension isEqualToString:@"wav"]) {
        NSURL *url = FallbackFixture(source, @"info-labelled-lyrics");
        if (!url) return;
        {
            TagLib::RIFF::WAV::File file(url.fileSystemRepresentation);
            file.ID3v2Tag()->setTitle("unrelated ID3 title");
            file.InfoTag()->setFieldText("ILYR", "explicit INFO lyrics");
            Check(file.save(), @"Save labelled INFO lyric fixture");
        }
        ExpectLyric(url, @"explicit INFO lyrics", @"WAV ILYR fallback beside unrelated ID3");
        Check([TaglibMetadataParser setLyrics:@"[00:01.00]canonical WAV lyrics" toFileURL:url], @"Write canonical WAV lyrics beside ILYR");
        ExpectLyric(url, @"canonical WAV lyrics", @"Canonical WAV lyrics outrank ILYR");
        TagLib::RIFF::WAV::File file(url.fileSystemRepresentation);
        Check(file.InfoTag()->fieldText("ILYR") == "explicit INFO lyrics", @"Canonical WAV write preserves ILYR");
    }
}

static void TestLRCCompatibilityDetails(void) {
    LyricLineModel *bom = [TaglibMetadataParser parseSynchronizedLyrics:@"\ufeff[00:01.00]BOM text"];
    Check(bom.lyrics.count == 1 && bom.lyrics[0].startTimestamp == 1000 && [bom.lyrics[0].realLyric isEqualToString:@"BOM text"],
          @"UTF-8 BOM does not hide first LRC timestamp");
    LyricLineModel *label = [TaglibMetadataParser parseSynchronizedLyrics:@"[Chorus: repeat]\nplain text"];
    Check(label.lyrics.count == 2 && [label.lyrics[0].realLyric isEqualToString:@"[Chorus: repeat]"], @"Unknown bracket labels remain visible lyrics");
    LyricLineModel *metadata = [TaglibMetadataParser parseSynchronizedLyrics:@"[re:editor]\n[ve:1.0]\n[00:01.00]body"];
    Check(metadata.lyrics.count == 1 && [metadata.lyrics[0].realLyric isEqualToString:@"body"], @"Known editor/version LRC metadata remains metadata");
}

static void TestRawAPEPictures(NSURL *source, NSData *png) {
    if (![source.pathExtension isEqualToString:@"wv"]) return;
    NSArray<NSData *> *images = @[MakeImage(NSBitmapImageFileTypeGIF, 65), MakeImage(NSBitmapImageFileTypeBMP, 70), MakeImage(NSBitmapImageFileTypeTIFF, 75)];
    for (NSUInteger index = 0; index < images.count; ++index) {
        NSData *image = images[index];
        Check(image.length > 0, @"Create alternate APE bitmap");
        NSURL *front = FallbackFixture(source, [NSString stringWithFormat:@"ape-raw-front-%lu", (unsigned long)index]);
        if (front) {
            {
                TagLib::WavPack::File file(front.fileSystemRepresentation);
                file.APETag(true)->setItem("Cover Art (Front)", TagLib::APE::Item("Cover Art (Front)", Bytes(image), true));
                Check(file.save(), @"Save filename-less raw APE front picture");
            }
            Check([[TaglibMetadataParser extractCoverArtDataFromURL:front] isEqualToData:image], @"Read raw GIF/BMP/TIFF APE front bytes without filename prefix");
            Check([TaglibMetadataParser extractCoverArtFromURL:front] != nil, @"Raw APE front picture decodes");
        }
        NSURL *back = FallbackFixture(source, [NSString stringWithFormat:@"ape-raw-back-%lu", (unsigned long)index]);
        if (back) {
            {
                TagLib::WavPack::File file(back.fileSystemRepresentation);
                file.APETag(true)->setItem("Cover Art (Back)", TagLib::APE::Item("Cover Art (Back)", Bytes(image), true));
                Check(file.save(), @"Save filename-less raw APE back picture");
            }
            Check([[TaglibMetadataParser extractCoverArtDataFromURL:back] isEqualToData:image], @"Read raw APE back picture as fallback");
            Check([TaglibMetadataParser setCoverArtData:png toFileURL:back], @"Write APE front beside raw back picture");
            TagLib::WavPack::File file(back.fileSystemRepresentation);
            Check(file.APETag(true)->itemListMap()["COVER ART (BACK)"].binaryData() == Bytes(image), @"Front replacement preserves raw GIF/BMP/TIFF APE back item exactly");
        }
    }
}

static void TestFLACArtworkFallbacks(NSURL *source, NSData *png, NSData *jpeg) {
    if (![source.pathExtension isEqualToString:@"flac"]) return;
    for (int kind = 0; kind < 3; ++kind) {
        NSURL *url = FallbackFixture(source, [NSString stringWithFormat:@"flac-art-fallback-%d", kind]);
        if (!url) continue;
        {
            TagLib::FLAC::File file(url.fileSystemRepresentation);
            if (kind == 0) {
                auto *frame = new TagLib::ID3v2::AttachedPictureFrame;
                frame->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);
                frame->setMimeType("image/jpeg"); frame->setPicture(Bytes(jpeg));
                file.ID3v2Tag(true)->addFrame(frame);
            } else if (kind == 1) {
                auto *picture = new TagLib::FLAC::Picture;
                picture->setType(TagLib::FLAC::Picture::FrontCover);
                picture->setMimeType("image/jpeg"); picture->setData(Bytes(jpeg));
                file.xiphComment(true)->addPicture(picture);
            } else {
                file.xiphComment(true)->addField("COVERART", TagLib::String(Bytes(jpeg).toBase64(), TagLib::String::UTF8));
                file.xiphComment(true)->addField("COVERARTMIME", "image/jpeg");
            }
            Check(file.save(), @"Save FLAC alternate artwork fixture");
        }
        Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:jpeg],
              [NSString stringWithFormat:@"FLAC alternate artwork source %d is readable", kind]);
        Check([TaglibMetadataParser setCoverArtData:png toFileURL:url], @"Write native FLAC artwork beside legacy source");
        Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:png], @"Native FLAC front artwork has priority after write");
        TagLib::FLAC::File file(url.fileSystemRepresentation);
        BOOL preserved = NO;
        auto *tag = kind == 0 ? static_cast<TagLib::Tag *>(file.ID3v2Tag(false)) : static_cast<TagLib::Tag *>(file.xiphComment(false));
        if (tag) for (const auto &picture : tag->complexProperties("PICTURE"))
            if (picture.value("data").value<TagLib::ByteVector>() == Bytes(jpeg)) preserved = YES;
        Check(preserved, @"Native FLAC artwork write preserves alternate-container picture bytes");
    }
}

static void TestCoverCandidateFallbacks(NSURL *source, NSData *png, NSData *back) {
    if (![source.pathExtension isEqualToString:@"mp3"]) return;
    NSMutableData *headerOnly = [[png subdataWithRange:NSMakeRange(0, MIN((NSUInteger)33, png.length))] mutableCopy];
    const unsigned char iend[] = {0,0,0,0, 'I','E','N','D', 0xae,0x42,0x60,0x82};
    [headerOnly appendBytes:iend length:sizeof(iend)];
    NSArray<NSData *> *invalidCandidates = @[[NSData dataWithBytes:"not image data" length:14], headerOnly];
    for (NSUInteger index = 0; index < invalidCandidates.count; ++index) {
        NSURL *url = FallbackFixture(source, [NSString stringWithFormat:@"cover-candidate-%lu", (unsigned long)index]);
        if (!url) continue;
        {
            TagLib::MPEG::File file(url.fileSystemRepresentation);
            for (int kind = 0; kind < 2; ++kind) {
                auto *frame = new TagLib::ID3v2::AttachedPictureFrame;
                frame->setType(kind == 0 ? TagLib::ID3v2::AttachedPictureFrame::FrontCover : TagLib::ID3v2::AttachedPictureFrame::BackCover);
                frame->setMimeType("image/png"); frame->setPicture(Bytes(kind == 0 ? invalidCandidates[index] : back));
                file.ID3v2Tag(true)->addFrame(frame);
            }
            Check(file.save(), @"Save invalid-front valid-back fixture");
        }
        Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:back], @"Unreadable front artwork falls back to decodable back artwork");
        Check([TaglibMetadataParser extractCoverArtFromURL:url] != nil, @"Fallback cover decodes");
    }
    NSData *tiff = MakeImage(NSBitmapImageFileTypeTIFF, 60);
    NSURL *url = FallbackFixture(source, @"tiff-apic");
    if (!url) return;
    {
        TagLib::MPEG::File file(url.fileSystemRepresentation);
        auto *frame = new TagLib::ID3v2::AttachedPictureFrame;
        frame->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);
        frame->setMimeType("image/tiff"); frame->setPicture(Bytes(tiff));
        file.ID3v2Tag(true)->addFrame(frame);
        Check(file.save(), @"Save TIFF APIC fixture");
    }
    Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:tiff], @"Existing TIFF APIC bytes can be read");
    Check([TaglibMetadataParser extractCoverArtFromURL:url] != nil, @"Existing TIFF APIC decodes");
    NSData *before = [NSData dataWithContentsOfURL:url];
    Check(![TaglibMetadataParser setCoverArtData:tiff toFileURL:url], @"TIFF input remains unsupported for portable writes");
    Check([[NSData dataWithContentsOfURL:url] isEqualToData:before], @"Unsupported TIFF write preserves existing file");
}

static void TestNativeArtworkCreation(NSURL *source, NSData *png) {
    if ([@[@"wv", @"tta", @"ape", @"mpc"] containsObject:source.pathExtension]) {
        NSURL *url = MakeLegacyOnlyFixture(source, NO, @"legacy-cover-first");
        if (!url) return;
        Check([TaglibMetadataParser setCoverArtData:png toFileURL:url], [source.pathExtension stringByAppendingString:@" creates native artwork tag beside ID3v1"]);
        Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:png], @"First native artwork write reopens exactly");
        MetadataTagModel *metadata = [TaglibMetadataParser readMetadataWithFileURL:url readType:TaglibReaderTypeBasic];
        Equal(metadata.comment, @"short legacy comment", @"First artwork write preserves legacy comment");
    } else if ([source.pathExtension isEqualToString:@"dff"]) {
        NSURL *url = FallbackFixture(source, @"diin-cover-first");
        if (!url) return;
        {
            TagLib::DSDIFF::File file(url.fileSystemRepresentation);
            file.DIINTag(true)->setTitle("DIIN title");
            Check(file.save(TagLib::DSDIFF::File::DIIN, TagLib::File::StripOthers), @"Save DIIN-only DFF fixture");
        }
        Check([TaglibMetadataParser setCoverArtData:png toFileURL:url], @"DFF creates native artwork beside DIIN");
        Check([[TaglibMetadataParser extractCoverArtDataFromURL:url] isEqualToData:png], @"DIIN-only artwork write reopens exactly");
    }
}

static void TestFLACMetadataLimits(NSURL *source, NSData *png) {
    if (![source.pathExtension isEqualToString:@"flac"]) return;
    NSURL *art = FallbackFixture(source, @"oversized-flac-art");
    if (art) {
        NSMutableData *oversized = [png mutableCopy]; [oversized setLength:16 * 1024 * 1024 + 256];
        NSData *before = [NSData dataWithContentsOfURL:art];
        Check(![TaglibMetadataParser setCoverArtData:oversized toFileURL:art], @"FLAC artwork exceeding 24-bit block length is rejected");
        Check([[NSData dataWithContentsOfURL:art] isEqualToData:before], @"Oversized FLAC artwork rejection preserves every byte");
    }
    NSURL *comments = FallbackFixture(source, @"oversized-flac-comment");
    if (!comments) return;
    {
        TagLib::FLAC::File file(comments.fileSystemRepresentation);
        file.xiphComment(true)->setComment(TagLib::String(std::string(0xffff00 - 1024, 'x'), TagLib::String::UTF8));
        Check(file.xiphComment()->render(false).size() <= 0xffffff, @"Initial large Xiph block fits FLAC limit");
        Check(file.save(), @"Save near-limit Xiph fixture");
    }
    NSData *before = [NSData dataWithContentsOfURL:comments];
    NSString *lyrics = [@"x" stringByPaddingToLength:2048 withString:@"x" startingAtIndex:0];
    Check(![TaglibMetadataParser setLyrics:lyrics toFileURL:comments], @"Combined Xiph fields exceeding FLAC block limit are rejected");
    Check([[NSData dataWithContentsOfURL:comments] isEqualToData:before], @"Oversized combined Xiph rejection preserves every byte");
}

static void TestFallbackCompatibility(NSURL *source, NSData *png, NSData *jpeg, NSData *back) {
    TestLyricFieldAliases(source);
    TestUSLTCandidates(source);
    TestMP4FreeformLyrics(source);
    TestLegacyTimedComments(source);
    TestFLACArtworkFallbacks(source, png, jpeg);
    TestCoverCandidateFallbacks(source, png, back);
    TestNativeArtworkCreation(source, png);
    TestFLACMetadataLimits(source, png);
    TestRawAPEPictures(source, png);
    if ([source.pathExtension isEqualToString:@"mp3"]) TestLRCCompatibilityDetails();
}
