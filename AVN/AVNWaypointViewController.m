//
//  AVNWaypointViewController.m
//  AVN
//
//  Created by Marten Tamerius on 12-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNWaypointViewController.h"
#import "AVNHTTPRequestFactory.h"
#import "AVNRoute.h"

@interface AVNWaypointViewController ()
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@end


@implementation AVNWaypointViewController

#pragma mark - Managing the waypoint

- (void)setCurrentLocation:(CLLocation *)newCurrentLocation
{
    if (_currentLocation != newCurrentLocation) {
        _currentLocation = newCurrentLocation;
        
        // Update the view.
        [self configureView];
    }
}

- (void)setSelectedRoute:(AVNRoute *)newSelectedRoute
{
    if (_selectedRoute != newSelectedRoute) {
        _selectedRoute = newSelectedRoute;
        
        // Update the view.
        [self configureView];
    }
}

- (void)setSelectedWaypoint:(AVNWaypoint *)newSelectedWaypoint
{
    if (_selectedWaypoint != newSelectedWaypoint) {
        _selectedWaypoint = newSelectedWaypoint;
        
        // Update the view.
        [self configureView];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.
    NSString *urlString;
    
    if (self.selectedWaypoint) {
        
        // Assemble url with indicated waypoint as main location
        urlString = [AVNHTTPRequestFactory urlForAVNWaypoint:self.selectedWaypoint];
        
    } else if (self.currentLocation) {
        
        // Assemble url with current long/lat coordinate
        NSString *urlGetNearestWaypointWithoutLocation = [AVNHTTPRequestFactory urlForAVNRoute:self.selectedRoute forAction:AVNAction_GetNearest];
        urlString = [NSString stringWithFormat:@"%@%.6f,%.6f", urlGetNearestWaypointWithoutLocation, self.currentLocation.coordinate.latitude, self.currentLocation.coordinate.longitude];

    } else if (self.selectedRoute) {
        
        // Assemble url with first waypoint as starting point
        urlString = [AVNHTTPRequestFactory urlForAVNRoute:self.selectedRoute forAction:AVNAction_GetStart];

    }
    
    if (urlString) {
        NSURL *url = [NSURL URLWithString:urlString];
        NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:url];
        [self.webView loadRequest:urlRequest];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self configureView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Previous and next buttons

- (IBAction)previousWaypointTapped:(UIBarButtonItem *)sender
{
    NSString *urlString = [NSString stringWithFormat:@"%@&wp=previous", [self.webView.request.URL absoluteString]];
    NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    [self.webView loadRequest:urlRequest];
}

- (IBAction)nextWaypointTapped:(id)sender
{
    NSString *urlString = [NSString stringWithFormat:@"%@&wp=next", [self.webView.request.URL absoluteString]];
    NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    [self.webView loadRequest:urlRequest];
}

@end
