//
//  FFWebServer.h
//  FFPlayer
//
//  Created by cyt on 14-1-16.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import "GCDWebServer.h"
#import "GCDWebServerConnection.h"

@class FFWebServer;

@protocol FFWebServerDelegate <NSObject>
- (void) webServerDidConnect:(FFWebServer*)server;
- (void) webServerDidUploadComic:(FFWebServer*)server;
- (void) webServerDidDownloadComic:(FFWebServer*)server;
- (void) webServerDidDisconnect:(FFWebServer*)server;
@end

@interface FFWebServer : GCDWebServer
@property (nonatomic, weak) id<FFWebServerDelegate> delegate;

@end
