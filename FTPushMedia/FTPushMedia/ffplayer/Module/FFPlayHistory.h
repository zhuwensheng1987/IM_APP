//
//  FFPlayHistory.h
//  FFPlayer
//
//  Created by cyt on 14-1-26.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface FFPlayHistory : NSObject <NSCoding>

@property (atomic, retain)  NSString *  url;
@property (assign)      CGFloat         lastPos;
@property (assign)      int                 count;
@property (atomic, retain)  NSDate *      lastPlayTime;

@end
