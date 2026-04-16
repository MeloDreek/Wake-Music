//
//  KakaPhotoItem.m
//  KakaPhotoBrowser
//
//  Created by Kyle Sun on 12/25/16.
//  Copyright © 2016 Kyle Sun. All rights reserved.
//

#import "KakaPhotoItem.h"

@interface KakaPhotoItem ()

@property (nonatomic, strong, readwrite) UIImage *thumbImage;
@property (nonatomic, strong, readwrite) UIImage *image;
@property (nonatomic, strong, readwrite) NSURL *imageUrl;
@property (nonatomic, strong, readwrite) PHAsset *asset;
@property (nonatomic, copy, readwrite) NSString *content;
@end

@implementation KakaPhotoItem

- (instancetype)initWithSourceView:(UIView *)view
                        thumbImage:(UIImage *)image
                          imageUrl:(NSURL *)url {
    self = [super init];
    if (self) {
        _sourceView = view;
        _thumbImage = image;
        _imageUrl = url;
    }
    return self;
}

- (instancetype)initWithSourceView:(UIImageView *)view
                        thumbImage:(UIImage *)image
                          asset:(PHAsset *)asset {
    self = [super init];
    if (self) {
        _sourceView = view;
        _thumbImage = image;
        _imageUrl = nil;
        _asset = asset;
    }
    return self;
}

- (instancetype)initWithSourceView:(UIImageView *)view
                          imageUrl:(NSURL *)url
{
    return [self initWithSourceView:view
                         thumbImage:view.image
                           imageUrl:url];
}

- (instancetype)initWithSourceView:(UIImageView *)view
                             image:(UIImage *)image {
    self = [super init];
    if (self) {
        _sourceView = view;
        _thumbImage = image;
        _imageUrl = nil;
        _image = image;
    }
    return self;
}

- (instancetype)initWithSourceView:(UIImageView *)view
                             image:(UIImage *)image
                           content:(NSString *)content {
    self = [super init];
    if (self) {
        _sourceView = view;
        _thumbImage = image;
        _imageUrl = nil;
        _image = image;
        _content = content;
    }
    return self;
}

+ (instancetype)itemWithSourceView:(UIView *)view
                        thumbImage:(UIImage *)image
                          imageUrl:(NSURL *)url
{
    return [[KakaPhotoItem alloc] initWithSourceView:view
                                    thumbImage:image
                                      imageUrl:url];
}

+ (instancetype)itemWithSourceView:(UIImageView *)view
                          imageUrl:(NSURL *)url
{
    return [[KakaPhotoItem alloc] initWithSourceView:view
                                          imageUrl:url];
}

+ (instancetype)itemWithSourceView:(UIImageView *)view
                             image:(UIImage *)image
{
    return [[KakaPhotoItem alloc] initWithSourceView:view
                                             image:image];
}

+ (instancetype)itemWithSourceView:(UIImageView *)view image:(UIImage *)image asset:(PHAsset *)asset {
    return [[KakaPhotoItem alloc]initWithSourceView:view thumbImage:image asset:asset];
}

+ (instancetype)itemWithSourceView:(UIImageView *)view content:(NSString *)content {
    return [[KakaPhotoItem alloc]initWithSourceView:view image:view.image content:content];
}

@end
