//
//  AVNDownloadListViewController.m
//  AVN
//
//  Created by Marten Tamerius on 22-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNDownloadListViewController.h"
#import "AVNRouteDetailViewController.h"
#import "AVNRoute.h"
#import <Mantle.h>


// Storyboard constants
#define kSegueDownloadListToShowDetail  @"DownloadListToShowDetailSegue"
#define kCellRouteDescription           @"CellRouteDescription"


@interface AVNDownloadListViewController ()
@property (nonatomic, strong) NSMutableArray *downloadList;
@end

@implementation AVNDownloadListViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Populate route list
    [self requestDownloadList];
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


#pragma mark - Populate download list

- (void)requestDownloadList
{
    self.downloadList = [NSMutableArray array];
    
    // Refresh UI on main thread
    __weak AVNDownloadListViewController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.tableView reloadData];
    });
}


#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.downloadList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellRouteDescription forIndexPath:indexPath];
    
    AVNRoute *route = self.downloadList[indexPath.row];
    cell.textLabel.text = route.title;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:kSegueDownloadListToShowDetail]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        [[segue destinationViewController] setSelectedRoute:self.downloadList[indexPath.row]];
    }
}

@end
