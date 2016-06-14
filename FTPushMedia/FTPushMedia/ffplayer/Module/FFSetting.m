//
//  FFSetting.m
//  FFPlayer
//
//  Created by Coremail on 14-1-17.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import "FFSetting.h"
#import "FFHelper.h"

@interface FFSetting ()
{
    NSUserDefaults * _setting;
    BOOL            _unlock;
}
@end

@implementation FFSetting

-(id) init
{
    self = [super init];
    self->_setting = [NSUserDefaults standardUserDefaults];
    self->_unlock = FALSE;
    return self;
}

+(FFSetting *)default
{
    static FFSetting * setting = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setting = [[FFSetting alloc] init];
    });
    return setting;
}

-(BOOL) enableInternalPlayer
{
    return ![_setting integerForKey:@"forbit_internal_player"];
}

-(void) setEnableInternalPlayer:(BOOL) bo
{
    [_setting setInteger:bo?0:1 forKey:@"forbit_internal_player"];
    [_setting synchronize];
}

-(BOOL) autoPlayNext
{
    return ![_setting integerForKey:@"pause_after_play"];
}

-(void) setAutoPlayNext:(BOOL) bo
{
    [_setting setInteger:bo?0:1 forKey:@"pause_after_play"];
    [_setting synchronize];
}

-(int) sortType
{
    return [_setting integerForKey:@"sort_type"];
}

-(void) setSortType:(int) type
{
    [_setting setInteger:type forKey:@"sort_type"];
    [_setting synchronize];
}

-(int) sparkSortType
{
    return [_setting integerForKey:@"spark_sort_type"];
}

-(void) setSparkSortType:(int) type
{
    [_setting setInteger:type forKey:@"spark_sort_type"];
    [_setting synchronize];
}

-(int) seekDelta
{
    int n = [_setting integerForKey:@"seek_delta"];
    if ( n == 0 )
        n = 10;
    return n;
}

-(void) setSeekDelta:(int) n
{
    [_setting setInteger:n forKey:@"seek_delta"];
    [_setting synchronize];
}

-(BOOL) scalingModeFit
{
    return [_setting integerForKey:@"scaling_mode"] != 2;
}

-(void) setScalingMode:(int)n
{
    [_setting setInteger:n forKey:@"scaling_mode"];
    [_setting synchronize];
}

-(int) lastSelectedTab
{
    return [_setting integerForKey:@"last_tab"];
}

-(void) setLastSelectedTab:(int)n
{
    [_setting setInteger:n forKey:@"last_tab"];
    [_setting synchronize];
}

-(BOOL) hasPassword
{
    return [_setting stringForKey:@"password"] != nil;
}

-(BOOL) checkPassword:(NSString *)str
{
    NSString * enc = [FFHelper md5HexDigest:str];
    NSString * save = [_setting stringForKey:@"password"];
    return ( [enc isEqualToString:save]);
}

-(void) setPassword:(NSString *)str
{
    if ( str == nil )
        return;
    [_setting setObject:[FFHelper md5HexDigest:str] forKey:@"password"];
    [_setting synchronize];
}

-(BOOL) unlock
{
    return _unlock;
}

-(void) setUnlock:(BOOL) bo
{
    _unlock = bo;
}

-(int) webPort
{
    int n = [_setting integerForKey:@"web_port"];
    if ( n == 0 )
        n = 8080;
    return n;
}

-(void) setWebPort:(int)nPort
{
    [_setting setInteger:nPort forKey:@"web_port"];
    [_setting synchronize];
}

-(int) bandwidth
{
    int n = [_setting integerForKey:@"band_width"];
    if ( n == 0 )
        n = 10000;
    return n;
}
-(void) setBandwidth:(int) n
{
    [_setting setInteger:n forKey:@"band_width"];
    [_setting synchronize];
}

-(int) resolution
{
    int n = [_setting integerForKey:@"resolution"];
    if ( n == 0 )
        n = 1024;
    return n;
}

-(void) setResolution:(int) n
{
    [_setting setInteger:n forKey:@"resolution"];
    [_setting synchronize];
}

-(int) boost
{
    return [_setting integerForKey:@"boost"];
}

-(void) setBoost:(int)n
{
    [_setting setInteger:n forKey:@"boost"];
    [_setting synchronize];
}

@end
