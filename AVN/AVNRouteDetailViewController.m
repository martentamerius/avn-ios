//
//  AVNRouteDetailViewController.m
//  AVN
//
//  Created by Marten Tamerius on 09-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNRouteDetailViewController.h"
#import "AVNWaypointViewController.h"
#import "AVNHTTPRequestFactory.h"
#import "AVNWaypoint.h"
#import <CoreLocation/CoreLocation.h>
#import <MBProgressHUD.h>
#import <TSMessage.h>


// Segue identifiers
#define kSegueStartRoute                @"StartRouteSegue"
#define kSegueFindNearestWaypoint       @"FindNearestWaypointSegue"
#define kSegueSpecificWaypointTapped    @"SpecificWaypointTappedSegue"


@interface AVNRouteDetailViewController () <CLLocationManagerDelegate, UIWebViewDelegate>
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *currentLocation;
@property (nonatomic) BOOL currentLocationDetermined;
@property (strong, nonatomic) AVNWaypoint *tappedWaypoint;
@property (strong, nonatomic) AVNWaypoint *nearestWaypoint;
@end

@implementation AVNRouteDetailViewController

#pragma mark - Managing the selected route

- (void)setSelectedRoute:(AVNRoute *)newSelectedRoute
{
    if (_selectedRoute != newSelectedRoute) {
        _selectedRoute = newSelectedRoute;
        
        // Update the view.
        [self configureView];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.
    if (self.selectedRoute) {
        NSURL *urlGetMain = [NSURL URLWithString:[AVNHTTPRequestFactory urlForAVNRoute:self.selectedRoute forAction:AVNAction_GetMain]];
        NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:urlGetMain];
        urlRequest.cachePolicy = NSURLRequestReloadRevalidatingCacheData;

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


#pragma mark - Download Route button

- (IBAction)downloadRoute:(id)sender
{
    // TODO: All pages should be downloaded here
    NSLog(@"Download route button clicked for AVNRoute with id %@.", self.selectedRoute.identifier);
    
    NSString *html = [self.webView stringByEvaluatingJavaScriptFromString:@"document.documentElement.outerHTML"];
    NSLog(@"HTML content: %@", html);
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
        NSLog(@"Error downloading AVN route detail page: %@, %@", [error localizedDescription], [error userInfo]);
        
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
        {
            // The user tapped on a link.
            NSString *path = request.URL.path;
            if (path && ([path length]>1)) {
                NSString *waypointIdFromPath = [path substringWithRange:NSMakeRange(1, [path length]-1)];
                __block AVNWaypoint *tappedWaypoint;
                [self.selectedRoute.waypoints enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    AVNWaypoint *currentWaypoint = (AVNWaypoint *)obj;
                    if ([currentWaypoint.identifier isEqualToString:waypointIdFromPath]) {
                        tappedWaypoint = currentWaypoint;
                        *stop = YES;
                    }
                }];
                
                if (tappedWaypoint) {
                    self.tappedWaypoint = tappedWaypoint;
                    
                    // Don't start the current request; we will manually push a segue to
                    // the waypoint view controller, which will be populated with the tapped waypoint
                    [self performSegueWithIdentifier:kSegueSpecificWaypointTapped sender:self];
                }
                
            }
            break;
        }
        case UIWebViewNavigationTypeReload:
        case UIWebViewNavigationTypeOther:
        {
            NSString *hostname = request.URL.host;
            if (hostname) {
                if ([hostname isEqualToString:kGoogleMapsHostname]) {
                    
                    // Allow requests directed at Google Maps
                    shouldStart = YES;
                    
                } else if ([hostname isEqualToString:kAVNHostname]) {
                    
                    NSString *queryPart = [request.URL query];
                    if (queryPart && ([queryPart length]>7)) {
                        
                        // Allow requests directed at AVN webserver only when  the current request is intended
                        // to load the main route webpage (other requests should be intercepted and handled manually).
                        NSString *wpQuery = [queryPart substringFromIndex:([queryPart length]-7)];
                        if ([wpQuery isEqualToString:@"wp=main"]) {
                            shouldStart = YES;
                        }
                    }
                    
                }
            }
            break;
        }
        default:
            break;
    }
    
    return shouldStart;
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
    NSLog(@"LocationManager failed with error %@, %@", [error localizedDescription], [error userInfo]);
    
    self.currentLocationDetermined = NO;

    // Dismiss notification
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [TSMessage showNotificationInViewController:self title:@"Let op: de huidige locatie kan niet worden bepaald." subtitle:@"Het startpunt van de route zal worden geladen." type:TSMessageNotificationTypeWarning duration:3.0 canBeDismissedByUser:YES];
    
    // Start the segue to the starting waypoint viewcontroller programmatically after 2 seconds
    __weak AVNRouteDetailViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf performSegueWithIdentifier:kSegueStartRoute sender:weakSelf];
    });
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    // Retrieve the last known location from the locations array
    CLLocation *currentLocation = [locations lastObject];
    
    NSLog(@"New location update: %@", currentLocation);
    
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

            // Start the segue to the waypoint viewcontroller programmatically
            [self performSegueWithIdentifier:kSegueFindNearestWaypoint sender:self];
        }
    }
}


#pragma mark - Navigation

- (IBAction)findNearestWaypointTapped:(UIBarButtonItem *)sender
{
    [self startLocationManager];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:kSegueStartRoute]) {
        // Try to get indicated start waypoint
        __block AVNWaypoint *startWaypoint = nil;
        if (self.selectedRoute && self.selectedRoute.waypoints &&
            ([self.selectedRoute.waypoints count]>0) && (self.selectedRoute.startWaypoint)) {
            
            NSString *startID = self.selectedRoute.startWaypoint;
            [self.selectedRoute.waypoints enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                AVNWaypoint *wp = (AVNWaypoint *)obj;
                if ([wp.identifier isEqualToString:startID]) {
                    startWaypoint = wp;
                    *stop = YES;
                }
            }];
            
            // If the start waypoint has not been found, just select the first one available
            startWaypoint = startWaypoint?:self.selectedRoute.waypoints[0];
        }
        
        if (startWaypoint)
            [[segue destinationViewController] setSelectedWaypoint:startWaypoint];
        
    } else if ([[segue identifier] isEqualToString:kSegueFindNearestWaypoint]) {
        
        // Try to get the nearest waypoint
        __block AVNWaypoint *nearestWaypoint = nil;
        __block CLLocationDistance distanceToNearest = 1000000000000;
        
        // Calculate distance to all waypoints and remember nearest
        if (self.selectedRoute && self.selectedRoute.waypoints &&
            ([self.selectedRoute.waypoints count]>0) && self.currentLocation) {
            
            [self.selectedRoute.waypoints enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                AVNWaypoint *wp = (AVNWaypoint *)obj;
                CLLocationDistance wpDistance = [wp.gpsCoordinate distanceFromLocation:self.currentLocation];
                if (wpDistance<distanceToNearest) {
                    // Current waypoint is nearer than the last one
                    nearestWaypoint = wp;
                    distanceToNearest = wpDistance;
                }
            }];
            
            // If the nearest waypoint has not been found, just select the first one available
            nearestWaypoint = nearestWaypoint?:self.selectedRoute.waypoints[0];
        }
        
        if (nearestWaypoint)
            [[segue destinationViewController] setSelectedWaypoint:nearestWaypoint];

        
    } else if ([[segue identifier] isEqualToString:kSegueSpecificWaypointTapped]) {
        
        if (self.tappedWaypoint) {
            // The link to a specific waypoint has been tapped
            [[segue destinationViewController] setSelectedWaypoint:self.tappedWaypoint];
            self.tappedWaypoint = nil;
        }
        
    }
}


@end
