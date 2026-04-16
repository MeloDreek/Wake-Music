#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "LyricLineModel.h"
#import "MetadataTagModel.h"
#import "NSURL+Permission.h"
#import "TagLibHeader.h"
#import "TaglibMetadataParser.h"

FOUNDATION_EXPORT double KakaTaglibKitVersionNumber;
FOUNDATION_EXPORT const unsigned char KakaTaglibKitVersionString[];

