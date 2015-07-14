//
//  UIAlertView+Block.h
//  Epailive
//
//  Created by Zhu wensheng on 14-5-6.
//  Copyright (c) 2014年 Zhu wensheng. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^CompleteBlock) (NSInteger buttonIndex);

@interface UIAlertView (Block)

// 用Block的方式回调，这时候会默认用self作为Delegate
- (void)showAlertViewWithCompleteBlock:(CompleteBlock) block;

@end
