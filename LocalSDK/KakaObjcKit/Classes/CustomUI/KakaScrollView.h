//
//  KakaScrollView.h
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2022/4/17.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KakaScrollView : UIScrollView

@property (nonatomic, assign) BOOL isAutoOK;

@property (nonatomic, assign) BOOL leftCanBack;

@property (nonatomic, assign) BOOL downCanBack;

@property (nonatomic, assign) BOOL canLeftAndRight;

@end

NS_ASSUME_NONNULL_END
