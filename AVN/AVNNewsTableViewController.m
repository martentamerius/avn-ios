//
//  AVNNewsTableViewController.m
//  AVN
//
//  Created by Marten Tamerius on 24-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNNewsTableViewController.h"
#import "AVNHTTPRequestFactory.h"
#import "AVNNewsItem.h"
#import "AVNNewsTableViewCell.h"
#import "AVNNewsItemDetailViewController.h"
#import "AVNAppDelegate.h"
#import "AVNRootViewController.h"
#import <AFNetworking.h>
#import <Mantle.h>
#import <TSMessage.h>
#import <ODRefreshControl.h>


@interface AVNNewsTableViewController ()
@property (nonatomic, strong) NSMutableArray *newsItemsList;
@property (nonatomic, strong) ODRefreshControl *newsItemsListRefreshControl;
@end


@implementation AVNNewsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Add custom refresh control
    ODRefreshControl *refreshControl = [[ODRefreshControl alloc] initInScrollView:self.tableView];
    [refreshControl addTarget:self action:@selector(requestNewsItemsList:) forControlEvents:UIControlEventValueChanged];
    self.newsItemsListRefreshControl = refreshControl;
    [self.tableView setContentOffset:CGPointMake(0.0, (-1*refreshControl.frame.size.height)) animated:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Populate news items list
    if ((!self.newsItemsList) || ([self.newsItemsList count]==0))
        [self requestNewsItemsList:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Populate news items list

- (void)requestNewsItemsList:(NSNotification *)notification
{
    // Request header should have a field with content-type: "appliction/json"
    NSString *contentType = [NSString stringWithFormat:@"application/json; charset=%@", (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))];
    
    // Init request manager (with JSON serializeR) and URL request object
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFHTTPRequestSerializer new];
    [manager.requestSerializer setTimeoutInterval:8];
    manager.responseSerializer = [AFJSONResponseSerializer new];
    [manager.requestSerializer setValue:contentType forHTTPHeaderField:@"Content-Type"];
    
    // Give some visual feedback when the refreshing has been started programmatically
    if (!notification)
        [self.newsItemsListRefreshControl beginRefreshing];
    
    // Init actual HTTP request operation
    __weak AVNNewsTableViewController *weakSelf = self;
    [manager GET:[AVNHTTPRequestFactory urlForAVNNewsItemList] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        // Process the received response with Mantle
        NSError *error = nil;
        NSArray *jsonResponseArray = ([responseObject isKindOfClass:[NSArray class]])?(NSArray *)responseObject:[NSArray arrayWithObject:responseObject];
        
        NSArray *readNewsItems = [[NSUserDefaults standardUserDefaults] arrayForKey:kAVNSetting_ReadNewsItems];
        if (!readNewsItems)
            readNewsItems = @[];
        
        NSMutableArray *newsItemsListFromServer = [NSMutableArray arrayWithCapacity:[jsonResponseArray count]];
        for (id jsonObject in jsonResponseArray) {
            AVNNewsItem *newsItem = [MTLJSONAdapter modelOfClass:[AVNNewsItem class] fromJSONDictionary:jsonObject error:&error];
            if (!newsItem) {
                DLog(@"Error converting AVN JSON news item info: %@, %@", [error localizedDescription], [error userInfo]);
            } else {
                
                // Check in UserDefaults if the user has already seen this news item
                newsItem.hasReadItem = [readNewsItems containsObject:newsItem.identifier];
                
                // Add the news item to the list
                [newsItemsListFromServer addObject:newsItem];
            }
        }
        
        if (newsItemsListFromServer && weakSelf) {
            // Save the converted AVN route list
            weakSelf.newsItemsList = newsItemsListFromServer;
            
            // Refresh UI on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView reloadData];
                [weakSelf.newsItemsListRefreshControl endRefreshing];
                
                [weakSelf updateUnreadNewsItemsBadgeCount];
            });
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DLog(@"Error downloading AVN news items list info: %@, %@", [error localizedDescription], [error userInfo]);
        
        // Refresh UI on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.tableView reloadData];
            [weakSelf.newsItemsListRefreshControl endRefreshing];
            
            [weakSelf updateUnreadNewsItemsBadgeCount];
            
            // Show error message to user
            [TSMessage showNotificationInViewController:weakSelf title:@"Laden van pagina mislukt." subtitle:[error localizedDescription] type:TSMessageNotificationTypeError duration:5 canBeDismissedByUser:YES];
        });
    }];
}

- (void)updateUnreadNewsItemsBadgeCount
{
    NSArray *readItems = [[NSUserDefaults standardUserDefaults] arrayForKey:kAVNSetting_ReadNewsItems];
    
    if (readItems && self.newsItemsList) {
        NSInteger unreadItemCount = MAX(0, [self.newsItemsList count] - [readItems count]);
        
        AVNRootViewController *rootViewController = (AVNRootViewController *)self.tabBarController;
        [rootViewController updateNewsItemBadge:unreadItemCount];
    }
}


#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.newsItemsList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AVNNewsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellNewsItem forIndexPath:indexPath];
    
    AVNNewsItem *newsItem = self.newsItemsList[indexPath.row];
    [cell setUnread:(!newsItem.hasReadItem)];
    [cell setTitle:newsItem.title];
    [cell setSubtitle:newsItem.shortDescription];
    
    if (newsItem.imageURL) {
        
        // Download the actual image on a separate (background) queue
        __weak AVNNewsTableViewCell *weakCell = cell;
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            
            // Background queue: start HTTP request for image
            NSURLRequest *request = [NSURLRequest requestWithURL:newsItem.imageURL];
            AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:request];
            op.responseSerializer = [AFImageResponseSerializer serializer];
            [op setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                
                if (responseObject && [responseObject isKindOfClass:[UIImage class]]) {
                    // Draw the image in a new context with max image dimensions at 44x44
                    CGFloat squareLength = 44.0f;
                    UIGraphicsBeginImageContextWithOptions(CGSizeMake(squareLength, squareLength), NO, 0.0);
                    [(UIImage *)responseObject drawInRect:CGRectMake(0.0, 0.0, squareLength, squareLength)];
                    UIImage * scaledImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                    
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        // Always run UI updates on the main queue
                        [weakCell setThumbnail:scaledImage];
                    });
                }
                
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                DLog(@"Error downloading AVN news item image: %@, %@", [error localizedDescription], [error userInfo]);
            }];
            [[NSOperationQueue mainQueue] addOperation:op];
        });
        
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:kSegueNewsItemListToShowDetail] && self.newsItemsList) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        
        if ([self.newsItemsList count]>indexPath.row) {
            AVNNewsItem *selectedNewsItem = self.newsItemsList[indexPath.row];
            selectedNewsItem.hasReadItem = YES;
            
            NSArray *readItems = [[NSUserDefaults standardUserDefaults] arrayForKey:kAVNSetting_ReadNewsItems];
            if (readItems && (![readItems containsObject:selectedNewsItem.identifier])) {
                NSMutableArray *newReadItems = [NSMutableArray arrayWithArray:readItems];
                [newReadItems addObject:selectedNewsItem.identifier];

                // Save the new array into the UserDefaults for next time
                [[NSUserDefaults standardUserDefaults] setObject:newReadItems forKey:kAVNSetting_ReadNewsItems];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                // Update badge count + UITableView
                [self.tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
                [self updateUnreadNewsItemsBadgeCount];
            }
            
            [[segue destinationViewController] setSelectedNewsItem:selectedNewsItem];
        }
    }
}

@end
