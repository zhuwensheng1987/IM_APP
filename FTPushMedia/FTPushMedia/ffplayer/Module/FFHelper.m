//
//  FFHelper.m
//  FFPlayer
//
//  Created by Coremail on 14-1-14.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import "FFHelper.h"
#import "FFSetting.h"
#import <CommonCrypto/CommonDigest.h>

#import <arpa/inet.h>
#import <netdb.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <unistd.h>
#import <dlfcn.h>

@implementation FFHelper

+ (float)iOSVersion {
    static float version = 0.f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        version = [[[UIDevice currentDevice] systemVersion] floatValue];
    });
    return version;
}

+ (CGSize)sizeInOrientation:(UIInterfaceOrientation)orientation {
    CGSize size = [UIScreen mainScreen].bounds.size;
    UIApplication *application = [UIApplication sharedApplication];
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        size = CGSizeMake(size.height, size.width);
    }
    if (!application.statusBarHidden && [FFHelper iOSVersion] < 7.0) {
        size.height -= MIN(application.statusBarFrame.size.width, application.statusBarFrame.size.height);
    }
    return size;
}

+(BOOL) isIpad
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

+(void) switchToFullScreen:(UIViewController *)vc
{
    if ([vc respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        // iOS 7
        [vc prefersStatusBarHidden];
        [vc performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
    }
}

+ (NSString *) hostname
{
	char baseHostName[256]; // Thanks, Gunnar Larisch
	int success = gethostname(baseHostName, 255);
	if (success != 0) return nil;
	baseHostName[255] = '\0';
	
#if TARGET_IPHONE_SIMULATOR
 	return [NSString stringWithFormat:@"%s", baseHostName];
#else
	return [NSString stringWithFormat:@"%s.local", baseHostName];
#endif
}

+ (NSString *) getIPAddressForHost: (NSString *) theHost
{
	struct hostent *host = gethostbyname([theHost UTF8String]);
    if (!host) {herror("resolv"); return NULL; }
	struct in_addr **list = (struct in_addr **)host->h_addr_list;
	NSString *addressString = [NSString stringWithCString:inet_ntoa(*list[0]) encoding:NSUTF8StringEncoding];
	return addressString;
}

+ (NSString *) localIPAddress
{
	struct hostent *host = gethostbyname([[self hostname] UTF8String]);
    if (!host) {herror("resolv"); return nil;}
    struct in_addr **list = (struct in_addr **)host->h_addr_list;
	return [NSString stringWithCString:inet_ntoa(*list[0]) encoding:NSUTF8StringEncoding];
}

// Matt Brown's get WiFi IP addy solution
// Author gave permission to use in Cookbook under cookbook license
// http://mattbsoftware.blogspot.com/2009/04/how-to-get-ip-address-of-iphone-os-v221.html
// Updates: changed en0 to en.
// More updates: TBD
+ (NSString *) localWiFiIPAddress
{
	BOOL success;
	struct ifaddrs * addrs;
	const struct ifaddrs * cursor;
	
	success = getifaddrs(&addrs) == 0;
	if (success) {
		cursor = addrs;
		while (cursor != NULL) {
			// the second test keeps from picking up the loopback address
			if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0)
			{
				NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
				if ([name hasPrefix:@"en"])  // Wi-Fi adapter -- was en0
					return [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr)];
			}
			cursor = cursor->ifa_next;
		}
		freeifaddrs(addrs);
	}
	return nil;
}

+ (NSArray *) localWiFiIPAddresses
{
	BOOL success;
	struct ifaddrs * addrs;
	const struct ifaddrs * cursor;
	
	NSMutableArray *array = [NSMutableArray array];
	
	success = getifaddrs(&addrs) == 0;
	if (success) {
		cursor = addrs;
		while (cursor != NULL) {
			// the second test keeps from picking up the loopback address
			if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0)
			{
				NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
				if ([name hasPrefix:@"en"])
					[array addObject:[NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr)]];
			}
			cursor = cursor->ifa_next;
		}
		freeifaddrs(addrs);
	}
	
	if (array.count) return array;
	
	return nil;
}

+(BOOL) isSupportMidea:(NSString *)path
{
    NSString *ext = path.pathExtension.lowercaseString;
    
    if ([ext isEqualToString:@"mp3"] ||
        [ext isEqualToString:@"caff"]||
        [ext isEqualToString:@"aiff"]||
        [ext isEqualToString:@"ogg"] ||
        [ext isEqualToString:@"wma"] ||
        [ext isEqualToString:@"m4a"] ||
        [ext isEqualToString:@"mpv"] ||
        [ext isEqualToString:@"m4v"] ||
        [ext isEqualToString:@"wmv"] ||
        [ext isEqualToString:@"3gp"] ||
        [ext isEqualToString:@"mp4"] ||
        [ext isEqualToString:@"mov"] ||
        [ext isEqualToString:@"avi"] ||
        [ext isEqualToString:@"mkv"] ||
        [ext isEqualToString:@"mpeg"]||
        [ext isEqualToString:@"mpg"] ||
        [ext isEqualToString:@"flv"] ||
        [ext isEqualToString:@"vob"])
        return YES;
    
    return NO;
}

+(BOOL) isSupportPic:(NSString *)path
{
    NSString *ext = path.pathExtension.lowercaseString;
    
    if ([ext isEqualToString:@"jpg"] ||
        [ext isEqualToString:@"jpeg"]||
        [ext isEqualToString:@"bmp"]||
        [ext isEqualToString:@"gif"] ||
        [ext isEqualToString:@"pic"] ||
        [ext isEqualToString:@"png"] ||
        [ext isEqualToString:@"tiff"] ||
        [ext isEqualToString:@"icn"] ||
        [ext isEqualToString:@"icon"]
        )
        return YES;
    
    return NO;
}

+(BOOL) isSupportCompress:(NSString *)path
{
    NSString *ext = path.pathExtension.lowercaseString;
    
    if ([ext isEqualToString:@"zip"] ||
        [ext isEqualToString:@"rar"]||
        [ext isEqualToString:@"7z"]
        )
        return YES;
    
    return NO;
}

+(BOOL) isInternalPlayerSupport:(NSString *)path
{
    /*
     This class plays any movie or audio file supported in iOS. This includes both streamed content and fixed-length files. For movie files, this typically means files with the extensions .mov, .mp4, .mpv, and .3gp and using one of the following compression standards:
     
     H.264 Baseline Profile Level 3.0 video, up to 640 x 480 at 30 fps. (The Baseline profile does not support B frames.)
     MPEG-4 Part 2 video (Simple Profile)
     If you use this class to play audio files, it displays a white screen with a QuickTime logo while the audio plays. For audio files, this class supports AAC-LC audio at up to 48 kHz, and MP3 (MPEG-1 Audio Layer 3) up to 48 kHz, stereo audio.
     */

    NSString *ext = path.pathExtension.lowercaseString;
    
    if (![[FFSetting default] enableInternalPlayer])
        return NO;
    else if ([ext isEqualToString:@"mp3"] ||
        [ext isEqualToString:@"mp4"] ||
        [ext isEqualToString:@"mov"] ||
        [ext isEqualToString:@"mpv"] ||
        [ext isEqualToString:@"3gp"])
        return YES;
    
    return NO;
}

+ (NSString *)md5HexDigest:(NSString*)input
{
    const char* str = [input UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, strlen(str), result);
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];//
    
    for(int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x",result[i]];
    }
    return ret;
}

@end

//////////////////////////////////////////////////////
