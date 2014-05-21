//
//  AVNNewsItemDetailViewController.m
//  AVN
//
//  Created by Marten Tamerius on 21-05-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNNewsItemDetailViewController.h"
#import "AVNHTTPRequestFactory.h"
#import <MBProgressHUD.h>
#import <TSMessage.h>

@interface AVNNewsItemDetailViewController () <UIWebViewDelegate>
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic) BOOL didLoadPage;
@end

@implementation AVNNewsItemDetailViewController

#pragma mark - Managing the selected news item

- (void)setSelectedNewsItem:(AVNNewsItem *)newSelectedNewsItem
{
    if (_selectedNewsItem != newSelectedNewsItem) {
        _selectedNewsItem = newSelectedNewsItem;
        
        // Update the view.
        [self configureView];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.
    if (self.selectedNewsItem) {
        // Set page title
        self.title = self.selectedNewsItem.title;
        
        // Refresh webview content
        NSString *newsItemString = [AVNHTTPRequestFactory urlForAVNNewsItemWithIdentifier:self.selectedNewsItem.identifier];
        NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:newsItemString]];
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

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if ([[MBProgressHUD allHUDsForView:self.view] count]==0)
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.didLoadPage = YES;
    
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
        NSLog(@"Error downloading AVN news item detail page: %@, %@", [error localizedDescription], [error userInfo]);
        
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
    // The webview wants to load a URL. Determine if this action should be allowed.
    BOOL shouldStart = NO;
    
    NSString *hostname = request.URL.host;
    if (hostname && ([hostname isEqualToString:kAVNHostname] || [hostname isEqualToString:kGoogleMapsHostname])) {
        // Only allow requests directed at the AVN webserver or Google Maps
        shouldStart = YES;
    }
    
    return shouldStart;
}

@end
