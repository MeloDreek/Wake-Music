//
//  KakaPhotoBrowser.h
//  KakaPhotoBrowser
//
//  Created by Kyle Sun on 12/25/16.
//  Copyright © 2016 Kyle Sun. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KakaPhotoItem.h"
#import "KakaPhotoView.h"
#import "KakaImageManagerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, KakaPhotoBrowserInteractiveDismissalStyle) {
    KakaPhotoBrowserInteractiveDismissalStyleRotation,
    KakaPhotoBrowserInteractiveDismissalStyleScale,
    KakaPhotoBrowserInteractiveDismissalStyleSlide,
    KakaPhotoBrowserInteractiveDismissalStyleNone
};

typedef NS_ENUM(NSUInteger, KakaPhotoBrowserBackgroundStyle) {
    KakaPhotoBrowserBackgroundStyleBlurPhoto,
    KakaPhotoBrowserBackgroundStyleBlur,
    KakaPhotoBrowserBackgroundStyleBlack
};

typedef NS_ENUM(NSUInteger, KakaPhotoBrowserPageIndicatorStyle) {
    KakaPhotoBrowserPageIndicatorStyleDot,
    KakaPhotoBrowserPageIndicatorStyleText
};

typedef NS_ENUM(NSUInteger, KakaPhotoBrowserImageLoadingStyle) {
    KakaPhotoBrowserImageLoadingStyleIndeterminate,
    KakaPhotoBrowserImageLoadingStyleDeterminate
};

@protocol KakaPhotoBrowserDelegate, KakaImageManager;
@interface KakaPhotoBrowser : UIViewController

@property (nonatomic, assign) KakaPhotoBrowserInteractiveDismissalStyle dismissalStyle;
@property (nonatomic, assign) KakaPhotoBrowserBackgroundStyle backgroundStyle;
@property (nonatomic, assign) KakaPhotoBrowserPageIndicatorStyle pageindicatorStyle;
@property (nonatomic, assign) KakaPhotoBrowserImageLoadingStyle loadingStyle;
@property (nonatomic, assign) BOOL bounces;
@property (nonatomic, weak) id<KakaPhotoBrowserDelegate> delegate;
@property (class, nonatomic, strong) Class<KakaImageManager> imageManagerClass;
@property (class, nonatomic, strong) UIColor *imageViewBackgroundColor;

// 是否展示横幅广告，默认不展示
@property (nonatomic, assign) BOOL isShowAdBnner;

+ (instancetype)browserWithPhotoItems:(NSArray<KakaPhotoItem *> *)photoItems selectedIndex:(NSUInteger)selectedIndex;
- (instancetype)initWithPhotoItems:(NSArray<KakaPhotoItem *> *)photoItems selectedIndex:(NSUInteger)selectedIndex;
- (void)showFromViewController:(UIViewController *)vc;

- (UIImage *)imageForItem:(KakaPhotoItem *)item;
- (UIImage *)imageAtIndex:(NSUInteger)index;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray <KakaPhotoItem *>*photoItems;
@property (nonatomic, strong) NSMutableSet *reusableItemViews;
@property (nonatomic, strong) NSMutableArray <KakaPhotoView *>*visibleItemViews;
@property (nonatomic, assign) NSUInteger currentPage;
@property (nonatomic, strong) UIImageView *backgroundView;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) UILabel *pageLabel;
@property (nonatomic, assign) BOOL presented;
@property (nonatomic, assign) CGPoint startLocation;
@property (nonatomic, assign) CGRect startFrame;
@property (nonatomic, strong) UILabel *contentLabel;


// 正在拖拽消失
@property (nonatomic, assign) BOOL isDismissing;

// 点击事件
- (void)didSingleTap:(UITapGestureRecognizer *)tap;

// 双击事件
- (void)didDoubleTap:(UITapGestureRecognizer *)tap;

// 长按事件
- (void)didLongPress:(UILongPressGestureRecognizer *)longPress;

// 关闭事件
- (void)showDismissalAnimation;

@end

@protocol KakaPhotoBrowserDelegate <NSObject>

@optional
- (void)kaka_photoBrowser:(KakaPhotoBrowser *)browser didSelectItem:(KakaPhotoItem *)item atIndex:(NSUInteger)index;

// If you do not implement this method, there will be a default implementation which will call the system share sheet `UIActivityViewController`
- (void)kaka_photoBrowser:(KakaPhotoBrowser *)browser didLongPressItem:(KakaPhotoItem *)item atIndex:(NSUInteger)index;

// 关闭
- (void)kaka_photoBrowserDidDismiss:(KakaPhotoBrowser *)browser;

@end

NS_ASSUME_NONNULL_END
