//
//  KakaProgressLayer.h
//  KakaPhotoBrowser
//
//  Created by Kyle Sun on 30/12/2016.
//  Copyright © 2016 Kyle Sun. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KakaProgressLayer : CAShapeLayer

- (instancetype)initWithFrame:(CGRect)frame;
- (void)startSpin; 
- (void)stopSpin;

@end

NS_ASSUME_NONNULL_END
