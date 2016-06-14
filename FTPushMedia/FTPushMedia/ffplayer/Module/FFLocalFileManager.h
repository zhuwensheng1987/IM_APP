//
//  FFLocalFileManager.h
//  FFPlayer
//
//  Created by Coremail on 14-1-17.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

typedef enum {
    LIT_PARENT,
    LIT_SECRETE,
    LIT_DIR,
    LIT_FOLDER_DEF_END,
    
    LIT_MIDEA,
    LIT_PIC,
    LIT_ZIP,
    LIT_UNKNOWN
} LOCAL_ITEM_TYPE;

@interface FFLocalItem : NSObject
@property (retain,atomic)   NSString *  fullPath;
@property (retain,atomic)   NSString *  fileName;
@property (retain,atomic)   NSDate *    modifyTime;
@property (assign)  unsigned long long  size;
@property (assign)  LOCAL_ITEM_TYPE     type;
@property (readonly, getter = isDir)   BOOL   isDir;
@property (readonly, getter = sortNameHelper)   int    sortNameHelper;
@property (readonly)  BOOL          editable;
@property (assign) int              random;
@property (assign) CGFloat          lastPos;
@property (assign) int              playCount;

-(id) initWithPath:(NSString *)strPath type:(LOCAL_ITEM_TYPE)type;
-(id) initWithAttributes:(NSDictionary *) attrs path:(NSString *)strPath;
@end

////////////////////////////////////////////////////

@interface FFLocalFileManager : NSObject

+(NSString *) getRootFullPath;
+(NSString *) getSecretRootPath;

+(NSString *) getPlayHistoryPath;
+(NSString *) getURLHistoryPath;
+(NSString *) getSparkSvrListPath;

+(NSString *) getCurrentFolder:(NSString *) strSubPath inSecret:(BOOL) inSecret;
+(NSArray *) listFolder:(NSString *)folder  subPath:(NSString *)strSubPath inSecret:(BOOL) inSecret;
+(NSString *) uncompress:(NSString *)fullPath;

@end
