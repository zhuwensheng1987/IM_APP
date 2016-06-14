//
//  FFMovieViewController.h
//  FFPlayer
//
//  Created by Coremail on 14-1-14.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import <UIKit/UIKit.h>

@class KxMovieDecoder;
@protocol FFMovieCallback;

extern NSString * const FFMovieParameterMinBufferedDuration;    // Float
extern NSString * const FFMovieParameterMaxBufferedDuration;    // Float
extern NSString * const FFMovieParameterDisableDeinterlacing;   // BOOL

@interface FFMovieViewController : UIViewController

+ (id) movieViewControllerWithDelegate:(id <FFMovieCallback>)delegate;

@property (readonly) BOOL playing;
@property (nonatomic, weak)   id <FFMovieCallback> delegate;

- (void) play;
- (void) pause;

-(void) playMovie:(NSString *)path pos:(CGFloat)pos parameters: (NSDictionary *) parameters;

@end
