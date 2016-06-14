//
//  FFHelper.h
//  FFPlayer
//
//  Created by Coremail on 14-1-14.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "GTMDefines.h"
#import "GTMNSString.h"

@interface FFHelper : NSObject

+ (float)iOSVersion;
+(BOOL) isSupportMidea:(NSString *)path;
+(BOOL) isSupportPic:(NSString *)path;
+(BOOL) isSupportCompress:(NSString *)path;

+(BOOL) isInternalPlayerSupport:(NSString *)path;
+ (CGSize)sizeInOrientation:(UIInterfaceOrientation)orientation;
+(BOOL) isIpad;
+ (NSString *)md5HexDigest:(NSString*)input;

+(void) switchToFullScreen:(UIViewController *)vc;

//copy from uidevice-extension
//https://github.com/erica/uidevice-extension
+ (NSString *) hostname;
+ (NSString *) getIPAddressForHost: (NSString *) theHost;
+ (NSString *) localIPAddress;
+ (NSString *) localWiFiIPAddress;
+ (NSArray *) localWiFiIPAddresses;

@end

///////////////////////////////////////////////////
