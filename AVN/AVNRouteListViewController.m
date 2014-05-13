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
#import "AVNHTTPRequestFactory.h"
#import <AFNetworking.h>
#import <Mantle.h>


// Storyboard constants
#define kSegueRouteListToShowDetail @"RouteListToShowDetailSegue"
#define kCellRouteDescription       @"CellRouteDescription"


@interface AVNRouteListViewController ()
@property (nonatomic, strong) NSMutableArray *routeList;
@end

@implementation AVNRouteListViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Populate route list
    [self requestRouteList];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Populate route list

- (void)requestRouteList
{
    // Request header should have a field with content-type: "appliction/json"
    NSString *contentType = [NSString stringWithFormat:@"application/json; charset=%@", (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))];
    
    // Init request manager (with JSON serializeR) and URL request object
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFHTTPRequestSerializer new];
    manager.responseSerializer = [AFJSONResponseSerializer new];
    [manager.requestSerializer setValue:contentType forHTTPHeaderField:@"Content-Type"];
    
    // Init actual HTTP request operation
    __weak AVNRouteListViewController *weakSelf = self;
    [manager GET:[AVNHTTPRequestFactory urlForAVNRouteInfo] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        // Process the received response with Mantle
        NSError *error = nil;
        NSArray *jsonResponseArray = ([responseObject isKindOfClass:[NSArray class]])?(NSArray *)responseObject:[NSArray arrayWithObject:responseObject];
        
        NSMutableArray *routeListFromServer = [NSMutableArray arrayWithCapacity:[jsonResponseArray count]];
        for (id jsonObject in jsonResponseArray) {
            AVNRoute *route = [MTLJSONAdapter modelOfClass:[AVNRoute class] fromJSONDictionary:jsonObject error:&error];
            if (!route) {
                NSLog(@"Error converting AVN JSON route info: %@, %@", [error localizedDescription], [error userInfo]);
            } else {
                [routeListFromServer addObject:route];
            }
        }
        
        if (routeListFromServer && weakSelf) {
            // Save the converted AVN route list
            weakSelf.routeList = routeListFromServer;
            
            // Refresh UI on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView reloadData];
            });
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error downloading AVN route info: %@, %@", [error localizedDescription], [error userInfo]);
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
    if ([[segue identifier] isEqualToString:kSegueRouteListToShowDetail]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        [[segue destinationViewController] setSelectedRoute:self.routeList[indexPath.row]];
    }
}

@end
