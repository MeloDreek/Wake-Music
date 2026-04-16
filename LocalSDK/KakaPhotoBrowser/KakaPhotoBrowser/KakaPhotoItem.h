//
//  KakaPhotoItem.h
//  KakaPhotoBrowser
//
//  Created by Kyle Sun on 12/25/16.
//  Copyright © 2016 Kyle Sun. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Photos/PHAsset.h>

@interface KakaPhotoItem : NSObject

@property (nonatomic, strong, nullable) UIView *sourceView;
@property (nonatomic, strong, readonly, nullable) UIImage *thumbImage;
@property (nonatomic, strong, readonly, nullable) UIImage *image;
@property (nonatomic, strong, readonly, nullable) NSURL *imageUrl;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, strong, readonly, nullable) PHAsset * asset;
@property (nonatomic, copy, readonly, nullable) NSString *content;

- (nonnull instancetype)initWithSourceView:(nullable UIView *)view
                                thumbImage:(nullable UIImage *)image
                                  imageUrl:(nullable NSURL *)url;
- (nonnull instancetype)initWithSourceView:(nullable UIImageView * )view
                                  imageUrl:(nullable NSURL *)url;
- (nonnull instancetype)initWithSourceView:(nullable UIImageView *)view
                                     image:(nullable UIImage *)image;

+ (nonnull instancetype)itemWithSourceView:(nullable UIView *)view
                                thumbImage:(nullable UIImage *)image
                                  imageUrl:(nullable NSURL *)url;
+ (nonnull instancetype)itemWithSourceView:(nullable UIImageView *)view
                                  imageUrl:(nullable NSURL *)url;
+ (nonnull instancetype)itemWithSourceView:(nullable UIImageView *)view
                                     image:(nullable UIImage *)image;

// 加载本地云相册
+ (nonnull instancetype)itemWithSourceView:(nullable UIImageView *)view
                                     image:(nullable UIImage *)image
                                     asset:(nullable PHAsset *)asset;

// 加载本地图片+文字
+ (nonnull instancetype)itemWithSourceView:(nullable UIImageView *)view
                                   content:(nullable NSString *)content;

@end
