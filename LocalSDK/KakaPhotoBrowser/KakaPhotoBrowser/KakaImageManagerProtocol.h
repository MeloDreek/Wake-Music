//
//  KSWebImageProtocol.h
//  KakaPhotoBrowserDemo
//
//  Created by Kyle Sun on 22/05/2017.
//  Copyright © 2017 Kyle Sun. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^KakaImageManagerProgressBlock)(NSInteger receivedSize, NSInteger expectedSize);

typedef void (^KakaImageManagerCompletionBlock)(UIImage * _Nullable image, NSURL * _Nullable url, BOOL success, NSError * _Nullable error);

@protocol KakaImageManager

+ (Class _Nonnull)imageViewClass;

+ (void)setImageForImageView:(nullable UIImageView *)imageView
                     withURL:(nullable NSURL *)imageURL
                 placeholder:(nullable UIImage *)placeholder
                    progress:(nullable KakaImageManagerProgressBlock)progress
                  completion:(nullable KakaImageManagerCompletionBlock)completion;

+ (void)cancelImageRequestForImageView:(nullable UIImageView *)imageView;

+ (UIImage *_Nullable)imageFromMemoryForURL:(nullable NSURL *)url;

+ (UIImage *_Nullable)imageForURL:(nullable NSURL *)url;

@end
