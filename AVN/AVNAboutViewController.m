//
//  AVNAboutViewController.m
//  AVN
//
//  Created by Marten Tamerius on 24-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNAboutViewController.h"
#import "AVNAppDelegate.h"
#import "AVNHTTPRequestFactory.h"
#import <MBProgressHUD.h>
#import <TSMessage.h>

@interface AVNAboutViewController () <UIWebViewDelegate>
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic) BOOL didLoadPage;
@property (nonatomic) BOOL didLoadLocalContent;
@end

@implementation AVNAboutViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.didLoadPage = NO;
    self.didLoadLocalContent = NO;
    
    [self refreshContent];
}

- (void)viewWillAppear:(BOOL)animated
{
    if (!self.didLoadPage)
        [self refreshContent];
    
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Refresh content

- (void)refreshContent
{
    // Refresh webview content
    NSURL *urlAboutAVN = [NSURL URLWithString:[AVNHTTPRequestFactory urlForAVNPage:AVNPage_About]];
    NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:urlAboutAVN];
    [self.webView loadRequest:urlRequest];
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
        DLog(@"Error downloading AVN About page: %@, %@. Trying to load local version.", [error localizedDescription], [error userInfo]);
        
        if (!self.didLoadLocalContent) {
            // Show static local (old) version of about AVN page if it hasn't already been loaded
            NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"about_avn" ofType:@"html"];
            NSURL *localURL = [NSURL fileURLWithPath:htmlPath isDirectory:NO];
            NSURLRequest *request = [NSURLRequest requestWithURL:localURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5];
            [webView loadRequest:request];
            
            self.didLoadLocalContent = YES;
        }
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    // The webview wants to load a URL. Determine if this action should be allowed.
    BOOL shouldStart = NO;
    
    NSString *hostname = request.URL.host;
    if (hostname && [hostname isEqualToString:kAVNHostname]) {
        
        // Only allow requests directed at the AVN webserver or Google Maps
        shouldStart = YES;
        
    } else if ([request.URL.absoluteString rangeOfString:@"file:///"].location == 0) {
    
        // .. or if the request has a local URL (static HTML page on disk)
        shouldStart = YES;
        
    } else {
        
        // Redirect user to external app for external links
        AVNAppDelegate *appDelegate = (AVNAppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate openExternalURL:request.URL];
    }
    
    return shouldStart;
}
  
@end
