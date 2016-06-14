//
//  FFPlayer.m
//  FFPlayer
//
//  Created by Coremail on 14-1-14.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import "FFHelper.h"
#import "FFPlayer.h"
#import "FFSetting.h"
#import "FFMovieViewController.h"
#import "FFInternalMoviePlayerController.h"
#import "ALMoviePlayerControls.h"
#import "KxMovieDecoder.h"
#import "FFPlayHistoryManager.h"

@implementation FFPlayItem

-(id) initWithPath:(NSString *)url position:(CGFloat) position keyName:(NSString *)keyName
{
    self = [super init];
    if ( self ) {
        self->_position = position;
        self->_url = url;
        self->_keyName = keyName;
    }
    return self;
}

@end

////////////////////////////////////////

@interface FFPlayer () <FFMovieCallback>
{
    NSArray * _playList;
    int         _curIndex;
    __weak UIViewController *  _parentView;
    UIViewController *         _lastController;
    KxMovieDecoder *           _decoder;
    BOOL                       _forceInternal;
    NSString *                 _curPlaying;
}
@end

@implementation FFPlayer

-(id) init
{
    self = [super init];
    if ( self ) {
        self->_playList = nil;
        self->_curIndex  = 0;
        self->_parentView = nil;
        self->_lastController = nil;
        self->_decoder = nil;
        self->_forceInternal = NO;
    }
    
    return self;
}

-(NSArray *)getMediaInfo:(NSString *)url
{
    if ( _decoder == nil ) {
        _decoder = [[KxMovieDecoder alloc] init];
    }
    NSError *error = nil;
    [_decoder openFile:url error:&error];
    if ( _decoder.isNetwork || error != nil )
        return nil;
    NSArray * aryResult = [_decoder.info copy];
    [_decoder closeFile];
    return aryResult;
}

-(UIViewController *)internalPlayList:(NSArray *)aryList curIndex:(int)curIndex parent:(UIViewController *)parent
{
    _forceInternal = YES;
    return [self playList:aryList curIndex:curIndex parent:parent];
}

-(UIViewController *)playList:(NSArray *)aryList curIndex:(int)curIndex parent:(UIViewController *)parent
{
    _playList = aryList;
    _parentView = parent;
    _curIndex = curIndex;
    if ( _playList.count == 0 || curIndex < 0 || curIndex >= _playList.count )
        return nil;
    
    return [self play:_playList[_curIndex] animated:NO];
}

-(BOOL) hasNext
{
    return _curIndex < _playList.count - 1;
}

-(BOOL) hasPre
{
    return _curIndex > 0;
}

+(UIViewController *) playInController:(UIViewController *)vc item:(FFPlayItem *)item
{
    NSMutableDictionary * parameters = [[NSMutableDictionary alloc] init];
    [parameters setObject:[item.keyName lastPathComponent] forKey:@"display"];
    NSString * path = item.url;
    
    if ( [vc isKindOfClass:[FFInternalMoviePlayerController class]] ) {
        FFInternalMoviePlayerController * vc1 = (FFInternalMoviePlayerController *)vc;
        [vc1 playMovie:path pos:item.position parameters:parameters];
    } else {
        FFMovieViewController * vc2 = (FFMovieViewController *)vc;
        
        if ([path.pathExtension isEqualToString:@"wmv"])
            parameters[FFMovieParameterMinBufferedDuration] = @(5.0);
        
        // disable deinterlacing for iPhone, because it's complex operation can cause stuttering
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            parameters[FFMovieParameterDisableDeinterlacing] = @(YES);
        
        [vc2 playMovie:path pos:item.position parameters:parameters];
    }
    
    return vc;
}

-(UIViewController *) play:(FFPlayItem *)item animated:(BOOL)animated
{
    if ( _forceInternal || [FFHelper isInternalPlayerSupport:item.url] ) {
        
        if ( _lastController != nil && [_lastController isKindOfClass:[FFInternalMoviePlayerController class]]) {
            [FFPlayer playInController:_lastController item:item];
        } else {
            FFInternalMoviePlayerController * vc1 = [FFInternalMoviePlayerController movieViewControllerWithDelegate:self];
            _lastController = [FFPlayer playInController:vc1 item:item];
        }
    } else {
        FFMovieViewController * vc2 = [FFMovieViewController movieViewControllerWithDelegate:self];
        _lastController = [FFPlayer playInController:vc2 item:item];
    }
 
    _curPlaying = item.keyName;
    [_parentView presentViewController:_lastController animated:animated completion:nil];
    return _lastController;
}

-(void) onDoneWithPos:(CGFloat)curPos
{
    if ( _curPlaying != nil )
        [[FFPlayHistoryManager default] updateLastPlayInfo:_curPlaying pos:curPos ];
}

-(void) onFinish:(UIViewController *)control curPos:(CGFloat)curPos
{
    if ( [[FFSetting default] autoPlayNext] )
        [self onNext:control curPos:curPos];
    else {
        if ( _curPlaying != nil )
            [[FFPlayHistoryManager default] updateLastPlayInfo:_curPlaying pos:curPos ];
        [control dismissViewControllerAnimated:YES completion:nil];
    }
}

-(void) onNext:(UIViewController *)control curPos:(CGFloat)curPos
{
    if ( _curPlaying != nil )
        [[FFPlayHistoryManager default] updateLastPlayInfo:_curPlaying pos:curPos ];

    if ( [self hasNext] ) {
        ++_curIndex;
        FFPlayItem * item = _playList[_curIndex];
        if ( control != nil && [control isKindOfClass:[FFInternalMoviePlayerController class]] && [FFHelper isInternalPlayerSupport:item.url]) {
            [FFPlayer playInController:control item:item];
        } else {
            [control dismissViewControllerAnimated:NO completion:nil];
            [self play:_playList[_curIndex] animated:NO];
        }
    } else
        [control dismissViewControllerAnimated:YES completion:nil];
}

-(void) onPre:(UIViewController *)control curPos:(CGFloat)curPos
{
    if ( _curPlaying != nil )
        [[FFPlayHistoryManager default] updateLastPlayInfo:_curPlaying pos:curPos ];

    if ( [self hasPre] ) {
        --_curIndex;
        FFPlayItem * item = _playList[_curIndex];
        if ( control != nil && [control isKindOfClass:[FFInternalMoviePlayerController class]] && [FFHelper isInternalPlayerSupport:item.url]) {
            [FFPlayer playInController:control item:item];
        } else {
            [control dismissViewControllerAnimated:NO completion:nil];
            [self play:_playList[_curIndex] animated:NO];
        }
            
    } else
        [control dismissViewControllerAnimated:YES completion:nil];
}

@end
