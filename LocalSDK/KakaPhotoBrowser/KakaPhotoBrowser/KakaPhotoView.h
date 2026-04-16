//
//  KakaPhotoView.h
//  KakaPhotoBrowser
//
//  Created by Kyle Sun on 12/25/16.
//  Copyright © 2016 Kyle Sun. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KakaProgressLayer.h"

NS_ASSUME_NONNULL_BEGIN

extern const CGFloat kKakaPhotoViewPadding;

@protocol KakaImageManager;
@class KakaPhotoItem;

@interface KakaPhotoView : UIScrollView

@property (nonatomic, strong, readonly) UIImageView *imageView;
@property (nonatomic, strong, readonly) KakaProgressLayer *progressLayer;
@property (nonatomic, strong, readonly) KakaPhotoItem *item;
@property (class, nonatomic, strong) UIColor *backgroundColor;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)setItem:(KakaPhotoItem *)item determinate:(BOOL)determinate;
- (void)resizeImageView;
- (void)cancelCurrentImageLoad;

@end

NS_ASSUME_NONNULL_END
