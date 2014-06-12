//
//  AVNRouteListViewController.m
//  AVN
//
//  Created by Marten Tamerius on 09-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNRouteListViewController.h"
#import "AVNRootViewController.h"
#import "AVNRouteDetailViewController.h"
#import "AVNRoute.h"
#import "AVNWaypoint.h"
#import "AVNHTTPRequestFactory.h"
#import <AFNetworking.h>
#import <Mantle.h>
#import <TSMessage.h>
#import <ODRefreshControl.h>


@interface AVNRouteListViewController ()
@property (nonatomic, strong) NSMutableArray *routeList;
@property (nonatomic, strong) ODRefreshControl *routeListRefreshControl;
@end

@implementation AVNRouteListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Add custom refresh control
    ODRefreshControl *refreshControl = [[ODRefreshControl alloc] initInScrollView:self.tableView];
    [refreshControl addTarget:self action:@selector(requestRouteList:) forControlEvents:UIControlEventValueChanged];
    self.routeListRefreshControl = refreshControl;
    [self.tableView setContentOffset:CGPointMake(0.0, (-1*refreshControl.frame.size.height)) animated:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Populate route list
    if ((!self.routeList) || ([self.routeList count]==0))
        [self requestRouteList:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Populate route list

- (void)requestRouteList:(NSNotification *)notification
{   
    // Request header should have a field with content-type: "appliction/json"
    NSString *contentType = [NSString stringWithFormat:@"application/json; charset=%@", (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))];
    
    // Init request manager (with JSON serializer) and URL request object
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFHTTPRequestSerializer new];
    manager.requestSerializer.timeoutInterval = 8;
    if ([manager.reachabilityManager networkReachabilityStatus]==AFNetworkReachabilityStatusNotReachable) {
        manager.requestSerializer.cachePolicy = NSURLRequestReturnCacheDataDontLoad;
    } else {
        manager.requestSerializer.cachePolicy = NSURLRequestUseProtocolCachePolicy;
    }
    manager.responseSerializer = [AFJSONResponseSerializer new];
    [manager.requestSerializer setValue:contentType forHTTPHeaderField:@"Content-Type"];

    // Give some visual feedback when the refreshing has been started programmatically
    if (!notification)
        [self.routeListRefreshControl beginRefreshing];
    
    // Init actual HTTP request operation
    __weak AVNRouteListViewController *weakSelf = self;
    [manager GET:[AVNHTTPRequestFactory urlForAVNRouteInfo] parameters:nil
         success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        // Process the received response with Mantle
        NSError *error = nil;
        NSArray *jsonResponseArray = ([responseObject isKindOfClass:[NSArray class]])?(NSArray *)responseObject:[NSArray arrayWithObject:responseObject];
        
        NSMutableArray *routeListFromServer = [NSMutableArray arrayWithCapacity:[jsonResponseArray count]];
        for (id jsonObject in jsonResponseArray) {
            AVNRoute *route = [MTLJSONAdapter modelOfClass:[AVNRoute class] fromJSONDictionary:jsonObject error:&error];
            if (!route) {
                DLog(@"Error converting AVN JSON route info: %@, %@", [error localizedDescription], [error userInfo]);
            } else {
                
                // Also set the parentRoute for all waypoints in the current route
                [route.waypoints enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    AVNWaypoint *waypoint = (AVNWaypoint *)obj;
                    waypoint.parentRoute = route;
                }];
                
                [routeListFromServer addObject:route];
            }
        }
        
        if (routeListFromServer && weakSelf) {
            // Save the converted AVN route list
            weakSelf.routeList = routeListFromServer;
            
            // Refresh UI on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView reloadData];
                [weakSelf.routeListRefreshControl endRefreshing];
            });
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DLog(@"Error downloading AVN route info: %@, %@", [error localizedDescription], [error userInfo]);
        
        // Refresh UI on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.tableView reloadData];
            [weakSelf.routeListRefreshControl endRefreshing];
            
            // Show error message to user
            [TSMessage showNotificationInViewController:weakSelf title:@"Laden van pagina mislukt." subtitle:[error localizedDescription] type:TSMessageNotificationTypeError duration:5 canBeDismissedByUser:YES];
        });
    }];
}


#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.routeList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellRouteDescription forIndexPath:indexPath];

    AVNRoute *route = self.routeList[indexPath.row];
    cell.textLabel.text = route.title;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:kSegueRouteListToRouteDetail]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

        [[segue destinationViewController] setSelectedRoute:self.routeList[indexPath.row]];
    }
}

@end
