//
//  AVNRouteDetailViewController.m
//  AVN
//
//  Created by Marten Tamerius on 09-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNRouteDetailViewController.h"
#import "AVNWaypointViewController.h"
#import "AVNAppDelegate.h"
#import "AVNHTTPRequestFactory.h"
#import "AVNWaypoint.h"
#import <CoreLocation/CoreLocation.h>
#import <MBProgressHUD.h>
#import <TSMessage.h>


@interface AVNRouteDetailViewController () <UIWebViewDelegate>
@property (weak, nonatomic) IBOutlet UIWebView *webView;
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
    DLog(@"Download route button clicked for AVNRoute with id %@.", self.selectedRoute.identifier);
    
#ifdef DEBUG
    NSString *html = [self.webView stringByEvaluatingJavaScriptFromString:@"document.documentElement.outerHTML"];
    DLog(@"HTML content: %@", html);
#endif
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
        DLog(@"Error downloading AVN route detail page: %@, %@", [error localizedDescription], [error userInfo]);
        
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
                    [self performSegueWithIdentifier:kSegueRouteDetailSpecificWaypointTapped sender:self];
                }
                
            }
            break;
        }
        case UIWebViewNavigationTypeReload:
        case UIWebViewNavigationTypeOther:
        {
            NSString *hostname = request.URL.host;
            if (hostname) {
                if ([hostname isEqualToString:kAVNHostname]) {
                    
                    NSString *queryPart = [request.URL query];
                    if (queryPart && ([queryPart length]>7)) {
                        
                        // Allow requests directed at AVN webserver only when  the current request is intended
                        // to load the main route webpage (other requests should be intercepted and handled manually).
                        NSString *wpQuery = [queryPart substringFromIndex:([queryPart length]-7)];
                        if ([wpQuery isEqualToString:@"wp=main"]) {
                            shouldStart = YES;
                        }
                    }
                    
                } else {
                    
                    // Redirect user to external app for external links
                    AVNAppDelegate *appDelegate = (AVNAppDelegate *)[[UIApplication sharedApplication] delegate];
                    [appDelegate openExternalURL:request.URL];
                    
                }
            }
            break;
        }
        default:
            break;
    }
    
    return shouldStart;
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:kSegueRouteDetailToStartRouteAtFirstWaypoint]) {
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
        
    } else if ([[segue identifier] isEqualToString:kSegueRouteDetailToFindNearestWaypoint]) {
        
        if (self.selectedRoute) {
            // Set the currently selected route to find nearest waypoint
            [[segue destinationViewController] setSelectedRouteToDetermineNearestWaypoint:self.selectedRoute];
            [[segue destinationViewController] setSelectedWaypoint:nil];
        }
        
    } else if ([[segue identifier] isEqualToString:kSegueRouteDetailToMapView]) {
        
        if (self.selectedRoute && self.selectedRoute.kmzDownloadURL) {
            // Set the currently selected route to set map view
            [[segue destinationViewController] setSelectedRoute:self.selectedRoute];
        }
        
    } else if ([[segue identifier] isEqualToString:kSegueRouteDetailSpecificWaypointTapped]) {
        
        if (self.tappedWaypoint) {
            // The link to a specific waypoint has been tapped
            [[segue destinationViewController] setSelectedWaypoint:self.tappedWaypoint];
            self.tappedWaypoint = nil;
        }
        
    }
}


@end
