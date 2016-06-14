//
//  FFPlayHistoryManager.m
//  FFPlayer
//
//  Created by Coremail on 14-1-28.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import "FFPlayHistoryManager.h"
#import "FMDatabase.h"
#import "FFSetting.h"
#import "FFLocalFileManager.h"

@interface FFPlayHistoryManager ()
{
    FMDatabase * _database;
}
@end

//////////////////////////////////////////////////

@implementation FFPlayHistoryManager

-(id) init
{
    self = [super init];
    
    if ( self != nil ) {
        NSString * path = [FFLocalFileManager getPlayHistoryPath];
        _database = [FMDatabase databaseWithPath:path];
        _database.traceExecution = YES;
        if ( ![_database open] ) {
            NSLog(@"Create table error : %@", [_database lastError]);
            _database = nil;
        } else {
            if ( ![_database executeUpdate:@"create table if not exists history (path text primary key, pos real, pcnt integer default 0, modtime text)"] ) {
                NSLog(@"Create table error : %@", [_database lastError]);
            } else {
                if ( ![_database executeUpdate:@"delete from history where modtime < date('now', '-1 years')"])
                    NSLog(@"Delete expire data error : %@", [_database lastError]);
            }
        }
    }
    return self;
}

-(void) dealloc {
    if ( _database != nil )
        [_database close];
}

+(FFPlayHistoryManager *)default
{
    static FFPlayHistoryManager * setting = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setting = [[FFPlayHistoryManager alloc] init];
    });
    return setting;
}

-(NSString *) convertKey:(NSString *)key
{
    NSString * root = [[NSSearchPathForDirectoriesInDomains(NSApplicationDirectory,
                                                           NSUserDomainMask,
                                                           YES) lastObject] stringByDeletingLastPathComponent];
    if ( [key hasPrefix:root])
        return [key substringFromIndex:root.length];
    return key;
}

-(CGFloat) getLastPlayInfo:(NSString *)key playCount:(int *)playCount
{
    *playCount = 0;
    CGFloat res = 0.0f;
    if ( ![key hasPrefix:NSTemporaryDirectory()] && _database != nil ) {
        FMResultSet *rs = [_database executeQuery:@"select * from history where path=?", [self convertKey:key]];
        if ([rs next]) {
            res = (CGFloat)[rs doubleForColumn:@"pos"];
            *playCount = [rs intForColumn:@"pcnt"];
        }
        [rs close];
    }
    return res;
}

-(void) updateLastPlayInfo:(NSString *)key pos:(CGFloat)pos
{
    if ( [key hasPrefix:NSTemporaryDirectory()] || _database == nil )
        return;
    else if ( ![_database executeUpdate:@"update history set pos=?, pcnt=pcnt+1, modtime=date('now') where path=?", [NSNumber numberWithFloat:pos], [self convertKey:key]]
        || [_database changes] == 0 )
        [_database executeUpdate:@"insert into history (path,pos,pcnt,modtime) values(?,?,1,date('now'))", [self convertKey:key], [NSNumber numberWithFloat:pos]];
}

@end
