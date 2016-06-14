//
//  FFSparkViewController.h
//  FFPlayer
//
//  Created by Coremail on 14-1-27.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FFSparkViewController : UITableViewController

-(void) setSparkServer:(NSString *)setting baseURL:(NSString *)baseURL name:(NSString *)name;
-(void) unlock;

@end
