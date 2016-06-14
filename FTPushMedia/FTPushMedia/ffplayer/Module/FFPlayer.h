//
//  FFPlayer.h
//  FFPlayer
//
//  Created by Coremail on 14-1-14.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FFPlayItem : NSObject
@property (retain,atomic) NSString *    url;
@property (assign) CGFloat              position;
@property (retain,atomic) NSString *    keyName;

-(id) initWithPath:(NSString *)url position:(CGFloat)position keyName:(NSString *)keyName;

@end

@interface FFPlayer : NSObject

-(id) init;
-(UIViewController *)playList:(NSArray *)aryList curIndex:(int)curIndex parent:(UIViewController *)parent;
-(UIViewController *)internalPlayList:(NSArray *)aryList curIndex:(int)curIndex parent:(UIViewController *)parent;

-(NSArray *)getMediaInfo:(NSString *)url;

@end
