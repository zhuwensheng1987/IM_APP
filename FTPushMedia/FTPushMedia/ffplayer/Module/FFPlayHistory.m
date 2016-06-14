//
//  FFPlayHistory.m
//  FFPlayer
//
//  Created by cyt on 14-1-26.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import "FFPlayHistory.h"

@implementation FFPlayHistory

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.url forKey:@"url"];
    [aCoder encodeFloat:self.lastPos forKey:@"pos"];
    [aCoder encodeInt:self.count forKey:@"cnt"];
    [aCoder encodeObject:self.lastPlayTime forKey:@"time"];
}

-(id)init
{
    self = [super init];
    if ( self != nil ) {
        self.lastPos = 0.0f;
        self.count = 0;
        self.lastPlayTime = nil;
    }
    return  self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if ( self != nil ) {
        self.url = [aDecoder decodeObjectForKey:@"url"];
        self.lastPos = [aDecoder decodeFloatForKey:@"pos"];
        self.count = [aDecoder decodeIntForKey:@"cnt"];
        self.lastPlayTime = [aDecoder decodeObjectForKey:@"time"];
    }
    return self;
}

@end
