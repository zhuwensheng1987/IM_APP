//
//  FFLocalViewController.m
//  FFPlayer
//
//  Created by Coremail on 14-1-14.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import "FFLocalViewController.h"
#import "KxMovieViewController.h"
#import "FFHelper.h"
#import "FFSetting.h"
#import "FFPlayer.h"
#import "FFAlertView.h"
#import "FFLocalFileManager.h"
#import "TTOpenInAppActivity.h"
#import "MWPhotoBrowser.h"
#import "MBProgressHUD.h"

enum {
    IN_LOCAL,
    IN_SECRET,
};

@interface FFLocalViewController () <UIDocumentInteractionControllerDelegate, MWPhotoBrowserDelegate>
{
    NSArray *   _localMovies;
    NSString * _currentPath;
    UIBarButtonItem *           btnEdit;
    UIBarButtonItem *           btnDone;
    FFPlayer *                  _ffplayer;
    
    NSMutableArray *            _photos;
    NSMutableArray *            _thumbs;
    
    NSArray *                   itemToMove;
    int                         currentState;
    
    NSString *                  tempUncompressPath;
    NSString *                  secretName;
}

@property (nonatomic, strong) UIPopoverController *activityPopoverController;

@end

@implementation FFLocalViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(void) switchToSelectFolderAndMoveItems:(NSArray *)aryItemToMove
{
    itemToMove = aryItemToMove;
}

-(void) switchToUncompressMode:(NSString *)strTempPath name:(NSString *)filename
{
    tempUncompressPath = strTempPath;
    secretName = filename;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[NSFileManager defaultManager] createDirectoryAtPath:[FFLocalFileManager getSecretRootPath] withIntermediateDirectories:NO attributes:nil error:nil];
    currentState = IN_LOCAL;
    
    if ( secretName == nil )
        secretName = NSLocalizedString(@"Secret", nil);
    
    if ( itemToMove != nil ) {
        self.title = self.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"Move to %@", nil), _currentPath == nil ? @"/" : _currentPath];
        btnEdit = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(exitMove:)];
        btnDone = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(switchEditMode:)];
        self.navigationItem.rightBarButtonItem = btnDone;
        self.navigationItem.leftBarButtonItem = btnEdit;
    } else if ( tempUncompressPath == nil ) {
        self.title = self.navigationItem.title = NSLocalizedString(@"Local", @"Local Files");
        btnEdit = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(switchEditMode:)];
        btnDone = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(switchEditMode:)];
        self.navigationItem.rightBarButtonItem = btnEdit;
    } else {
        self.navigationItem.leftBarButtonItem = nil;
        self.navigationItem.backBarButtonItem = nil;
        [self.navigationItem setHidesBackButton:YES];
    }
    
    self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    
    _ffplayer = [[FFPlayer alloc] init];
    
    UIBarButtonItem * flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    UIBarButtonItem * btnAddFolder = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addFolder:)];
    UIBarButtonItem * btnRename = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(editItem:)];
    UIBarButtonItem * btnMove = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(moveItem:)];
    UIBarButtonItem * btnDelete = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deletItem:)];

    self.toolbarItems = [ NSArray arrayWithObjects: flex,btnAddFolder,
                                                    flex,btnRename,
                                                    flex,btnMove,
                                                    flex,btnDelete,
                                                    flex,nil ];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadMovies];
}

-(void) dealloc
{
    if ( tempUncompressPath != nil )
        [[NSFileManager defaultManager] removeItemAtPath:tempUncompressPath error:nil];
}

-(NSString *) getCurrentFullPath
{
    return [FFLocalFileManager getCurrentFolder:_currentPath inSecret:(currentState == IN_SECRET)];
}

- (void) reloadMovies
{
    if ( tempUncompressPath != nil ) {
        _localMovies = [FFLocalFileManager listFolder:tempUncompressPath  subPath:_currentPath inSecret:YES];
        currentState = IN_SECRET;
    } else {
        BOOL inSecret = (currentState == IN_SECRET);
        NSString * strRoot = inSecret ? [FFLocalFileManager getSecretRootPath] : [FFLocalFileManager getRootFullPath];
        _localMovies = [FFLocalFileManager listFolder:strRoot subPath:_currentPath inSecret:inSecret];
    }

    NSString * strTitle = nil;
    if ( itemToMove != nil ) {
        if ( currentState == IN_SECRET )
            strTitle = [NSString stringWithFormat:NSLocalizedString(@"Move to %@ (Secret)", nil), _currentPath == nil ? @"/" : _currentPath];
        else
            strTitle = [NSString stringWithFormat:NSLocalizedString(@"Move to %@", nil), _currentPath == nil ? @"/" : _currentPath];
    } else {
        if ( _currentPath == nil ) {
            if ( currentState == IN_SECRET )
                strTitle = secretName;
            else
                strTitle = NSLocalizedString(@"Local", @"Local Files");
        } else {
            if ( currentState == IN_SECRET )
                strTitle = [NSString stringWithFormat:@"%@ (%@)", _currentPath, secretName];
            else
                strTitle = _currentPath;
        }
    }
    self.title = self.navigationItem.title = strTitle;
    [self.tableView reloadData];
}

-(void) switchEditMode:(id)sender
{
    if ( itemToMove != nil ) {
        //Check taget is the same as select items;
        FFLocalItem * item1 = [itemToMove firstObject];
        NSString * strSrcPath = [item1.fullPath stringByDeletingLastPathComponent];
        NSString * strTarPath = [self getCurrentFullPath];
        if ( ![strTarPath isEqualToString:strSrcPath] ) {
            NSFileManager * mgr = [NSFileManager defaultManager];
            NSMutableArray * aryFailList = [[NSMutableArray alloc] init];
            for (FFLocalItem * item in itemToMove) {
                NSString * targetFull = [strTarPath stringByAppendingPathComponent:item.fileName];
                if ( ![mgr moveItemAtPath:item.fullPath toPath:targetFull error:nil] ) {
                    [aryFailList addObject:item.fileName];
                }
            }
            [self exitMove:sender];
            if ( aryFailList.count > 0 ) {
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                            message:[NSString stringWithFormat:NSLocalizedString(@"Move %@ fail!", nil), [aryFailList componentsJoinedByString:@","]]
                                           delegate:nil
                                  cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                  otherButtonTitles:nil] show];
            }
        }
    } else {
        self.tableView.editing = !self.tableView.editing;
        self.navigationItem.rightBarButtonItem = self.tableView.editing ? btnDone : btnEdit;
        [self.navigationController setToolbarHidden:!self.tableView.editing];
    }
}

-(void) exitMove:(id)sender
{
    if ( itemToMove == nil )
        return;
    [self.navigationController setToolbarHidden:NO];
    if (self.presentingViewController || !self.navigationController)
        [self dismissViewControllerAnimated:YES completion:nil];
    else
        [self.navigationController popViewControllerAnimated:YES];
}

-(NSString *)makeSureFileName:(NSString *)str
{
    NSString * trimFolder = [str stringByReplacingOccurrencesOfString:@"/" withString:@""];
    if ([trimFolder hasPrefix:@"."])
        trimFolder = [trimFolder stringByReplacingCharactersInRange:NSMakeRange(0,1)  withString:@"_"];
    return trimFolder;
}

-(void) addFolder:(id)sender
{
    __weak FFLocalViewController * weakSelf = self;
    [FFAlertView showWithTitle:NSLocalizedString(@"Create Folder", nil)
                       message:nil
                   defaultText:@""
                         style:UIAlertViewStylePlainTextInput
                    usingBlock:^(NSUInteger btn, NSString * folder) {
                        if ( btn == 0 )
                            return;
                        NSFileManager * mgr = [NSFileManager defaultManager];
                        NSString * trimFolder = [self makeSureFileName:folder];
                        if ( !trimFolder || ([trimFolder isEqualToString:@"Secret"] && _currentPath == nil && currentState != IN_SECRET))
                            return;
                        NSString * strFullPath = [[self getCurrentFullPath] stringByAppendingPathComponent:trimFolder];
                        NSError * err = nil;
                        [mgr createDirectoryAtPath:strFullPath withIntermediateDirectories:NO attributes:nil error:&err];
                        if ( err != nil ) {
                            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                                        message:NSLocalizedString(@"Create folder fail!", nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                              otherButtonTitles:nil] show];
                        } else {
                            FFLocalViewController * strongSelf = weakSelf;
                            [strongSelf reloadMovies];
                        }
                        
                    }
             cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
             otherButtonTitles:NSLocalizedString(@"Create", nil), nil
     ];
}

-(NSArray *)getAllSelected
{
    NSMutableArray * arySelectedItems = [[NSMutableArray alloc] init];
    
    size_t i = 0;
    for ( FFLocalItem *item in _localMovies ) {
        if ( item.editable ) {
            UITableViewCell * cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
            if ( cell.isSelected )
                [arySelectedItems addObject:item];
        }
        ++i;
    }
    return arySelectedItems;
}

-(void) deletItem:(id)sender
{
    NSArray * arySelected = [self getAllSelected];
    if ( arySelected.count == 0 )
        return;
    
    __weak FFLocalViewController * weakSelf = self;
    [FFAlertView showWithTitle: (( arySelected.count == 1 ) ? NSLocalizedString(@"Delete Item ?", nil) : NSLocalizedString(@"Delete Items ?", nil))
                       message:nil
                   defaultText:nil
                         style:UIAlertViewStyleDefault
                    usingBlock:^(NSUInteger btn, NSString * folder) {
                        if ( btn == 0 )
                            return;
                        FFLocalViewController * strongSelf = weakSelf;
                        NSFileManager * mgr = [NSFileManager defaultManager];
                        for ( FFLocalItem *item in arySelected ) {
                                if ( ![mgr removeItemAtPath:item.fullPath error:nil] ) {
                                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                                                message:[NSString stringWithFormat:NSLocalizedString(@"Delete %@ fail!", nil),item.fileName]
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                                      otherButtonTitles:nil] show];
                                }
                        }
                        [strongSelf reloadMovies];
                    }
             cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
             otherButtonTitles:NSLocalizedString(@"Delete", nil), nil
     ];
}

-(void) editItem:(id)sender
{
    NSArray * arySelected = [self getAllSelected];
    if ( arySelected.count == 0 )
        return;
    else if ( arySelected.count > 1 ) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                    message:NSLocalizedString(@"Only support rename one file/directory!", nil)
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"Close", nil)
                          otherButtonTitles:nil] show];
        return;
    }

    __weak FFLocalViewController * weakSelf = self;
    FFLocalItem *item = [arySelected firstObject];
    [FFAlertView showWithTitle:NSLocalizedString(@"Modify name", nil)
                       message:nil
                   defaultText:item.fileName
                         style:UIAlertViewStylePlainTextInput
                    usingBlock:^(NSUInteger btn, NSString * folder) {
                            if ( btn == 0 )
                                return;
                            NSString * strTrimPath = [self makeSureFileName:folder];
                            if ( !strTrimPath || [strTrimPath isEqualToString:item.fileName] )
                                return;
                            NSString * strNewPath = [[self getCurrentFullPath] stringByAppendingPathComponent:strTrimPath];
                            NSFileManager * mgr = [NSFileManager defaultManager];
                            if ( ![mgr moveItemAtPath:item.fullPath toPath:strNewPath error:nil] ) {
                                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                                            message:[NSString stringWithFormat:NSLocalizedString(@"Rename %@ -> %@ fail!", nil),item.fileName, strTrimPath]
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                                  otherButtonTitles:nil] show];
                            } else {
                                FFLocalViewController * strongSelf = weakSelf;
                                [strongSelf reloadMovies];
                            }
                        }
            cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
             otherButtonTitles:NSLocalizedString(@"Modify", nil), nil
    ];
}

-(void) moveItem:(id)sender
{
    NSArray * arySelected = [self getAllSelected];
    if ( arySelected.count == 0 )
        return;

    FFLocalViewController * vc = [self.storyboard instantiateViewControllerWithIdentifier:@"LocalFile"];
    [vc switchToSelectFolderAndMoveItems:arySelected];
    [self.navigationController setToolbarHidden:YES];
    [self.navigationController pushViewController:vc animated:TRUE];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return _localMovies.count;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FFLocalItem * item = _localMovies[indexPath.row];
	return item.editable ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"LocalCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    FFLocalItem * item = _localMovies[indexPath.row];
    
    if ( item.isDir ) {
        
        NSString * strPath = item.fileName;
        if ( item.type == LIT_PARENT )
            strPath = NSLocalizedString(@"Parent", nil);
        else if ( item.type == LIT_SECRETE )
            strPath = secretName;
        
        cell.textLabel.text = [NSString stringWithFormat:@"[%@]", strPath];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:20];
        cell.detailTextLabel.text = nil;
        cell.detailTextLabel.textColor = cell.textLabel.textColor = [UIColor blackColor];
        if ( item.type == LIT_SECRETE )
            cell.imageView.image = [UIImage imageNamed:@"padlock"];
        else if ( item.type == LIT_PARENT )
            cell.imageView.image = [UIImage imageNamed:@"arrowup"];
        else
            cell.imageView.image = [UIImage imageNamed:@"folder"];
        
        if ( item.type == LIT_DIR && itemToMove != nil )  {   //in Moveing mode
            for (FFLocalItem * check in itemToMove) {
                if ( [check.fullPath isEqualToString:item.fullPath] ) {
                    cell.detailTextLabel.textColor = cell.textLabel.textColor = [UIColor grayColor];
                    break;
                }
            }
        }
    } else {
        cell.textLabel.text = item.fileName;

        NSByteCountFormatter *byteCountFormatter = [[NSByteCountFormatter alloc] init];
        [byteCountFormatter setAllowedUnits:NSByteCountFormatterUseMB];
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
        
        if ( item.type == LIT_MIDEA )
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@ last:%02d:%02d played %d time(s)"
                                        , [dateFormatter stringFromDate:item.modifyTime]
                                        , [byteCountFormatter stringFromByteCount:item.size]
                                        , (int)(item.lastPos / 60), (int)(item.lastPos) % 60
                                        ,item.playCount
                                     ];
        else
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@"
                                         , [dateFormatter stringFromDate:item.modifyTime]
                                         , [byteCountFormatter stringFromByteCount:item.size]
                                         ];
        
        if ( itemToMove != nil )  {   //in Moveing mode
            cell.detailTextLabel.textColor = cell.textLabel.textColor = [UIColor grayColor];
        } else {
            cell.detailTextLabel.textColor = cell.textLabel.textColor = [UIColor blackColor];
        }
        
        if (item.type == LIT_MIDEA )
            cell.imageView.image = [UIImage imageNamed:@"movie"];
        else if ( item.type == LIT_PIC )
            cell.imageView.image = [UIImage imageNamed:@"camera"];
        else if ( item.type == LIT_ZIP )
            cell.imageView.image = [UIImage imageNamed:@"briefcase"];
        else
            cell.imageView.image = [UIImage imageNamed:@"disk"];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ( tableView.editing ) {
        
    } else {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        FFLocalItem * item = _localMovies[indexPath.row];
        switch (item.type) {
            case LIT_PARENT:
            {
                if (_currentPath == nil && tempUncompressPath != nil) {
                    [self.navigationController popViewControllerAnimated:YES];
                    return;
                } else if ( _currentPath == nil && currentState == IN_SECRET ) {
                    currentState = IN_LOCAL;
                } else {
                    _currentPath = [_currentPath stringByDeletingLastPathComponent];
                    if ( _currentPath.length == 0 )
                        _currentPath = nil;
                }
                [self reloadMovies];
            }break;
            case LIT_SECRETE:
            {
                currentState = IN_SECRET;
                [self reloadMovies];
            }break;
            case LIT_DIR:
            {
                if ( _currentPath == nil )
                    _currentPath = item.fileName;
                else
                    _currentPath = [_currentPath stringByAppendingPathComponent:item.fileName];
                [self reloadMovies];
            }break;
            case LIT_MIDEA:
            {
                NSMutableArray  * aryList = [[NSMutableArray alloc] init];
                int index = 0, i = 0;
                for ( FFLocalItem * it in _localMovies) {
                    if  ( it.type != LIT_MIDEA )
                        continue;
                    else if ( it == item )
                        index = i;
                    [aryList addObject:[[FFPlayItem alloc] initWithPath:it.fullPath position:it.lastPos keyName:it.fullPath]];
                    ++i;
                }
                [_ffplayer playList:aryList curIndex:index parent:self];
            }break;
            case LIT_PIC: {
                [self displayPic:item];
            }break;
            case LIT_ZIP: {
                if ( self.navigationController.navigationBar)
                    self.navigationController.navigationBar.userInteractionEnabled = NO;
                MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
                hud.labelText = NSLocalizedString(@"Uncompressing ...", nil);
                __weak FFLocalViewController * weakSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString * strTemp = [FFLocalFileManager uncompress:item.fullPath];
                    if ( weakSelf.navigationController.navigationBar)
                        weakSelf.navigationController.navigationBar.userInteractionEnabled = YES;
                    [MBProgressHUD hideHUDForView:weakSelf.view animated:YES];
                    if ( strTemp == nil )
                        return;
                    FFLocalViewController * vc = [weakSelf.storyboard instantiateViewControllerWithIdentifier:@"LocalFile"];
                    [vc switchToUncompressMode:strTemp name:item.fileName];
                    [weakSelf.navigationController pushViewController:vc animated:YES];
                });
            } break;
            default:
            {
                NSURL * newURL = [NSURL fileURLWithPath:item.fullPath];
                UIDocumentInteractionController * ctrl = [UIDocumentInteractionController interactionControllerWithURL:newURL];
                [ctrl setDelegate:self];
                BOOL boCanPreview = [ctrl presentPreviewAnimated:YES];
                NSLog(@"Can preview: %d", boCanPreview);
                if (!boCanPreview) {
                    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                    CGRect rect= cell.bounds; //CGRectMake(cell.bounds.origin.x+60, cell.bounds.origin.y+10, 50, 30);
                    
                    TTOpenInAppActivity *openInAppActivity = [[TTOpenInAppActivity alloc] initWithView:cell andRect:rect];
                    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[newURL] applicationActivities:@[openInAppActivity]];
                    
                    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
                        // Store reference to superview (UIActionSheet) to allow dismissal
                        openInAppActivity.superViewController = activityViewController;
                        // Show UIActivityViewController
                        [self presentViewController:activityViewController animated:YES completion:NULL];
                    } else {
                        // Create pop up
                        self.activityPopoverController = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
                        // Store reference to superview (UIPopoverController) to allow dismissal
                        openInAppActivity.superViewController = self.activityPopoverController;
                        // Show UIActivityViewController in popup
                        [self.activityPopoverController presentPopoverFromRect:rect inView:cell permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
                    }
                }

            }break;
        };
    }
}

- (UIViewController *) documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *) controller {
    return self;
}

-(void) unlock:(BOOL) bo
{
    [[FFSetting default] setUnlock:bo];
    if ( !bo && currentState == IN_SECRET ) {
        currentState = IN_LOCAL;
        _currentPath = nil;
    }
    [self reloadMovies];
}

-(void) toggleLock
{
    if ( ![[FFSetting default] hasPassword] ) {
        __weak FFLocalViewController * weakSelf = self;
        return [FFAlertView inputPassword2: NSLocalizedString(@"Input unlock initial password", nil)
                            message: NSLocalizedString(@"First input the password.", nil)
                           message2:NSLocalizedString(@"Confirm the password", nil)
                         usingBlock:^(BOOL notTheSame,NSString * pass) {
                             if ( notTheSame ) {
                                 [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                                             message:NSLocalizedString(@"Password not the same!", nil)
                                                            delegate:nil
                                                   cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                                   otherButtonTitles:nil] show];
                             } else {
                                 [[FFSetting default] setPassword:pass];
                                 FFLocalViewController * strongSelf = weakSelf;
                                 [strongSelf unlock:YES];
                             }
                         }
                  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                     okButtonTitles:NSLocalizedString(@"OK", nil)
         ];
    } else if ( [[FFSetting default] unlock] ) {
        return [self unlock:FALSE];
    }
    
    __weak FFLocalViewController * weakSelf = self;
    [FFAlertView showWithTitle: NSLocalizedString(@"Input unlock password", nil)
                       message:nil
                   defaultText:@""
                         style:UIAlertViewStyleSecureTextInput
                    usingBlock:^(NSUInteger btn, NSString * pass) {
                        if ( btn == 0 || !pass)
                            return;
                        else if ( [[FFSetting default] checkPassword:pass] ) {
                            FFLocalViewController * strongSelf = weakSelf;
                            return [strongSelf unlock:YES];
                        }
                    }
             cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
             otherButtonTitles:NSLocalizedString(@"Unlock", nil), nil
     ];
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    FFLocalItem * item = _localMovies[indexPath.row];
    return item.editable;
}

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

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

-(void) displayPic:(FFLocalItem *)item
{
    NSMutableArray *photos = [[NSMutableArray alloc] init];
    NSMutableArray *thumbs = [[NSMutableArray alloc] init];
    
    MWPhoto *photo;
    BOOL displayActionButton = YES;
    BOOL displaySelectionButtons = NO;
    BOOL displayNavArrows = YES;
    BOOL enableGrid = YES;
    BOOL startOnGrid = NO;

    int index = 0, i = 0;
    for ( FFLocalItem * it in _localMovies) {
        if  ( it.type != LIT_PIC )
            continue;
        else if ( it == item )
            index = i;
        ++i;
        
        photo = [MWPhoto photoWithURL:[NSURL fileURLWithPath:it.fullPath]];
        photo.caption = it.fileName;
        [photos addObject:photo];
        [thumbs addObject:photo];
    }
    
    _photos = photos;
    _thumbs = thumbs;

    MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    browser.displayActionButton = displayActionButton;
    browser.displayNavArrows = displayNavArrows;
    browser.displaySelectionButtons = displaySelectionButtons;
    browser.alwaysShowControls = displaySelectionButtons;
    browser.extendedLayoutIncludesOpaqueBars = YES;
    browser.zoomPhotosToFill = YES;
    browser.enableGrid = enableGrid;
    browser.startOnGrid = startOnGrid;
    [browser setCurrentPhotoIndex:index];
    
    [self.navigationController pushViewController:browser animated:YES];
    /*
    {
        // Modal
        UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:browser];
        nc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [self presentModalViewController:nc animated:YES];
    }
    */
    // Release
	
    // Test reloading of data after delay
    double delayInSeconds = 3;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    });
}

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return _photos.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index < _photos.count)
        return [_photos objectAtIndex:index];
    return nil;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser thumbPhotoAtIndex:(NSUInteger)index {
    if (index < _thumbs.count)
        return [_thumbs objectAtIndex:index];
    return nil;
}

@end
