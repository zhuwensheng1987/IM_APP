//
//  FFLocalFileManager.m
//  FFPlayer
//
//  Created by Coremail on 14-1-17.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import "FFLocalFileManager.h"
#import "FFHelper.h"
#import "FFSetting.h"
#import "FFPlayHistoryManager.h"
#import "MiniZip.h"
#import "UnRAR.h"
#import "LZMAExtractor.h"

/////////////////////////////////////////////////////

@implementation FFLocalItem

-(id) initWithPath:(NSString *)strPath type:(LOCAL_ITEM_TYPE)type
{
    self = [super init];
    if ( self ) {
        self.fullPath = strPath;
        self.fileName = [[strPath pathComponents] lastObject];
        self.type = type;
        self.size = 0;
        self.modifyTime = nil;
    }
    return self;
}

-(id) initWithAttributes:(NSDictionary *) attr path:(NSString *)strPath
{
    self = [super init];
    if ( self ) {
        id fileType = [attr valueForKey:NSFileType];
        
        self.fullPath = strPath;
        self.fileName = [[strPath pathComponents] lastObject];
        if ([fileType isEqual:NSFileTypeDirectory] )
            self.type = LIT_DIR;
        else if (  [FFHelper isSupportMidea:strPath] )
            self.type = LIT_MIDEA;
        else if ( [FFHelper isSupportPic:strPath])
            self.type = LIT_PIC;
        else if ( [FFHelper isSupportCompress:strPath])
            self.type = LIT_ZIP;
        else
            self.type = LIT_UNKNOWN;
        
        self.size = [[attr valueForKey:NSFileSize] longLongValue];
        self.modifyTime = [attr valueForKey:NSFileModificationDate];

        self.lastPos = 0.0f;
        self.playCount = 0;

        if ( self.type == LIT_MIDEA ) {
            FFPlayHistoryManager * history = [FFPlayHistoryManager default];
            int n = 0;
            self.lastPos = [history getLastPlayInfo:self.fullPath playCount:&n];
            self.playCount = n;
        }
        self.random = (arc4random() % 0x1000000) + ((self.playCount < 0xff ? self.playCount : 0xff ) * 0x1000000);
    }
    return self;
}

-(BOOL) isDir{
    return self.type < LIT_FOLDER_DEF_END;
}

-(int) sortNameHelper {
    if ( self.type > LIT_FOLDER_DEF_END )
        return LIT_FOLDER_DEF_END;
    return self.type;
}

-(BOOL) editable {
    return self.type != LIT_PARENT
    && self.type != LIT_SECRETE
    && self.fullPath != nil;
}

@end

///////////////////////////////////////////

@implementation FFLocalFileManager

+(NSString *) getRootFullPath
{
    NSString * root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                           NSUserDomainMask,
                                                           YES) lastObject];
    return root;
}

+(NSString *) getSecretRootPath
{
    NSString * root = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                           NSUserDomainMask,
                                                           YES) lastObject];
    return [root stringByAppendingPathComponent:@"private"];
}

+(NSString *) getPlayHistoryPath
{
    NSString * root = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                           NSUserDomainMask,
                                                           YES) lastObject];
    
    return [root stringByAppendingPathComponent:@"playhistory.data"];
}

+(NSString *) getURLHistoryPath
{
    NSString * root = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                           NSUserDomainMask,
                                                           YES) lastObject];
    
    return [root stringByAppendingPathComponent:@"urlhistory.data"];
}

+(NSString *) getSparkSvrListPath
{
    NSString * root = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                           NSUserDomainMask,
                                                           YES) lastObject];
    
    return [root stringByAppendingPathComponent:@"sparksvr.data"];
}

+(NSString *) getCurrentFolder:(NSString *) strSubPath inSecret:(BOOL) inSecret
{
    NSString * root = (inSecret) ? [FFLocalFileManager getSecretRootPath] : [FFLocalFileManager getRootFullPath];
    if ( strSubPath != nil && strSubPath.length > 0 ) {
        root = [root stringByAppendingPathComponent:strSubPath];
    }
    return root;
}

+(NSArray *) listFolder:(NSString *)root  subPath:(NSString *)strSubPath inSecret:(BOOL) inSecret
{
    NSMutableArray *ma = [NSMutableArray array];
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    if ( strSubPath != nil && strSubPath.length > 0 ) {
        [ma addObject:[[FFLocalItem alloc] initWithPath:nil type:LIT_PARENT]];
    } else if ( !inSecret && [[FFSetting default] unlock] ) {
        [ma addObject:[[FFLocalItem alloc] initWithPath:nil type:LIT_SECRETE]];
    } else if ( inSecret )
        [ma addObject:[[FFLocalItem alloc] initWithPath:nil type:LIT_PARENT]];
    
    if ( strSubPath != nil && strSubPath.length > 0 ) {
        root = [root stringByAppendingPathComponent:strSubPath];
    }
   
    NSArray *contents = [fm contentsOfDirectoryAtPath:root error:nil];
    return [FFLocalFileManager folderContent:contents folder:root tempResult:ma];
}

+(NSArray *) folderContent:(NSArray *) contents folder:(NSString *)folder tempResult:(NSMutableArray *)ma
{
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    for (NSString *filename in contents) {
        
        if (filename.length > 0 &&
            [filename characterAtIndex:0] != '.') {
            
            NSString *path = [folder stringByAppendingPathComponent:filename];
            NSDictionary *attr = [fm attributesOfItemAtPath:path error:nil];
            if (attr) {
                id fileType = [attr valueForKey:NSFileType];
                if ([fileType isEqual: NSFileTypeRegular] ||
                    [fileType isEqual: NSFileTypeSymbolicLink]) {
                    
                    [ma addObject:[[FFLocalItem alloc] initWithAttributes:attr path:path]];
                } else if ( [fileType isEqual:NSFileTypeDirectory] ) {
                    [ma addObject:[[FFLocalItem alloc] initWithAttributes:attr path:path]];
                }
            }
        }
    }
    
    NSMutableArray * arySort = [[NSMutableArray alloc] init];
    [arySort addObject:[NSSortDescriptor sortDescriptorWithKey:@"sortNameHelper" ascending:YES]];
    int nSort = [[FFSetting default] sortType];
    if ( nSort == SORT_BY_DATE || nSort == SORT_BY_DATE_DESC )
        [arySort addObject:[NSSortDescriptor sortDescriptorWithKey:@"modifyTime" ascending:(nSort == SORT_BY_DATE)]];
    else if ( nSort == SORT_BY_NAME || nSort == SORT_BY_NAME_DESC )
        [arySort addObject:[NSSortDescriptor sortDescriptorWithKey:@"fullPath" ascending:(nSort == SORT_BY_NAME)]];
    else
        [arySort addObject:[NSSortDescriptor sortDescriptorWithKey:@"random" ascending:YES]];
    
    return [[ma sortedArrayUsingDescriptors:arySort] copy];
}

+(NSString *) uncompress:(NSString *)fullPath
{
    NSString *ext = fullPath.pathExtension.lowercaseString;
    NSString * strTemp = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
    NSFileManager *fm = [[NSFileManager alloc] init];
    [fm removeItemAtPath:strTemp error:nil];
    if ( ![fm createDirectoryAtPath:strTemp withIntermediateDirectories:NO attributes:nil error:nil] )
        return nil;
    BOOL isOK = FALSE;
    if ( [ext isEqualToString:@"zip"]) {
        isOK = [MiniZip extractZipArchiveAtPath:fullPath toPath:strTemp];
    } else if ( [ext isEqualToString:@"rar"] ) {
        isOK = [UnRAR extractRARArchiveAtPath:fullPath toPath:strTemp];
    } else if ( [ext isEqualToString:@"7z"]) {
        isOK = ([LZMAExtractor extract7zArchive:fullPath dirName:strTemp preserveDir:YES] != nil);
    }
    if ( !isOK )
        return nil;
    return strTemp;
}

@end
