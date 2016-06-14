//
//  ViewController.h
//  kxmovieapp
//
//  Created by Kolyvan on 11.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>

@class KxMovieDecoder;
@protocol KxMovieCallback;

extern NSString * const KxMovieParameterMinBufferedDuration;    // Float
extern NSString * const KxMovieParameterMaxBufferedDuration;    // Float
extern NSString * const KxMovieParameterDisableDeinterlacing;   // BOOL

@interface KxMovieViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>

+ (id) movieViewControllerWithContentPath: (NSString *) path
                               parameters: (NSDictionary *) parameters;

+ (id) movieViewControllerWithDelegate:(id <KxMovieCallback>)delegate;

@property (readonly) BOOL playing;
@property (nonatomic, weak)   id <KxMovieCallback> delegate;

- (void) play;
- (void) pause;

-(void) playMovie:(NSString *)path pos:(CGFloat)pos parameters: (NSDictionary *) parameters;

@end

@protocol KxMovieCallback <NSObject>

-(BOOL) hasNext;
-(BOOL) hasPre;
-(void) onNext:(KxMovieViewController *)control curPos:(CGFloat)curPos;
-(void) onPre:(KxMovieViewController *)control curPos:(CGFloat)curPos;

@end


