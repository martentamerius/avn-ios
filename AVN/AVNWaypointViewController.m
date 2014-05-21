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
#import <MBProgressHUD.h>
#import <TSMessage.h>


@interface AVNWaypointViewController () <UIWebViewDelegate>
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *previousBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *nextBarButtonItem;
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


#pragma mark - Previous and next buttons

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
        NSLog(@"Error downloading AVN Waypoint page: %@, %@", [error localizedDescription], [error userInfo]);
        
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
