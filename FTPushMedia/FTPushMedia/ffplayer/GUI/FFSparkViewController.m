//
//  FFSparkViewController.m
//  FFPlayer
//
//  Created by Coremail on 14-1-27.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import "FFSparkViewController.h"
#import "AFNetworking.h"
#import "MBProgressHUD.h"
#import "FFAlertView.h"
#import "FFHelper.h"
#import "FFSetting.h"
#import "FFPlayHistoryManager.h"
#import "FFHelper.h"
#import "FFPlayer.h"

#define ASYNC_HUD_BEGIN(strTitle)   if ( self.navigationController.navigationBar) self.navigationController.navigationBar.userInteractionEnabled = NO;\
                                    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES]; \
                                    hud.labelText = strTitle;   \
                                    _loading = YES;
#define ASYNC_HUD_END               if ( self.navigationController.navigationBar) self.navigationController.navigationBar.userInteractionEnabled = YES;\
                                    [MBProgressHUD hideHUDForView:self.view animated:YES]; \
                                    _loading = NO;

//////////////////////////////////////////////////

@interface FFSparkItem : NSObject

@property (atomic) NSString *   path;
@property (atomic) NSString *   name;
@property (assign) BOOL         goParent;
@property (assign) BOOL         dir;
@property (assign) BOOL         root;
@property (assign) BOOL         lock;
@property (atomic) NSString *   mtime;
@property (assign) long long    size;
@property (assign) int          random;
@property (assign) int          playCount;
@property (assign) CGFloat      lastPos;

@end

@implementation FFSparkItem

-(id) init {
    self = [super init];
    if ( self != nil ) {
        
    }
    return  self;
}

@end

///////////////////////////////////////////////////

@interface MyJSONResponseSerializer : AFJSONResponseSerializer

+ (instancetype)serializerWithReadingOptions:(NSJSONReadingOptions)readingOptions;

@end

@implementation MyJSONResponseSerializer

+ (instancetype)serializer {
    return [self serializerWithReadingOptions:0];
}

+ (instancetype)serializerWithReadingOptions:(NSJSONReadingOptions)readingOptions {
    MyJSONResponseSerializer *serializer = [[self alloc] init];
    serializer.readingOptions = readingOptions;
    return serializer;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    self.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", nil];
    
    return self;
}

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error
{
    NSString * fix = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"}{" withString:@"},{"];
    return [super responseObjectForResponse:response data:[fix dataUsingEncoding: NSUTF8StringEncoding] error:error];
}

@end

///////////////////////////////////////////////////

static FFPlayer * _internalPlayer = nil;

@interface FFSparkViewController ()
{
    UIBarButtonItem *           btnRefresh;
    BOOL         _loading;
    NSString * _setting;
    NSString * _name;
    NSString * _baseURL;
    NSString * _urlPrefix;
    NSString * _extPHP;
    NSArray *    _arySprkItems;
}
@end

@implementation FFSparkViewController

-(void) setSparkServer:(NSString *)setting baseURL:(NSString *)baseURL name:(NSString *)name
{
    _baseURL = baseURL;
    _name = name;
    _setting = setting;

    if ( [_setting rangeOfString:@":"].location == NSNotFound )
        _urlPrefix = [NSString stringWithFormat:@"http://%@:27888", _setting];
    else
        _urlPrefix = [NSString stringWithFormat:@"http://%@", _setting];
    
    if ( [_setting rangeOfString:@"/"].location != NSNotFound)
        _extPHP = @".php";
    else
        _extPHP = @"";
}

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
    
    _arySprkItems = [[NSArray alloc] init];
    self.title = _name;

    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.backBarButtonItem = nil;
    [self.navigationItem setHidesBackButton:YES];

    btnRefresh = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(onRefresh:)];
    self.navigationItem.rightBarButtonItem = btnRefresh;
    _loading = FALSE;
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    [self loadList];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) onRefresh:(id)sender {
    [self loadList];
}

-(void) unlock {
    __weak FFSparkViewController * weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [FFAlertView showWithTitle:NSLocalizedString(@"Input the password", nil)
                           message:nil
                       defaultText:nil
                             style:UIAlertViewStyleSecureTextInput
                        usingBlock:^(NSUInteger btn, NSString * str) {
                            if ( btn == 0 || str == nil || str.length == 0 )
                                return;
                            [weakSelf doUnlock:str];
                        }
                 cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                 otherButtonTitles:NSLocalizedString(@"OK", nil),nil];
    });
}

-(void) needLogin
{
    __weak FFSparkViewController * weakSelf = self;
    [FFAlertView showWithTitle:NSLocalizedString(@"Input the password", nil)
                       message:nil
                   defaultText:nil
                         style:UIAlertViewStyleSecureTextInput
                    usingBlock:^(NSUInteger btn, NSString * str) {
                        if ( btn == 0 || str == nil || str.length == 0 )
                            return;
                        [weakSelf login:str];
                    }
             cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
             otherButtonTitles:NSLocalizedString(@"OK", nil),nil];
}

-(void) onGetList:(NSDictionary *)dictData
{
    NSMutableArray * ary = [[NSMutableArray alloc] init];
    NSArray * aryItems = [((NSDictionary *)dictData) objectForKey:@"data"];
    FFPlayHistoryManager * history = [FFPlayHistoryManager default];

    for ( NSDictionary * dict in aryItems ) {
        FFSparkItem * item = [[FFSparkItem alloc] init];
        item.name = [dict objectForKey:@"name"];
        item.dir = [[dict objectForKey:@"dir"] isEqualToString:@"true"];
        item.path = [dict objectForKey:@"path"];
        item.root = [[dict objectForKey:@"root"] isEqualToString:@"true"];
        item.lock = [[dict objectForKey:@"lock"] isEqualToString:@"true"];
        if ( item.name != nil && item.name.length > 0) {
            if ([item.name hasPrefix:@"."])
                continue;
            else if ( !item.root && !item.dir && ![FFHelper isSupportMidea:item.name] )
                continue;
        }
        if ( item.root ) {
            item.mtime = @"";
            item.size = 0;
            item.playCount = 0;
            item.lastPos = 0.0f;
        } else {
            item.mtime = [dict objectForKey:@"mtime"];
            item.size = [[dict objectForKey:@"size"] longLongValue];
            
            int n = 0;
            item.lastPos = [history getLastPlayInfo:[_baseURL stringByAppendingPathComponent:item.name] playCount:&n];
            item.playCount = n;
            int a = (arc4random() % 0x1000000);
            int b = ((item.playCount < 0x7f ? item.playCount : 0x7f ) * 0x1000000);
            item.random = a + b;
        }
        
        [ary addObject:item];
    }
    
    NSMutableArray * arySort = [[NSMutableArray alloc] init];
    [arySort addObject:[NSSortDescriptor sortDescriptorWithKey:@"dir" ascending:NO]];
    int nSort = [[FFSetting default] sparkSortType];
    if ( nSort == SORT_BY_DATE || nSort == SORT_BY_DATE_DESC )
        [arySort addObject:[NSSortDescriptor sortDescriptorWithKey:@"mtime" ascending:(nSort == SORT_BY_DATE)]];
    else if ( nSort == SORT_BY_NAME || nSort == SORT_BY_NAME_DESC )
        [arySort addObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:(nSort == SORT_BY_NAME)]];
    else
        [arySort addObject:[NSSortDescriptor sortDescriptorWithKey:@"random" ascending:YES]];
    
    FFSparkItem * itemGoParent = [[FFSparkItem alloc] init];
    itemGoParent.goParent = YES;
    _arySprkItems = [@[itemGoParent] arrayByAddingObjectsFromArray:[ary sortedArrayUsingDescriptors:arySort]];

    [self.tableView reloadData];
}

-(void) handleError:(AFHTTPRequestOperation *)operation error:(NSError *)error
{
    NSHTTPURLResponse * respond = operation.response;
    if ( respond.statusCode == 401 ) { //Need login
        [self needLogin];
        return;
    }
    [FFAlertView showWithTitle:NSLocalizedString(@"Error", nil)
                       message:[error description]
                   defaultText:nil
                         style:UIAlertViewStyleDefault
                    usingBlock:nil
             cancelButtonTitle:NSLocalizedString(@"OK", nil)
             otherButtonTitles:nil];
}

-(void) loadList
{
    if ( _loading )
        return;
    
    __weak FFSparkViewController * weakSelf = self;
    ASYNC_HUD_BEGIN( NSLocalizedString(@"Loading", nil) );
    NSString * strURL = [[_urlPrefix stringByAppendingString:@"/list"] stringByAppendingString:_extPHP];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:strURL]];
    
    if ( _baseURL != nil && _baseURL.length > 0 ) {
        AFHTTPRequestSerializer * sz = [AFHTTPRequestSerializer serializer];
        request = [sz requestBySerializingRequest:request withParameters:@{ @"path" : _baseURL } error:nil];
    }
    
    AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    op.responseSerializer = [MyJSONResponseSerializer serializer];
    [op setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        ASYNC_HUD_END;
        NSLog(@"JSON: %@", responseObject);
        [weakSelf onGetList:responseObject];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        ASYNC_HUD_END;
        if ( error.code == -1016 && [[error.userInfo objectForKey:@"NSLocalizedDescription"] isEqualToString:@"Request failed: unacceptable content-type: text/plain"] ) {
            _extPHP = @".php";
            [weakSelf loadList];
        } else {
            [weakSelf handleError:operation error:error];
        }
    }];
    [[NSOperationQueue mainQueue] addOperation:op];
}

-(void) login:(NSString *)pass
{
    NSString * strMD5 = [FFHelper md5HexDigest:pass];
    NSString * strQuery = [NSString stringWithFormat:@"%@/login_server%@?spid=%@", _urlPrefix, _extPHP, strMD5];
    
    __weak FFSparkViewController * weakSelf = self;
    ASYNC_HUD_BEGIN( NSLocalizedString(@"Login", nil) );

    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    
    [manager GET:strQuery parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        ASYNC_HUD_END;
        NSLog(@"JSON: %@", responseObject);
        [weakSelf loadList];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        ASYNC_HUD_END;
        [weakSelf handleError:operation error:error];
    }];
}

-(void) doUnlock:(NSString *)pass
{
    NSString * strMD5 = [FFHelper md5HexDigest:pass];
    NSString * strQuery = [NSString stringWithFormat:@"%@/login%@?pid=%@", _urlPrefix, _extPHP, strMD5];
    
    __weak FFSparkViewController * weakSelf = self;
    ASYNC_HUD_BEGIN( NSLocalizedString(@"Login", nil) );
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    
    [manager GET:strQuery parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        ASYNC_HUD_END;
        NSLog(@"JSON: %@", responseObject);
        [weakSelf loadList];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        ASYNC_HUD_END;
        [weakSelf handleError:operation error:error];
    }];
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
    return _arySprkItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    FFSparkItem * item = [_arySprkItems objectAtIndex:indexPath.row];
    if ( item.goParent ) {
        cell.textLabel.text = [NSString stringWithFormat:@"[%@]", NSLocalizedString(@"Parent", nil)];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:20];
        cell.detailTextLabel.text = nil;
        cell.detailTextLabel.textColor = cell.textLabel.textColor = [UIColor blackColor];
        cell.imageView.image = [UIImage imageNamed:@"arrowup"];
    } else if ( item.dir ) {
        cell.textLabel.text = [NSString stringWithFormat:@"[%@]", item.name];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:20];
        cell.detailTextLabel.text = nil;
        cell.detailTextLabel.textColor = cell.textLabel.textColor = [UIColor blackColor];
        if ( !item.lock )
            cell.imageView.image = [UIImage imageNamed:@"folder"];
        else
            cell.imageView.image = [UIImage imageNamed:@"padlock"];
    } else {
        
        cell.textLabel.text = item.name;
        if ( item.playCount == 0 )
            cell.textLabel.font = [UIFont boldSystemFontOfSize:20];
        else
            cell.textLabel.font = [UIFont systemFontOfSize:20];
        
        NSByteCountFormatter *byteCountFormatter = [[NSByteCountFormatter alloc] init];
        [byteCountFormatter setAllowedUnits:NSByteCountFormatterUseMB];
        
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@ last:%02d:%02d played %d time(s)"
                                     , item.mtime
                                     , [byteCountFormatter stringFromByteCount:item.size]
                                     , (int)(item.lastPos / 60), (int)(item.lastPos) % 60
                                     ,item.playCount
                                     ];
        
        cell.imageView.image = [UIImage imageNamed:@"movie"];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    FFSparkItem * item = [_arySprkItems objectAtIndex:indexPath.row];
    if ( item.goParent ) {
        [self.navigationController popViewControllerAnimated:YES];
    } else if ( item.dir ) {
        FFSparkViewController * vc = [self.storyboard instantiateViewControllerWithIdentifier:@"FFSparkViewController"];
        NSString * strNewBaseURL = nil;
        if ( item.root )
            strNewBaseURL = item.path;
        else
            strNewBaseURL = [_baseURL stringByAppendingPathComponent:item.name];
        
        [vc setSparkServer:_setting baseURL:strNewBaseURL name:item.name ];
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        if ( _internalPlayer == nil )
            _internalPlayer = [[FFPlayer alloc] init];
        
        NSString * strURL = [[_urlPrefix stringByAppendingString:@"/play.m3u8"] stringByAppendingString:_extPHP];
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:strURL]];
        AFHTTPRequestSerializer * sz = [AFHTTPRequestSerializer serializer];
        FFSetting * setting = [FFSetting default];
        
        NSMutableArray  * aryList = [[NSMutableArray alloc] init];
        int index = 0, i = 0;
        for ( FFSparkItem * it in _arySprkItems) {
            if  ( it.dir || it.root || it.goParent )
                continue;
            else if ( it == item )
                index = i;
        
            NSURLRequest * req = [sz requestBySerializingRequest:request withParameters:@{
                                                                                          @"path" : [_baseURL stringByAppendingPathComponent:it.name]
                                                                                          ,@"bandwidth" : [NSString stringWithFormat:@"%d", [setting bandwidth]]
                                                                                          ,@"res" : [NSString stringWithFormat:@"%d", [setting resolution]]
                                                                                          ,@"boost" : [NSString stringWithFormat:@"%d", [setting boost]]
                                                                                          ,@"aindex" : [NSString stringWithFormat:@"%d", 0]
                                                                                        } error:nil];
            
            [aryList addObject:[[FFPlayItem alloc] initWithPath:[req.URL absoluteString] position:0.0 keyName:[_baseURL stringByAppendingPathComponent:it.name]]];
            ++i;
        }
        [_internalPlayer internalPlayList:aryList curIndex:index parent:self];
    }
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

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

@end
