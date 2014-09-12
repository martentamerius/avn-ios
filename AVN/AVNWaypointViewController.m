//
//  AVNWaypointViewController.m
//  AVN
//
//  Created by Marten Tamerius on 12-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNWaypointViewController.h"
#import "AVNRouteDetailViewController.h"
#import "AVNHTTPRequestFactory.h"
#import <MBProgressHUD.h>
#import <TSMessage.h>


@interface AVNWaypointViewController () <UIWebViewDelegate, CLLocationManagerDelegate>
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *previousBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *nextBarButtonItem;

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *currentLocation;
@property (nonatomic) BOOL currentLocationDetermined;
@end


@implementation AVNWaypointViewController

#pragma mark - Managing the waypoint

- (void)setSelectedWaypoint:(AVNWaypoint *)newSelectedWaypoint
{
    if (_selectedWaypoint != newSelectedWaypoint) {
        _selectedWaypoint = newSelectedWaypoint;
        
        // Update the view.
        [self configureView];
    }
}

- (void)setSelectedRouteToDetermineNearestWaypoint:(AVNRoute *)selectedRouteToDetermineNearestWaypoint
{
    if (_selectedRouteToDetermineNearestWaypoint != selectedRouteToDetermineNearestWaypoint) {
        _selectedRouteToDetermineNearestWaypoint = selectedRouteToDetermineNearestWaypoint;
        
        // Start determining the current location to find the nearest waypoint right away
        [self startLocationManager];
    }
}


- (void)configureView
{
    // Update the user interface for the detail item.
    NSString *urlString;
    
    if (self.selectedWaypoint) {
        // Assemble url with indicated waypoint as main location
        urlString = [AVNHTTPRequestFactory urlForAVNWaypoint:self.selectedWaypoint];

        BOOL previousWaypointAvailable = ([self.selectedWaypoint previousWaypoint]!=nil);
        BOOL nextWaypointAvailable = ([self.selectedWaypoint nextWaypoint]!=nil);
        
        self.previousBarButtonItem.enabled = previousWaypointAvailable;
        self.nextBarButtonItem.enabled = nextWaypointAvailable;
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


#pragma mark - Previous, nearest and next buttons

- (IBAction)previousWaypointTapped:(UIBarButtonItem *)sender
{
    if (self.selectedWaypoint) {
        AVNWaypoint *previousWaypoint = [self.selectedWaypoint previousWaypoint];
        if (previousWaypoint) {
            self.selectedWaypoint = previousWaypoint;
            [self configureView];
        }
    } else {
        NSString *urlString = [NSString stringWithFormat:@"%@&wp=previous", [self.webView.request.URL absoluteString]];
        NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
        [self.webView loadRequest:urlRequest];
    }
}

- (IBAction)nextWaypointTapped:(UIBarButtonItem *)sender
{
    if (self.selectedWaypoint) {
        AVNWaypoint *nextWaypoint = [self.selectedWaypoint nextWaypoint];
        if (nextWaypoint) {
            self.selectedWaypoint = nextWaypoint;
            [self configureView];
        }
    } else {
        NSString *urlString = [NSString stringWithFormat:@"%@&wp=next", [self.webView.request.URL absoluteString]];
        NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
        [self.webView loadRequest:urlRequest];
    }
}

- (IBAction)findNearestWaypointTapped:(id)sender
{
    // Find nearest waypoint
    [self startLocationManager];
}


#pragma mark - CoreLocation

- (void)startLocationManager
{
    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    }
    
    [self.locationManager startUpdatingLocation];
    
    // Give user some visual feedback
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.currentLocationDetermined = NO;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    DLog(@"LocationManager failed with error %@, %@", [error localizedDescription], [error userInfo]);
    
    self.currentLocationDetermined = NO;
    
    // Stop location manager
    [self.locationManager stopUpdatingLocation];
    
    // Dismiss notification
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [TSMessage showNotificationInViewController:self title:@"Let op: de huidige locatie kan niet worden bepaald." subtitle:@"Het startpunt van de route zal worden geladen." type:TSMessageNotificationTypeWarning duration:3.0 canBeDismissedByUser:YES];
    
    // Show the first waypoint programmatically after 2 seconds
    __weak AVNWaypointViewController *weakSelf = self;
    AVNWaypoint *firstWaypoint;
    if (self.selectedWaypoint) {
        firstWaypoint = [self.selectedWaypoint firstWaypoint];
    } else if (self.selectedRouteToDetermineNearestWaypoint) {
        firstWaypoint = [self.selectedRouteToDetermineNearestWaypoint firstWaypoint];
    }
    if (firstWaypoint) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            weakSelf.selectedWaypoint = firstWaypoint;
        });
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    // Retrieve the last known location from the locations array
    CLLocation *currentLocation = [locations lastObject];
    
    DLog(@"New location update: %@", currentLocation);
    
    // Wait until the accuracy of the returned locations is within 100 meters
    if ((currentLocation.horizontalAccuracy>=0) && (currentLocation.horizontalAccuracy<100)) {
        
        // Dismiss notification
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        
        // Stop the location manager updates
        [self.locationManager stopUpdatingLocation];
        
        // Remember the last location update
        self.currentLocation = currentLocation;
        
        if (!self.currentLocationDetermined) {
            self.currentLocationDetermined = YES;
            
            // Try to get the nearest waypoint
            __block AVNWaypoint *nearestWaypoint = nil;
            __block CLLocationDistance distanceToNearest = 1000000000000;
            AVNRoute *parentRoute = self.selectedWaypoint?self.selectedWaypoint.parentRoute:self.selectedRouteToDetermineNearestWaypoint;
            
            // Calculate distance to all waypoints and remember nearest
            if (parentRoute && parentRoute.waypoints && ([parentRoute.waypoints count]>0) && self.currentLocation) {
                
                [parentRoute.waypoints enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    AVNWaypoint *wp = (AVNWaypoint *)obj;
                    CLLocationDistance wpDistance = [wp.gpsCoordinate distanceFromLocation:self.currentLocation];
                    if (wpDistance<distanceToNearest) {
                        // Current waypoint is nearer than the last one
                        nearestWaypoint = wp;
                        distanceToNearest = wpDistance;
                    }
                }];
                
                // If the nearest waypoint has not been found, just select the first one available
                nearestWaypoint = nearestWaypoint?:parentRoute.waypoints[0];
            }
            
            if (nearestWaypoint)
                self.selectedWaypoint = nearestWaypoint;
        }
    }
}


#pragma mark - UIWebView delegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if ([[MBProgressHUD allHUDsForView:self.view] count]==0)
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    // Sometimes error code -999 pops up. This is a "NSURLErrorCancelled".
    // Triggered for example by double-clicking a link. Just ignore this error.
    if (error.code != -999) {

        // Dismiss HUD
        [MBProgressHUD hideHUDForView:self.view animated:YES];

        // Log error
        DLog(@"Error downloading AVN Waypoint page: %@, %@", [error localizedDescription], [error userInfo]);
        
        // Show error message to user
        [TSMessage showNotificationInViewController:self title:@"Laden van pagina mislukt."
                                           subtitle:[error localizedDescription]
                                               type:TSMessageNotificationTypeError
                                           duration:5
                               canBeDismissedByUser:YES];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    // The webview wants to load a URL.
    // Determine if this action should be allowed, or if we should handle it with another view controller.
    BOOL shouldStart = NO;
    
    switch (navigationType) {
        case UIWebViewNavigationTypeLinkClicked:
        case UIWebViewNavigationTypeReload:
        case UIWebViewNavigationTypeOther:
        {
            NSString *hostname = request.URL.host;
            if (hostname) {
                if ([hostname isEqualToString:kGoogleMapsHostname]) {
                    
                    // Allow requests directed at Google Maps
                    shouldStart = YES;
                    
                } else if ([hostname isEqualToString:kAVNHostname]) {
                    
                    shouldStart = YES;
                    
                }
            }
            break;
        }
        default:
            break;
    }
    
    return shouldStart;
}


@end
