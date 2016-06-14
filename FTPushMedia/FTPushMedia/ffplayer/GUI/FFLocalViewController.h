//
//  FFLocalViewController.h
//  FFPlayer
//
//  Created by Coremail on 14-1-14.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FFLocalViewController : UITableViewController

-(void) switchToSelectFolderAndMoveItems:(NSArray *)itemToMove;
-(void) switchToUncompressMode:(NSString *)strTempPath name:(NSString *)filename;
-(void) toggleLock;

@end
