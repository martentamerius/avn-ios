//
//  AVNAboutViewController.m
//  AVN
//
//  Created by Marten Tamerius on 24-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNAboutViewController.h"
#import "AVNHTTPRequestFactory.h"

@interface AVNAboutViewController () <UIWebViewDelegate>
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@end

@implementation AVNAboutViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated
{
    // Refresh webview content
    NSURL *urlAboutAVN = [NSURL URLWithString:[AVNHTTPRequestFactory urlForAVNPage:AVNPage_About]];
    NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:urlAboutAVN];
    [self.webView loadRequest:urlRequest];

    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - UIWebView delegate

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
