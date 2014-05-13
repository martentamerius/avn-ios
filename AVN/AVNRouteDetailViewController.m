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
#import "SVProgressHUD.h"
#import "TSMessage.h"


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
        NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:urlGetMain];
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


#pragma mark - UIWebView delegate

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
            if (path && ([path length]>[self.selectedRoute.identifier length]+2)) {
                
                NSString *routeIdFromPath = [path substringWithRange:NSMakeRange(1, [self.selectedRoute.identifier length])];
                if ([routeIdFromPath isEqualToString:self.selectedRoute.identifier]) {
                    NSArray *pathComponents = [path componentsSeparatedByString:@"_"];
                    if ([pathComponents count] > 1) {
                        // User tapped a link to a specific waypoint! Extract the waypoint details.
                        self.tappedWaypoint = [[AVNWaypoint alloc] init];
                        self.tappedWaypoint.identifier = [pathComponents lastObject];
                        self.tappedWaypoint.parentRoute = self.selectedRoute;
                        
                        // Don't start the current request; we will manually push a segue to
                        // the waypoint view controller, which will be populated with the tapped waypoint
                        [self performSegueWithIdentifier:kSegueSpecificWaypointTapped sender:self];
                    }
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
    [SVProgressHUD showWithStatus:@"Locatie bepalen..." maskType:SVProgressHUDMaskTypeBlack];
    self.currentLocationDetermined = NO;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"LocationManager failed with error %@, %@", [error localizedDescription], [error userInfo]);
    
    self.currentLocationDetermined = NO;

    // Dismiss notification
    [SVProgressHUD showErrorWithStatus:@""];
    [TSMessage showNotificationInViewController:self title:@"Let op: de huidige locatie kan niet worden bepaald." subtitle:@"Het startpunt zal nu worden getoond" type:TSMessageNotificationTypeWarning duration:3.0 canBeDismissedByUser:YES];
    
    // Start the segue to the starting waypoint viewcontroller programmatically
    [self performSegueWithIdentifier:kSegueStartRoute sender:self];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    // Retrieve the last known location from the locations array
    CLLocation *currentLocation = [locations lastObject];
    
    NSLog(@"New location update: %@", currentLocation);
    
    // Wait until the accuracy of the returned locations is within 100 meters
    if ((currentLocation.horizontalAccuracy>=0) && (currentLocation.horizontalAccuracy<100)) {
        
        // Dismiss notification
        [SVProgressHUD showSuccessWithStatus:@"Locatie gevonden"];

        // Stop the location manager updates
        [self.locationManager stopUpdatingLocation];
        
        // Remember the last location update
        self.currentLocation = currentLocation;

        if (!self.currentLocationDetermined) {
            // Start the segue to the waypoint viewcontroller programmatically
            [self performSegueWithIdentifier:kSegueFindNearestWaypoint sender:self];
            self.currentLocationDetermined = YES;
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
        
        [[segue destinationViewController] setSelectedRoute:self.selectedRoute];
        
    } else if ([[segue identifier] isEqualToString:kSegueFindNearestWaypoint]) {
        
        if (self.currentLocation) {
            [[segue destinationViewController] setCurrentLocation:self.currentLocation];
        }
        [[segue destinationViewController] setSelectedRoute:self.selectedRoute];
        
    } else if ([[segue identifier] isEqualToString:kSegueSpecificWaypointTapped]) {
        
        if (self.tappedWaypoint) {
            [[segue destinationViewController] setSelectedWaypoint:self.tappedWaypoint];
            self.tappedWaypoint = nil;
        }
        
    }
}


@end
