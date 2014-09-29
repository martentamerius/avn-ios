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
@property (nonatomic, strong) ODRefreshControl *newsItemsListRefreshControl;
@property (nonatomic, strong) AVNNewsItem *newsItemToPush;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *allReadButton;
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
    
    // Enable/disable all-read-button
    if (self.allReadButton)
        self.allReadButton.enabled = (self.newsItemsList && ([self.newsItemsList count]>0));
    
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Populate news items list

- (void)setNewsItemsList:(NSMutableArray *)newsItemsList
{
    if (newsItemsList != _newsItemsList) {
        [self willChangeValueForKey:@"newsItemList"];
        _newsItemsList = newsItemsList;
        [self didChangeValueForKey:@"newsItemList"];
        
        if (self.allReadButton)
            self.allReadButton.enabled = (newsItemsList && ([newsItemsList count]>0));
    }
}

- (void)requestNewsItemsList:(NSNotification *)notification
{
    // Give some visual feedback when the refreshing has been started programmatically
    if (!notification)
        [self.newsItemsListRefreshControl beginRefreshing];
    
    __weak AVNNewsTableViewController *weakSelf = self;
    AVNAppDelegate *appDelegate = (AVNAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate refreshNewsItemListForController:self withCompletionHandler:^(){
        [weakSelf.tableView reloadData];
        [weakSelf.newsItemsListRefreshControl endRefreshing];
        
        if (appDelegate.backgroundFetchError) {
            // Show error message to user
            [TSMessage showNotificationInViewController:weakSelf title:@"Laden van pagina mislukt." subtitle:[appDelegate.backgroundFetchError localizedDescription] type:TSMessageNotificationTypeError duration:5 canBeDismissedByUser:YES];
        }
    }];
}

- (IBAction)markAllAsRead:(id)sender
{
    if (self.newsItemsList) {
        __block NSMutableArray *newReadItems = [NSMutableArray array];

        [self.newsItemsList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            AVNNewsItem *currentItem = (AVNNewsItem *)obj;
            currentItem.hasReadItem = YES;
            
            [newReadItems addObject:currentItem.identifier];
        }];
        
        // Save the new array into the UserDefaults for next time
        [[NSUserDefaults standardUserDefaults] setObject:newReadItems forKey:kAVNSetting_ReadNewsItems];
        [[NSUserDefaults standardUserDefaults] setObject:newReadItems forKey:kAVNSetting_DownloadedNewsItems];
        [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kAVNSetting_TimestampForLastNewsDownload];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // Update table view UI
        [self.tableView reloadData];

        // Update badge counts
        AVNRootViewController *rootVC = (AVNRootViewController *)self.tabBarController;
        [rootVC updateNewsItemBadge:0];
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


#pragma mark - Navigation

- (void)pushNewsItemWithIdentifier:(NSString *)identifier
{
    // Get a fresh copy of the news items list from the server...
    __weak typeof(self) weakSelf = self;
    AVNAppDelegate *appDelegate = (AVNAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate refreshNewsItemListForController:self withCompletionHandler:^{
        __block AVNNewsItem *newsItem;
        
        if (weakSelf.newsItemsList) {
            [weakSelf.newsItemsList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                AVNNewsItem *currentItem = (AVNNewsItem *)obj;
                if ([currentItem.identifier isEqualToString:identifier]) {
                    newsItem = currentItem;
                    *stop = YES;
                }
            }];
        }
        
        if (newsItem) {
            weakSelf.newsItemToPush = newsItem;
            [weakSelf performSegueWithIdentifier:kSegueNewsItemListPushNotAnimated sender:weakSelf];
        }
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if (self.newsItemsList &&
        ([[segue identifier] isEqualToString:kSegueNewsItemListToShowDetail] ||
        [[segue identifier] isEqualToString:kSegueNewsItemListPushNotAnimated])) {
        
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
            if (indexPath)
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
                
                // Refresh UITableView
                if (indexPath)
                    [self.tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
                
                // Update badge count in tab bar and on application icon
                __block NSInteger unreadItemsCount = 0;
                [self.newsItemsList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if (!((AVNNewsItem *)obj).hasReadItem)
                        unreadItemsCount++;
                }];
                AVNRootViewController *rootVC = (AVNRootViewController *)self.tabBarController;
                [rootVC updateNewsItemBadge:unreadItemsCount];
            }
            
            [[segue destinationViewController] setSelectedNewsItem:selectedNewsItem];
        }
    }
}

@end
