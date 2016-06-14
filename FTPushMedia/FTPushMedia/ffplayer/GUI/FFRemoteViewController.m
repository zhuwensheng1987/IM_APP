//
//  FFRemoteFileManager.m
//  FFPlayer
//
//  Created by cyt on 14-1-26.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import "FFRemoteViewController.h"
#import "FFLocalFileManager.h"
#import "FFSparkViewController.h"
#import "FFAlertView.h"
#import "FFPlayer.h"
#import "FFPlayHistoryManager.h"

@interface FFRemoteViewController ()
{
    FFPlayer *  _player;
    UIBarButtonItem *           btnEdit;
    UIBarButtonItem *           btnDone;

    NSArray *   arySection;
    NSArray *   arySectionArray;
    NSMutableArray * aryURLHistory;
    NSMutableArray * arySparkList;
}

@end

@implementation FFRemoteViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _player = [[FFPlayer alloc] init];
    btnEdit = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(switchEditMode:)];
    btnDone = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(switchEditMode:)];
    self.navigationItem.rightBarButtonItem = btnEdit;

    aryURLHistory = [[NSMutableArray alloc] init];
    arySparkList = [[NSMutableArray alloc] init];
    [aryURLHistory addObject:@"Add"];
    [arySparkList addObject:@"Add"];
    
    NSArray * loadSparkList = [[NSArray alloc] initWithContentsOfFile:[FFLocalFileManager getSparkSvrListPath]];
    if ( loadSparkList != nil )
        [arySparkList addObjectsFromArray:loadSparkList];
    NSArray * loadURLHistory = [[NSArray alloc] initWithContentsOfFile:[FFLocalFileManager getURLHistoryPath]];
    if ( loadURLHistory != nil )
        [aryURLHistory addObjectsFromArray:loadURLHistory];
    
    arySection = @[
        NSLocalizedString(@"URL History", nil)
        ,NSLocalizedString(@"Spark Server", nil)
    ];
    arySectionArray = @[
        aryURLHistory
        ,arySparkList
    ];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

-(void) switchEditMode:(id)sender
{
    self.tableView.editing = !self.tableView.editing;
    self.navigationItem.rightBarButtonItem = self.tableView.editing ? btnDone : btnEdit;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return [arySection count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return arySection[section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [arySectionArray[section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    if ( indexPath.section == 0) {  //URL history
        if ( indexPath.row == 0 ) {
            cell.textLabel.text = NSLocalizedString(@"Add Media URL", nil);
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.imageView.image = [UIImage imageNamed:@"plus"];
            cell.detailTextLabel.text = nil;
        } else {
            NSURL * url = [NSURL URLWithString:aryURLHistory[ indexPath.row ]];
            cell.textLabel.text = [[url path] lastPathComponent];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.imageView.image = [UIImage imageNamed:@"movie"];
            cell.detailTextLabel.text = aryURLHistory[ indexPath.row ];
        }
    } else if ( indexPath.section == 1 ) { //Sprk Server
        if ( indexPath.row == 0 ) {
            cell.textLabel.text = NSLocalizedString(@"Add Server IP", nil);
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.imageView.image = [UIImage imageNamed:@"plus"];
            cell.detailTextLabel.text = nil;
        } else {
            cell.textLabel.text = arySparkList[ indexPath.row ];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.imageView.image = [UIImage imageNamed:@"connections"];
            cell.detailTextLabel.text = nil;
        }
    }
    // Configure the cell...
    
    return cell;
}

-(void) saveWebURLHistory
{
    NSArray * ary = [aryURLHistory subarrayWithRange:NSMakeRange(1, aryURLHistory.count - 1)];
    [ary writeToFile:[FFLocalFileManager getURLHistoryPath] atomically:YES];
}

-(void) saveSparkSvrHistory
{
    NSArray * ary = [arySparkList subarrayWithRange:NSMakeRange(1, arySparkList.count - 1)];
    [ary writeToFile:[FFLocalFileManager getSparkSvrListPath] atomically:YES];
}

-(void) addWebURL
{
    __weak FFRemoteViewController * weakSelf = self;
    
    [FFAlertView showWithTitle:NSLocalizedString(@"Input the media URL", nil)
                       message:nil
                   defaultText:@""
                         style:UIAlertViewStylePlainTextInput
                    usingBlock:^(NSUInteger btn, NSString * url) {
                        if ( btn == 0 || url == nil || url.length == 0 )
                            return;
                        [aryURLHistory addObject:url];
                        [weakSelf saveWebURLHistory];
                        [weakSelf.tableView reloadData];
                    }
             cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
             otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
}

-(void) addSparkSvr
{
    __weak FFRemoteViewController * weakSelf = self;
    
    [FFAlertView showWithTitle:NSLocalizedString(@"Input the spark server setting, format: IP[:port]", nil)
                       message:NSLocalizedString(@"Default port: 27888", nil)
                   defaultText:@""
                         style:UIAlertViewStylePlainTextInput
                    usingBlock:^(NSUInteger btn, NSString * url) {
                        if ( btn == 0 || url == nil || url.length == 0 )
                            return;
                        [arySparkList addObject:url];
                        [weakSelf saveSparkSvrHistory];
                        [weakSelf.tableView reloadData];
                    }
             cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
             otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ( indexPath.section == 0 ) {
        if ( indexPath.row == 0 ) {
            [self addWebURL];
        } else {
            NSString * url = aryURLHistory[indexPath.row];
            int n = 0;
            CGFloat pos = [[FFPlayHistoryManager default] getLastPlayInfo:url playCount:&n];
            [_player playList:@[ [[FFPlayItem alloc] initWithPath:url position:pos keyName:url] ] curIndex:0 parent:self];
        }
    } else if ( indexPath.section == 1 ) {
        if ( indexPath.row == 0 ) {
            [self addSparkSvr];
        } else {
            NSString * setting = arySparkList[indexPath.row];
            FFSparkViewController * vc = [self.storyboard instantiateViewControllerWithIdentifier:@"FFSparkViewController"];
            [vc setSparkServer:setting baseURL:@"" name:NSLocalizedString(@"[ROOT]", nil)];
            [self.navigationController pushViewController:vc animated:YES];
        }
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    if ( indexPath.row == 0 )
        return  FALSE;
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        BOOL isOK = NO;
        if ( indexPath.section == 0 && indexPath.row > 0 ) {
            [aryURLHistory removeObjectAtIndex:indexPath.row];
            [self saveWebURLHistory];
            isOK = YES;
        } else if ( indexPath.section == 1 && indexPath.row > 0 ) {
            [arySparkList removeObjectAtIndex:indexPath.row];
            [self saveSparkSvrHistory];
            isOK = YES;
        }
        if ( isOK )
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

@end
