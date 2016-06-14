//
//  FFInternalMoviePlayerController.h
//  FFPlayer
//
//  Created by cyt on 14-1-14.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import <MediaPlayer/MediaPlayer.h>

@protocol FFMovieCallback;

@interface FFInternalMoviePlayerController : UIViewController

+ (id) movieViewControllerWithDelegate:(id <FFMovieCallback>)delegate;

@property (readonly) BOOL playing;
@property (nonatomic, weak)   id <FFMovieCallback> delegate;

- (void) play;
- (void) pause;

-(void) playMovie:(NSString *)path pos:(CGFloat)pos parameters: (NSDictionary *) parameters;

@end
