//
//  KakaScrollView.m
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2022/4/17.
//

#import "KakaScrollView.h"

@implementation KakaScrollView

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ( [gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] )  {
        if (self.zoomScale > 1) {
            return NO;
        }
        return YES;
    }
    if (![gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    
    if (_canLeftAndRight) {
        if ([otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
            NSString *className = NSStringFromClass(otherGestureRecognizer.view.class);
            //button手势移动的时候也不处理
            if ([className isEqualToString:@"UIButton"] ||
                [className isEqualToString:@"UITableView"]) {
                return NO;
            }
            CGPoint velocity = [(UIPanGestureRecognizer *)otherGestureRecognizer velocityInView:self];
            if (velocity.x > 0 && self.contentOffset.x == 0) {
                return YES;
            }
            else if ( velocity.x <= 0 && (self.contentOffset.x + self.frame.size.width ) >= self.contentSize.width) {
                return YES;
            }
        }
    }
    return NO;
}


@end
