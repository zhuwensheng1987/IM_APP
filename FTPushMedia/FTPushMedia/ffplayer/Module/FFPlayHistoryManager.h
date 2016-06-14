//
//  FFPlayHistoryManager.h
//  FFPlayer
//
//  Created by Coremail on 14-1-28.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface FFPlayHistoryManager : NSObject

+(FFPlayHistoryManager *)default;

-(id) init;
-(CGFloat) getLastPlayInfo:(NSString *)key playCount:(int *)playCount;
-(void) updateLastPlayInfo:(NSString *)key pos:(CGFloat)pos;

@end
