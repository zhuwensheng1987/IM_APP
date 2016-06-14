//
//  FFWebServer.m
//  FFPlayer
//
//  Created by cyt on 14-1-16.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import "FFWebServer.h"
#import "AppDelegate.h"
#import "FFHelper.h"
#import "FFSetting.h"
#import "FFLocalFileManager.h"
#import "XMLDictionary.h"

static NSString* _serverName = nil;
static dispatch_queue_t _connectionQueue = NULL;

@interface FFURLPath : NSObject
@property (atomic)  NSString *  path;
@property (assign)  BOOL        inSecret;
@end

@implementation FFURLPath
@end

////////////////////////////////////////////

@interface GCDWebServerDataResponse (XMLExtensions)
+ (GCDWebServerDataResponse*)responseWithXML:(NSDictionary*)text withStatusCode:(NSInteger)statusCode;
- (id)initWithXML:(NSDictionary*)text withStatusCode:(NSInteger)statusCode;
@end

@implementation GCDWebServerDataResponse (XMLExtensions)

+ (GCDWebServerDataResponse*)responseWithXML:(NSDictionary*)text withStatusCode:(NSInteger)statusCode
{
    return [[self alloc] initWithXML:text withStatusCode:statusCode];
}

- (id)initWithXML:(NSDictionary*)text withStatusCode:(NSInteger)statusCode
{
    NSData* data = [[text XMLString] dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) {
        return nil;
    }
    self = [self initWithData:data contentType:@"text/xml; charset=utf-8"];
    self.statusCode = statusCode;
    return self;
}

@end

////////////////////////////////////////////

@implementation FFWebServer

@synthesize delegate=_delegate;

+ (void) initialize {
    if (_serverName == nil) {
        _serverName = [[NSString alloc] initWithFormat:NSLocalizedString(@"SERVER_NAME_FORMAT", nil),
                       [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                       [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
    }
    if (_connectionQueue == NULL) {
        _connectionQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    }
}

+ (NSString*) serverName {
    return _serverName;
}

-(id)init
{
    self = [super init];
    if ( self != nil )
        [self initHandle];
    return self;
}

-(void) getFolderContent:(NSString *)subPath content:(NSMutableString *)content inSecret:(BOOL)inSecret
{
    NSByteCountFormatter *byteCountFormatter = [[NSByteCountFormatter alloc] init];
    [byteCountFormatter setAllowedUnits:NSByteCountFormatterUseMB];
    NSString * strRoot = inSecret ? [FFLocalFileManager getSecretRootPath] : [FFLocalFileManager getRootFullPath];
    
    NSArray * ary = [FFLocalFileManager listFolder:strRoot subPath:subPath inSecret:inSecret];
    for ( FFLocalItem * item in ary ) {
        NSString * strSubItem = [item.fullPath substringFromIndex:(strRoot.length + 1)];
        NSString * strDisplay = [item.fileName gtm_stringByEscapingForHTML];
        if ( item.type == LIT_PARENT ) {
            strDisplay = @"Parent";
            if ( subPath == nil ) {
                [content appendFormat:@"<tr><td><a href=\"download.html\">[%@]</a></td><td></td></tr>", strDisplay];
            } else {
                [content appendFormat:@"<tr><td><a href=\"download.html?%@\">[%@]</a></td><td></td></tr>", [self convertPathToURL:[subPath stringByDeletingLastPathComponent] inSecret:inSecret], strDisplay];
            }
        } else if ( item.type == LIT_SECRETE ) {
            strDisplay = @"Secret";
            [content appendFormat:@"<tr><td><a href=\"download.html?%@\">[%@]</a></td><td></td></tr>", [self convertPathToURL:nil inSecret:YES], strDisplay];
        } else if ( item.isDir) {
            [content appendFormat:@"<tr><td><a href=\"download.html?%@\">[%@]</a></td><td></td></tr>", [self convertPathToURL:strSubItem inSecret:inSecret], strDisplay];
        } else {
            [content appendFormat:@"<tr><td><a href=\"download?%@\">%@</a></td><td>%@</td></tr>", [self convertPathToURL:strSubItem inSecret:inSecret], strDisplay, [byteCountFormatter stringFromByteCount:item.size]];
        }
    }
}

-(void) getFileContentInXML:(NSString *)fullPath data:(NSMutableDictionary *)data inSecret:(BOOL)inSecret parentURL:(NSString *)parentURL
{
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    formatter.dateFormat = @"EEE', 'd' 'MMM' 'yyyy' 'HH:mm:ss' GMT'";
    
//    NSMutableDictionary * root = [[NSMutableDictionary alloc] init];
    NSMutableDictionary * response = [[NSMutableDictionary alloc] init];
    NSMutableDictionary * propstat = [[NSMutableDictionary alloc] init];
    NSMutableDictionary * prop = [[NSMutableDictionary alloc] init];
    
//    [data setObject:root forKey:@"d:multistatus"];
    [data setObject:@"d:multistatus" forKey:XMLDictionaryNodeNameKey];
    [data setObject:@{ @"xmlns:d" : @"DAV:" } forKey:XMLDictionaryAttributesKey];
    [data setObject:response forKey:@"d:response"];
    
        [response setObject:[self urlEncode:parentURL] forKey:@"d:href"];
        [response setObject:propstat forKey:@"d:propstat"];
        [propstat setObject:@"HTTP/1.1 200 OK" forKey:@"d:status"];
        [propstat setObject:prop forKey:@"d:prop"];
        [prop setObject:[parentURL lastPathComponent] forKey:@"d:displayname"];
        [prop setObject:[parentURL lastPathComponent] forKey:@"d:name"];
    
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:nil];
        id fileType = [attr valueForKey:NSFileType];
        if ( [fileType isEqual:NSFileTypeDirectory] )
            [prop setObject:@{ @"d:collection" : @{} } forKey:@"d:resourcetype"];
        else
            [prop setObject:@{} forKey:@"d:resourcetype"];
    
        [prop setObject:[NSString stringWithFormat:@"%qu", [[attr valueForKey:NSFileSize] longLongValue]] forKey:@"d:getcontentlength"];
        [prop setObject:[formatter stringFromDate:[attr valueForKey:NSFileModificationDate]] forKey:@"d:getlastmodified"];
        [prop setObject:[formatter stringFromDate:[attr valueForKey:NSFileCreationDate]] forKey:@"d:creationdate"];
}

-(void) getFolderContentInXML:(NSString *)subPath data:(NSMutableDictionary *)data inSecret:(BOOL)inSecret parentURL:(NSString *)parentURL
{
    NSString * strRoot = inSecret ? [FFLocalFileManager getSecretRootPath] : [FFLocalFileManager getRootFullPath];
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    formatter.dateFormat = @"EEE', 'd' 'MMM' 'yyyy' 'HH:mm:ss' GMT'";
    
    NSMutableDictionary * root = [[NSMutableDictionary alloc] init];
    NSMutableArray * aryResponse = [[NSMutableArray alloc] init];
    [data setObject:root forKey:@"d:multistatus"];
        [root setObject:@{ @"xmlns:d" : @"DAV:" } forKey:XMLDictionaryAttributesKey];
        [root setObject:aryResponse forKey:@"d:response"];
    
    NSArray * ary = [FFLocalFileManager listFolder:strRoot subPath:subPath inSecret:inSecret];
    for ( FFLocalItem * item in ary ) {
        if ( item.type == LIT_PARENT )
            continue;
        else {
            NSString * subName = (item.type == LIT_SECRETE) ? @"Secret" : item.fileName;
            NSString * displayName = (item.type == LIT_SECRETE) ? NSLocalizedString(@"Secret", nil) : item.fileName;
            NSMutableDictionary * response = [[NSMutableDictionary alloc] init];
            NSMutableDictionary * propstat = [[NSMutableDictionary alloc] init];
            NSMutableDictionary * prop = [[NSMutableDictionary alloc] init];

            [aryResponse addObject:response];
            [response setObject:[self urlEncode:[parentURL stringByAppendingPathComponent:subName]] forKey:@"d:href"];
                [response setObject:propstat forKey:@"d:propstat"];
                    [propstat setObject:@"HTTP/1.1 200 OK" forKey:@"d:status"];
                    [propstat setObject:prop forKey:@"d:prop"];
                        [prop setObject:displayName forKey:@"d:displayname"];
                        [prop setObject:displayName forKey:@"d:name"];
                        if ( item.type == LIT_DIR || item.type == LIT_SECRETE )
                            [prop setObject:@{ @"d:collection" : @{} } forKey:@"d:resourcetype"];
                        else {
                            [prop setObject:@{} forKey:@"d:resourcetype"];
                            [prop setObject:[NSString stringWithFormat:@"%qu", item.size] forKey:@"d:getcontentlength"];
                            [prop setObject:[formatter stringFromDate:item.modifyTime] forKey:@"d:getlastmodified"];
                        }
        }
    }
}

-(NSString *)normalizedPath:(NSString *)subPath
{
    if ( subPath != nil ) {
        NSRange r;
        while ( (r=[subPath rangeOfString:@"../"]).location == 0 )
            subPath = [subPath substringFromIndex:3];
        subPath = [subPath stringByReplacingOccurrencesOfString:@"/../" withString:@"/"];
    }
    return subPath;
}

-(FFURLPath *) getInputPath:(NSDictionary *)dic
{
    FFURLPath * url = [[FFURLPath alloc] init];
    url.inSecret = NO;
    url.path = nil;
    if ( dic != nil ) {
        NSString * subPath = [[dic objectForKey:@"id"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        subPath = [self normalizedPath:subPath];
        if ( subPath != nil && subPath.length == 0 )
            subPath = nil;
        
        url.path = subPath;
        url.inSecret = ([[dic objectForKey:@"sec"] intValue] != 0) && [[FFSetting default] unlock];
    }
    return url;
}

-(FFURLPath *) getInputPathByURLPath:(NSString *)urlInput
{
    FFURLPath * url = [[FFURLPath alloc] init];
    url.inSecret = NO;
    url.path = nil;
    if ( urlInput != nil ) {
        NSMutableArray * aryPath = [[urlInput pathComponents] mutableCopy];
        if ( aryPath.count > 0 ) {
            if ( [aryPath[0] isEqualToString:@"/"] )
                [aryPath removeObjectAtIndex:0];
            if ( aryPath.count > 0 && [aryPath[0] isEqualToString:@"webdav"] ) {
                [aryPath removeObjectAtIndex:0];
            }
            if ( aryPath.count > 0 ) {
                if ( [aryPath[0] isEqualToString:@"Secret"] && [[FFSetting default] unlock] ) {
                    url.inSecret = YES;
                    [aryPath removeObjectAtIndex:0];
                }
            }
            NSString * subPath = [NSString pathWithComponents:aryPath];
            subPath = [self normalizedPath:subPath];
            if ( subPath != nil && subPath.length == 0 )
                subPath = nil;
            url.path = subPath;
        }
    }
    return url;
}

-(NSString *)urlEncode:(NSString *) str
{
    return [[str stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
            stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
}

-(NSString *) convertPathToURL:(NSString *)path inSecret:(BOOL)inSecret
{
    NSMutableString * str = [[NSMutableString alloc] init];
    if ( path != nil && path.length > 0 )
        [str appendFormat:@"id=%@", [self urlEncode:path]];
    if ( inSecret ) {
        if ( str.length > 0 )
            [str appendString:@"&"];
        [str appendString:@"sec=1"];
    }
    return str;
}

- (NSString *)DAVClass
{
    return(@"1,2");
}

- (NSArray *)allowedMethods
{
    return([NSArray arrayWithObjects:@"OPTIONS", @"GET", @"HEAD", @"PUT", @"POST", @"COPY", @"PROPFIND", @"DELETE", @"MKCOL", @"MOVE", @"LOCK", @"UNLOCK", NULL]);  //, @"PROPPATCH"
}

-(NSString *) firstElementKey:(NSDictionary *)xml
{
    for ( NSString * key in xml ) {
        if ([key hasPrefix:XMLDictionaryAttributePrefix])
            continue;
        NSString * lowerKey = [key lowercaseString];
        NSRange range = [lowerKey rangeOfString:@":"];
        if ( range.location != NSNotFound )
            return [lowerKey substringFromIndex:range.location + 1];
        else
            return  lowerKey;
    }
    return  nil;
}

-(NSInteger) getWebDAVDepth:(NSDictionary *)headers
{
    NSInteger theDepth = -1;
    NSString *theDepthString = [headers objectForKey:@"Depth"];
    if (theDepthString != NULL)
    {
        if ([theDepthString isEqualToString:@"0"])
            theDepth = 0;
        else if ([theDepthString isEqualToString:@"1"])
            theDepth = 1;
        else if ([theDepthString isEqualToString:@"infinity"])
            theDepth = -1;
        else
            theDepth = -2;
    }
    return theDepth;
}

-(NSString *) webDavURLToLocalURL:(NSString*) inputPath
{
    NSString *theRootPath = [inputPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    FFURLPath * path = [self getInputPathByURLPath:theRootPath];
    return [FFLocalFileManager getCurrentFolder:path.path inSecret:path.inSecret];
}

-(void) initHandle {
    
    NSString* websitePath = [[NSBundle mainBundle] pathForResource:@"Website" ofType:nil];
    NSString* footer = [NSString stringWithFormat:@"%@ - %@",
                        [[UIDevice currentDevice] name],
                        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    NSDictionary* baseVariables = [NSDictionary dictionaryWithObjectsAndKeys:footer, @"footer", nil];
    __weak FFWebServer * weakSelf = self;
    
    [self addHandlerForBasePath:@"/" localPath:websitePath indexFilename:nil cacheAge:3600];
    
    [self addHandlerForMethod:@"PROPFIND" pathRegex:@"/webdav/.*" requestClass:[GCDWebServerDataRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        GCDWebServerDataRequest * requestData = (GCDWebServerDataRequest *)request;
        
        NSInteger theDepth = [weakSelf getWebDAVDepth:requestData.headers];
        if ( theDepth < -1)
                return [GCDWebServerDataResponse responseWithXML:@{} withStatusCode:400];
        
        NSString *theRootPath = [request.URL.path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        FFURLPath * path = [weakSelf getInputPathByURLPath:theRootPath];
        NSString * pathToCheck = [FFLocalFileManager getCurrentFolder:path.path inSecret:path.inSecret];
        BOOL boIsDir = FALSE;
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:pathToCheck isDirectory:&boIsDir] )
            return [GCDWebServerResponse responseWithStatusCode:404];
        
        NSMutableDictionary * dicData = [[NSMutableDictionary alloc] init];
        if ( boIsDir && theDepth != 0 )
            [weakSelf getFolderContentInXML:path.path data:dicData inSecret:path.inSecret parentURL:theRootPath];
        else
            [weakSelf getFileContentInXML:pathToCheck data:dicData inSecret:path.inSecret parentURL:theRootPath];
        
        return [GCDWebServerDataResponse responseWithXML:dicData withStatusCode:200];
    }];
    [self addHandlerForMethod:@"OPTIONS" pathRegex:@"/webdav/.*" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        
        GCDWebServerResponse * response = [GCDWebServerResponse responseWithStatusCode:200];
        [response setValue:[weakSelf DAVClass] forAdditionalHeader:@"DAV"];
        [response setValue:[[weakSelf allowedMethods] componentsJoinedByString:@","] forAdditionalHeader:@"Allow"];
        return response;
        
    }];
    [self addHandlerForMethod:@"GET" pathRegex:@"/webdav/.*" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        
        GCDWebServerResponse* response = nil;
        NSString * pathToCheck = [weakSelf webDavURLToLocalURL:request.URL.path];
        if ( [[NSFileManager defaultManager]  fileExistsAtPath:pathToCheck] ) {
            response = [GCDWebServerFileResponse responseWithFile:pathToCheck isAttachment:YES];
        } else {
            response = [GCDWebServerResponse responseWithStatusCode:404];
        }
        return response;
    }];
    [self addHandlerForMethod:@"MKCOL" pathRegex:@"/webdav/.*" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        
        NSString * pathToCheck = [weakSelf webDavURLToLocalURL:request.URL.path];
        NSFileManager * mgr = [NSFileManager defaultManager];
        
        if ( [mgr fileExistsAtPath:pathToCheck isDirectory:nil] )
            return [GCDWebServerResponse responseWithStatusCode:405];//Not allow
        else if ( [request.headers objectForKey:@"Content-Type"] )
            return [GCDWebServerResponse responseWithStatusCode:415];        /* Unsupported Media Type */        \
        else if ( ![mgr createDirectoryAtPath:pathToCheck withIntermediateDirectories:NO attributes:nil error:nil])
            return [GCDWebServerResponse responseWithStatusCode:403];        /* Forbidden */
        return [GCDWebServerResponse responseWithStatusCode:201];
    }];
    [self addHandlerForMethod:@"DELETE" pathRegex:@"/webdav/.*" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        
        NSString * pathToCheck = [weakSelf webDavURLToLocalURL:request.URL.path];
        NSFileManager * mgr = [NSFileManager defaultManager];
        
        if ( [weakSelf getWebDAVDepth:request.headers] != -1)
            return [GCDWebServerDataResponse responseWithStatusCode:400];
        else if ( ![mgr fileExistsAtPath:pathToCheck isDirectory:nil] )
            return [GCDWebServerResponse responseWithStatusCode:404];//Not found
        else if ( ![mgr removeItemAtPath:pathToCheck error:nil] )
            return [GCDWebServerResponse responseWithStatusCode:403];        /* Forbidden */
        return [GCDWebServerResponse responseWithStatusCode:201];
    }];
    [self addHandlerForMethod:@"MOVE" pathRegex:@"/webdav/.*" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        
        NSInteger theDepth = [weakSelf getWebDAVDepth:request.headers];
        if ( theDepth != -1)
            return [GCDWebServerDataResponse responseWithXML:@{} withStatusCode:400];
        BOOL boOverWrite = [[request.headers objectForKey:@"Overwrite"] isEqualToString:@"T"];
        NSFileManager * mgr = [NSFileManager defaultManager];

        NSString *theSourcePath = [weakSelf webDavURLToLocalURL:request.URL.path];
        NSString *theDestinationStringURL = [request.headers objectForKey:@"Destination"];

        if ( theDestinationStringURL == nil )
            return [GCDWebServerResponse responseWithStatusCode:400];
        NSURL *theDestination = [NSURL URLWithString:theDestinationStringURL];
        NSString *theDestinationPath = [weakSelf webDavURLToLocalURL:[theDestination path]];
        
        if ( ![mgr fileExistsAtPath:theSourcePath isDirectory:nil] )
            return [GCDWebServerResponse responseWithStatusCode:404];//Not found
        else if ( [mgr fileExistsAtPath:theDestinationPath] ) {
            if ( !boOverWrite )
                return [GCDWebServerResponse responseWithStatusCode:400];
            else if (![mgr removeItemAtPath:theDestinationPath error:nil])
                return [GCDWebServerResponse responseWithStatusCode:500];
        }
        
        if ( ![mgr moveItemAtPath:theSourcePath toPath:theDestinationPath error:nil] )
            return [GCDWebServerResponse responseWithStatusCode:403];        /* Forbidden */
        return [GCDWebServerResponse responseWithStatusCode:200];
    }];
    [self addHandlerForMethod:@"COPY" pathRegex:@"/webdav/.*" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        
        NSInteger theDepth = [weakSelf getWebDAVDepth:request.headers];
        if ( theDepth != -1)
            return [GCDWebServerDataResponse responseWithXML:@{} withStatusCode:400];
        BOOL boOverWrite = [[request.headers objectForKey:@"Overwrite"] isEqualToString:@"T"];
        NSFileManager * mgr = [NSFileManager defaultManager];
        
        NSString *theSourcePath = [weakSelf webDavURLToLocalURL:request.URL.path];
        NSString *theDestinationStringURL = [request.headers objectForKey:@"Destination"];
        
        if ( theDestinationStringURL == nil )
            return [GCDWebServerResponse responseWithStatusCode:400];
        NSURL *theDestination = [NSURL URLWithString:theDestinationStringURL];
        NSString *theDestinationPath = [weakSelf webDavURLToLocalURL:[theDestination path]];
        
        if ( ![mgr fileExistsAtPath:theSourcePath isDirectory:nil] )
            return [GCDWebServerResponse responseWithStatusCode:404];//Not found
        else if ( [mgr fileExistsAtPath:theDestinationPath] ) {
            if ( !boOverWrite )
                return [GCDWebServerResponse responseWithStatusCode:400];
            else if (![mgr removeItemAtPath:theDestinationPath error:nil])
                return [GCDWebServerResponse responseWithStatusCode:500];
        }
        
        if ( ![mgr copyItemAtPath:theSourcePath toPath:theDestinationPath error:nil] )
            return [GCDWebServerResponse responseWithStatusCode:403];        /* Forbidden */
        return [GCDWebServerResponse responseWithStatusCode:200];
    }];
    [self addHandlerForMethod:@"PUT" pathRegex:@"/webdav/.*" requestClass:[GCDWebServerFileRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        GCDWebServerFileRequest * requestData = (GCDWebServerFileRequest *)request;
        
        NSFileManager * mgr = [NSFileManager defaultManager];
        
        NSString *thePath = [weakSelf webDavURLToLocalURL:request.URL.path];
        BOOL isDir = FALSE, isSrcExist = FALSE;
        if ( thePath == nil )
            return [GCDWebServerResponse responseWithStatusCode:400];
        else if ( ![mgr fileExistsAtPath:[ thePath stringByDeletingLastPathComponent]] )
            return [GCDWebServerResponse responseWithStatusCode:403];
        else if ( (isSrcExist = [mgr fileExistsAtPath:thePath isDirectory:&isDir]) && isDir )
            return [GCDWebServerResponse responseWithStatusCode:403];
        else if ( isSrcExist && ![mgr removeItemAtPath:thePath error:nil] )
            return [GCDWebServerResponse responseWithStatusCode:403];
        else if ( requestData.contentLength ==  0) {
            [requestData open];
            [requestData close];
        }
        if ( ![mgr moveItemAtPath:requestData.filePath toPath:thePath error:nil] )
            return [GCDWebServerResponse responseWithStatusCode:403];
        return [GCDWebServerResponse responseWithStatusCode:200];
    }];
    [self addHandlerForMethod:@"LOCK" pathRegex:@"/webdav/.*" requestClass:[GCDWebServerDataRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest * request){
        GCDWebServerDataRequest * requestData = (GCDWebServerDataRequest *)request;
        
        NSInteger theDepth = [weakSelf getWebDAVDepth:requestData.headers];
        if ( theDepth < -1)
            return [GCDWebServerDataResponse responseWithXML:@{} withStatusCode:400];
        NSFileManager * mgr = [NSFileManager defaultManager];
        NSString *thePath = [weakSelf webDavURLToLocalURL:request.URL.path];
        if ( ![mgr fileExistsAtPath:thePath] )
            return [GCDWebServerResponse responseWithStatusCode:404];

        NSString* scope = nil;
        NSString* type = nil;
        NSString* owner = nil;
        NSString* token = nil;
        NSString * lockToken = nil;
        
        XMLDictionaryParser * parser = [XMLDictionaryParser sharedInstance];
        parser.stripEmptyNodes = FALSE;
        parser.attributesMode = XMLDictionaryAttributesModeDiscard;
        NSDictionary * xml = [parser dictionaryWithData:requestData.data];
        if ( xml == nil ) {
            if ((lockToken = [request.headers objectForKey:@"If"]) != nil) {
                scope = @"exclusive";
                type = @"write";
                theDepth = 0;
                token = [lockToken stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"(<>)"]];
            }
        } else {
            for ( NSString * key in xml ) {
                NSString * strLowKey = [key lowercaseString];
                if ( [strLowKey hasSuffix:@"lockscope"] ) {
                    scope = [weakSelf firstElementKey:[xml objectForKey:key]];
                } else if ( [strLowKey hasSuffix:@"locktype"] ) {
                    type = [weakSelf firstElementKey:[xml objectForKey:key]];
                } else if ( [strLowKey hasSuffix:@"owner"] ) {
                    owner = [[xml objectForKey:key] objectForKey:@"href"];
                }
            }
        }
        
        if ([scope isEqualToString:@"exclusive"] && [type isEqualToString:@"write"] && theDepth == 0 &&
            ([[NSFileManager defaultManager] fileExistsAtPath:thePath] || [[NSData data] writeToFile:thePath atomically:YES])) {
            NSString* timeout = [request.headers objectForKey:@"Timeout"];
            if (!token) {
                CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
                NSString *uuidStr = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
                token = [NSString stringWithFormat:@"urn:uuid:%@", uuidStr];
                CFRelease(uuid);
            }
            NSString* lockroot = [@"http://" stringByAppendingString:[[request.headers objectForKey:@"Host"] stringByAppendingString:[@"/" stringByAppendingString:request.path]]];
            
            NSMutableDictionary * xmlResult = [NSMutableDictionary dictionary];
            NSMutableDictionary * xmlDiscovery = [NSMutableDictionary dictionary];
            NSMutableDictionary * xmlActivelock = [NSMutableDictionary dictionary];
            
            [xmlResult setObject:@"d:prop" forKey:XMLDictionaryNodeNameKey];
                [xmlResult setObject:@{ @"xmlns:d" : @"DAV:" } forKey:XMLDictionaryAttributesKey];
                [xmlResult setObject:xmlDiscovery forKey:@"d:lockdiscovery"];
                [xmlDiscovery setObject:xmlActivelock forKey:@"d:activelock"];
            
                [xmlActivelock setObject:@{ [NSString stringWithFormat:@"d:%@",type] : @{} } forKey:@"d:locktype"];
                [xmlActivelock setObject:@{ [NSString stringWithFormat:@"d:%@",scope] : @{} } forKey:@"d:lockscope"];
                [xmlActivelock setObject:[NSString stringWithFormat:@"%d", theDepth] forKey:@"d:depth"];
                if (owner)
                    [xmlActivelock setObject:@{ @"d:href" : owner } forKey:@"d:owner"];
                if (timeout)
                    [xmlActivelock setObject:timeout forKey:@"d:timeout"];
            [xmlActivelock setObject:@{ @"d:href" : token } forKey:@"d:locktoken"];
            [xmlActivelock setObject:@{ @"d:href" : lockroot } forKey:@"d:lockroot"];
            
            return [GCDWebServerDataResponse responseWithXML:xmlResult withStatusCode:200];
        } else {
            NSLog(@"Locking request \"%@/%@/%d\" for \"%@\" is not allowed", scope, type, theDepth, request.path);
            return [GCDWebServerResponse responseWithStatusCode:403];
        }
        return [GCDWebServerResponse responseWithStatusCode:200];
    }];
    [self addHandlerForMethod:@"UNLOCK" pathRegex:@"/webdav/.*" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        
        return [GCDWebServerResponse responseWithStatusCode:200];
    }];

    
    [self addHandlerForMethod:@"GET" path:@"/" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        return [GCDWebServerResponse responseWithRedirect:[NSURL URLWithString:@"index.html" relativeToURL:request.URL] permanent:NO];
        
    }];
    [self addHandlerForMethod:@"GET" path:@"/index.html" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        NSMutableDictionary* variables = [NSMutableDictionary dictionaryWithDictionary:baseVariables];
        return [GCDWebServerDataResponse responseWithHTMLTemplate:[websitePath stringByAppendingPathComponent:request.path] variables:variables];
    }];
    
    [self addHandlerForMethod:@"GET" path:@"/download.html" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        GCDWebServerResponse* response = nil;
        NSMutableDictionary* variables = [NSMutableDictionary dictionaryWithDictionary:baseVariables];
        
        NSMutableString* content = [[NSMutableString alloc] init];
        FFURLPath * path = [weakSelf getInputPath:request.query];
        
        [weakSelf getFolderContent:path.path content:content inSecret:path.inSecret];
        [variables setObject:content forKey:@"content"];
        [variables setObject:[weakSelf convertPathToURL:path.path inSecret:path.inSecret] forKey:@"uploadPath"];
        NSString * strCurrentPath = path.path == nil ? @"/" : path.path;
        if ( path.inSecret )
            strCurrentPath = [NSString stringWithFormat:@"%@ (Secret)", strCurrentPath];
        [variables setObject:strCurrentPath forKey:@"currentPath"];

        response = [GCDWebServerDataResponse responseWithHTMLTemplate:[websitePath stringByAppendingPathComponent:request.path] variables:variables];
        return response;
    }];
    
    [self addHandlerForMethod:@"GET" path:@"/download" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        
        // Called from GCD thread
        GCDWebServerResponse* response = nil;
        FFURLPath * url = [weakSelf getInputPath:request.query];
        NSString * strRoot = url.inSecret ? [FFLocalFileManager getSecretRootPath] : [FFLocalFileManager getRootFullPath];
        NSString * path = [strRoot stringByAppendingPathComponent:url.path];
        if ( [[NSFileManager defaultManager]  fileExistsAtPath:path] ) {
            response = [GCDWebServerFileResponse responseWithFile:path isAttachment:YES];
        } else {
            response = [GCDWebServerResponse responseWithStatusCode:404];
        }
        return response;
    }];
    
    [self addHandlerForMethod:@"GET" path:@"/createFolder" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        GCDWebServerResponse* response = nil;
        FFURLPath * url = [weakSelf getInputPath:request.query];
        
        NSString * strRoot = url.inSecret ? [FFLocalFileManager getSecretRootPath] : [FFLocalFileManager getRootFullPath];
        NSString * path = [strRoot stringByAppendingPathComponent:url.path];
        NSString * newPath = [request.query objectForKey:@"name"];
        if ( [[NSFileManager defaultManager]  fileExistsAtPath:path] && newPath != nil && newPath.length > 0 ) {
            newPath = [weakSelf normalizedPath:newPath];
            
            if ([newPath isEqualToString:@"Secret"] && url.path == nil && !url.inSecret)
                return [GCDWebServerResponse responseWithStatusCode:404];

            path = [path stringByAppendingPathComponent:newPath];
            if ( ![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil] )
                response = [GCDWebServerDataResponse responseWithHTML:NSLocalizedString(@"Create folder error", nil)];
            else
                response = [GCDWebServerResponse responseWithRedirect:[NSURL URLWithString:
                                                                        [NSString stringWithFormat:@"/download.html?%@",[weakSelf convertPathToURL:url.path inSecret:url.inSecret] ]
                                                                       ] permanent:NO];
        } else {
            response = [GCDWebServerResponse responseWithStatusCode:404];
        }
        return response;
    }];
    
    [self addHandlerForMethod:@"POST" path:@"/upload" requestClass:[GCDWebServerMultiPartFormRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        
        // Called from GCD thread
        NSString* html = NSLocalizedString(@"Successfully Uploaded", nil);
        GCDWebServerMultiPartFile* file = [[(GCDWebServerMultiPartFormRequest*)request files] objectForKey:@"file"];
        
        FFURLPath * targetUrl = [weakSelf getInputPath:request.query];
        NSString * strRoot = targetUrl.inSecret ? [FFLocalFileManager getSecretRootPath] : [FFLocalFileManager getRootFullPath];
        NSString * targetPath = [strRoot stringByAppendingPathComponent:targetUrl.path == nil ? @"" : targetUrl.path];

        NSString* fileName = file.fileName;
        NSString* temporaryPath = file.temporaryPath;
        
        if (fileName.length && ![fileName hasPrefix:@"."]) {
            
            NSString* filePath = [targetPath stringByAppendingPathComponent:fileName];
            NSFileManager * mgr = [NSFileManager defaultManager];
            int i = 0;
            while ( [mgr fileExistsAtPath:filePath] ) {
                NSString * strNewName = [NSString stringWithFormat:@"%@(%d).%@", [fileName stringByDeletingPathExtension],i++, [fileName pathExtension]];
                filePath = [targetPath stringByAppendingPathComponent:strNewName];
            }
            
            NSError* error = nil;
            if (![mgr moveItemAtPath:temporaryPath toPath:filePath error:&error]) {
                return [GCDWebServerResponse responseWithStatusCode:402];
                /*
                html = NSLocalizedString(@"SERVER_STATUS_ERROR", nil);
                html = NSLocalizedString(@"SERVER_STATUS_UNSUPPORTED", nil);
                html = NSLocalizedString(@"SERVER_STATUS_INVALID", nil);
                 */
            }
        } else
            return [GCDWebServerResponse responseWithStatusCode:402];
        return [GCDWebServerDataResponse responseWithHTML:html];
    }];
}

@end


/*
 if ([method isEqualToString:@"LOCK"]) {
 NSString* path = [rootPath stringByAppendingPathComponent:resourcePath];
 if (![path hasPrefix:rootPath]) {
 return nil;
 }
 
 NSString* depth = [headers objectForKey:@"Depth"];
 NSString* scope = nil;
 NSString* type = nil;
 NSString* owner = nil;
 NSString* token = nil;
 xmlDocPtr document = xmlReadMemory(body.bytes, (int)body.length, NULL, NULL, kXMLParseOptions);
 if (document) {
    xmlNodePtr node = _XMLChildWithName(document->children, (const xmlChar*)"lockinfo");
    if (node) {
        xmlNodePtr scopeNode = _XMLChildWithName(node->children, (const xmlChar*)"lockscope");
        if (scopeNode && scopeNode->children && scopeNode->children->name) {
            scope = [NSString stringWithUTF8String:(const char*)scopeNode->children->name];
        }
        xmlNodePtr typeNode = _XMLChildWithName(node->children, (const xmlChar*)"locktype");
        if (typeNode && typeNode->children && typeNode->children->name) {
            type = [NSString stringWithUTF8String:(const char*)typeNode->children->name];
        }
        xmlNodePtr ownerNode = _XMLChildWithName(node->children, (const xmlChar*)"owner");
        if (ownerNode) {
            ownerNode = _XMLChildWithName(ownerNode->children, (const xmlChar*)"href");
            if (ownerNode && ownerNode->children && ownerNode->children->content) {
                owner = [NSString stringWithUTF8String:(const char*)ownerNode->children->content];
            }
        }
    } else {
        HTTPLogWarn(@"HTTP Server: Invalid DAV properties\n%@", [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]);
    }
    xmlFreeDoc(document);
 } else {
    // No body, see if they're trying to refresh an existing lock.  If so, then just fake up the scope, type and depth so we fall
    // into the lock create case.
    NSString* lockToken;
    if ((lockToken = [headers objectForKey:@"If"]) != nil) {
        scope = @"exclusive";
        type = @"write";
        depth = @"0";
        token = [lockToken stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"(<>)"]];
    }
 }
 if ([scope isEqualToString:@"exclusive"] && [type isEqualToString:@"write"] && [depth isEqualToString:@"0"] &&
 ([[NSFileManager defaultManager] fileExistsAtPath:path] || [[NSData data] writeToFile:path atomically:YES])) {
 NSString* timeout = [headers objectForKey:@"Timeout"];
 if (!token) {
 CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
 NSString *uuidStr = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
 token = [NSString stringWithFormat:@"urn:uuid:%@", uuidStr];
 CFRelease(uuid);
 }
 
 NSMutableString* xmlString = [NSMutableString stringWithString:@"<?xml version=\"1.0\" encoding=\"utf-8\" ?>"];
 [xmlString appendString:@"<D:prop xmlns:D=\"DAV:\">\n"];
 [xmlString appendString:@"<D:lockdiscovery>\n<D:activelock>\n"];
 [xmlString appendFormat:@"<D:locktype><D:%@/></D:locktype>\n", type];
 [xmlString appendFormat:@"<D:lockscope><D:%@/></D:lockscope>\n", scope];
 [xmlString appendFormat:@"<D:depth>%@</D:depth>\n", depth];
 if (owner) {
 [xmlString appendFormat:@"<D:owner><D:href>%@</D:href></D:owner>\n", owner];
 }
 if (timeout) {
 [xmlString appendFormat:@"<D:timeout>%@</D:timeout>\n", timeout];
 }
 [xmlString appendFormat:@"<D:locktoken><D:href>%@</D:href></D:locktoken>\n", token];
 NSString* lockroot = [@"http://" stringByAppendingString:[[headers objectForKey:@"Host"] stringByAppendingString:[@"/" stringByAppendingString:resourcePath]]];
 [xmlString appendFormat:@"<D:lockroot><D:href>%@</D:href></D:lockroot>\n", lockroot];
 [xmlString appendString:@"</D:activelock>\n</D:lockdiscovery>\n"];
 [xmlString appendString:@"</D:prop>"];
 
 [_headers setObject:@"application/xml; charset=\"utf-8\"" forKey:@"Content-Type"];
 _data = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
 _status = 200;
 HTTPLogVerbose(@"Pretending to lock \"%@\"", resourcePath);
 } else {
 HTTPLogError(@"Locking request \"%@/%@/%@\" for \"%@\" is not allowed", scope, type, depth, resourcePath);
 _status = 403;
 }
 }
 
 // 9.11 UNLOCK Method - TODO: Actually unlock the resource
 if ([method isEqualToString:@"UNLOCK"]) {
 NSString* path = [rootPath stringByAppendingPathComponent:resourcePath];
 if (![path hasPrefix:rootPath] || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
 return nil;
 }
 
 NSString* token = [headers objectForKey:@"Lock-Token"];
 _status = token ? 204 : 400;
 HTTPLogVerbose(@"Pretending to unlock \"%@\"", resourcePath);
}
 
 */
