//
//  KakaPhotoView.m
//  KakaPhotoBrowser
//
//  Created by Kyle Sun on 12/25/16.
//  Copyright © 2016 Kyle Sun. All rights reserved.
//

#import "KakaPhotoView.h"
#import "KakaPhotoItem.h"
#import "KakaProgressLayer.h"
#import "KakaPhotoBrowser.h"

const CGFloat kKakaPhotoViewPadding = 10;
const CGFloat kKakaPhotoViewMaxScale = 3;

static UIColor *BackgroundColor = nil;

@interface KakaPhotoView ()<UIScrollViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong, readwrite) UIImageView *imageView;
@property (nonatomic, strong, readwrite) KakaProgressLayer *progressLayer;
@property (nonatomic, strong, readwrite) KakaPhotoItem *item;

@end

@implementation KakaPhotoView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.bouncesZoom = YES;
        self.maximumZoomScale = kKakaPhotoViewMaxScale;
        
        self.multipleTouchEnabled = YES;
        self.showsHorizontalScrollIndicator = YES;
        self.showsVerticalScrollIndicator = YES;
        self.delegate = self;
        if (@available(iOS 11.0, *)) {
            self.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        
        _imageView = [[[KakaPhotoBrowser.imageManagerClass imageViewClass]  alloc] init];
        _imageView.backgroundColor = KakaPhotoView.backgroundColor;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        [self addSubview:_imageView];
        [self resizeImageView];
        
        _progressLayer = [[KakaProgressLayer alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        
        _progressLayer.hidden = YES;
        [self.layer addSublayer:_progressLayer];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _progressLayer.position = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
}

- (void)setItem:(KakaPhotoItem *)item determinate:(BOOL)determinate {
    _item = item;
    [KakaPhotoBrowser.imageManagerClass cancelImageRequestForImageView:_imageView];
    
    if (item) {
        if (item.image) {
            _imageView.image = item.image;
            _item.finished = YES;
            [_progressLayer stopSpin];
            _progressLayer.hidden = YES;
            [self resizeImageView];
            return;
        }
        __weak typeof(self) wself = self;
        KakaImageManagerProgressBlock progressBlock = nil;
        if (determinate) {
            progressBlock = ^(NSInteger receivedSize, NSInteger expectedSize) {
                __strong typeof(wself) sself = wself;
                double progress = (double)receivedSize / expectedSize;
                sself.progressLayer.hidden = NO;
                sself.progressLayer.strokeEnd = MAX(progress, 0.01);
            };
        } else {
            [_progressLayer startSpin];
        }
        _progressLayer.hidden = NO;
        
        _imageView.image = item.thumbImage;
        [KakaPhotoBrowser.imageManagerClass setImageForImageView:_imageView withURL:item.imageUrl placeholder:item.thumbImage progress:progressBlock completion:^(UIImage *image, NSURL *url, BOOL finished, NSError *error) {
            __strong typeof(wself) sself = wself;
            if (finished) {
                [sself resizeImageView];
            }
            [sself.progressLayer stopSpin];
            sself.progressLayer.hidden = YES;
            sself.item.finished = YES;
        }];
    } else {
        [_progressLayer stopSpin];
        _progressLayer.hidden = YES;
        _imageView.image = nil;
    }
    [self resizeImageView];
}

- (void)resizeImageView {
    if (_imageView.image) {
        CGSize imageSize = _imageView.image.size;
        CGFloat viewWidth = self.bounds.size.width - 2 * kKakaPhotoViewPadding;
        CGFloat viewHeight = self.bounds.size.height - 2 * kKakaPhotoViewPadding;
        
        CGFloat imgWidth, imgHeight;
        
        if (imageSize.width / imageSize.height > viewWidth / viewHeight) {
            // 图片宽度大于高度，以宽度为准计算高度
            imgWidth = viewWidth;
            imgHeight = imgWidth * (imageSize.height / imageSize.width);
        } else {
            // 图片高度大于宽度，以高度为准计算宽度
            imgHeight = viewHeight;
            imgWidth = imgHeight * (imageSize.width / imageSize.height);
        }
        
        CGRect imgRect = CGRectMake((self.frame.size.width - imgWidth) / 2, (self.frame.size.height - imgHeight) / 2, imgWidth, imgHeight);
        _imageView.frame = imgRect;
        
        // 确保图片能够缩放到全屏
        self.maximumZoomScale = MAX(self.bounds.size.width / imgWidth, self.bounds.size.height / imgHeight);
    } else {
        CGFloat width = self.bounds.size.width - 2 * kKakaPhotoViewPadding;
        _imageView.frame = CGRectMake(0, 0, width, width * 2.0 / 3);
        _imageView.center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    }
    
    self.contentSize = _imageView.frame.size;
    
    // 确保图片默认显示全部内容
    CGFloat scale = MIN(self.bounds.size.width / _imageView.frame.size.width, self.bounds.size.height / _imageView.frame.size.height);
    self.minimumZoomScale = scale;
    self.zoomScale = scale;
}

- (void)cancelCurrentImageLoad {
    [KakaPhotoBrowser.imageManagerClass cancelImageRequestForImageView:_imageView];
    [_progressLayer stopSpin];
}

- (BOOL)isScrollViewOnTopOrBottom {
    CGPoint translation = [self.panGestureRecognizer translationInView:self];
    if (translation.y > 0 && self.contentOffset.y <= 0) {
        return YES;
    }
    CGFloat maxOffsetY = floor(self.contentSize.height - self.bounds.size.height);
    if (translation.y < 0 && self.contentOffset.y >= maxOffsetY) {
        return YES;
    }
    return NO;
}


#pragma mark - ScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    CGFloat offsetX = (scrollView.bounds.size.width > scrollView.contentSize.width)?
    (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0;
    
    CGFloat offsetY = (scrollView.bounds.size.height > scrollView.contentSize.height)?
    (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0;
    
    _imageView.center = CGPointMake(scrollView.contentSize.width * 0.5 + offsetX,
                                 scrollView.contentSize.height * 0.5 + offsetY);
}

#pragma mark - GestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.panGestureRecognizer) {
        if (gestureRecognizer.state == UIGestureRecognizerStatePossible) {
            if ([self isScrollViewOnTopOrBottom]) {
                return NO;
            }
        }
    }
    return YES;
}

#pragma mark - Setter & Getter

+ (void)setBackgroundColor:(UIColor *)backgroundColor {
    BackgroundColor = backgroundColor;
}

+ (UIColor *)backgroundColor {
    return BackgroundColor ?: UIColor.darkGrayColor;
}


@end
