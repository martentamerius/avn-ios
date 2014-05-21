//
//  AVNRootViewController.m
//  AVN
//
//  Created by Marten Tamerius on 22-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNRootViewController.h"

#define kDefaultAnimationDuration   0.5

@implementation AVNRootViewController

- (void)viewWillAppear:(BOOL)animated
{
    // Set selected tabbar item tint color... this does not seem to work properly from storyboard editor
    UIColor *defaultAVNAppTintColor = [UIColor colorWithRed:(231.0f/255) green:(180.0f/255) blue:(43.0f/255) alpha:1.0f];
    
    //[UIColor colorWithRed:(195.0f/255) green:(162.0f/255) blue:(27.0f/255) alpha:1.0f];
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        // Load resources for iOS 6.1 or earlier
        
        //[[UINavigationBar appearance] setTitleTextAttributes:@{ UITextAttributeTextColor: defaultAVNAppTintColor }];
    } else {
        // Load resources for iOS 7 or later
        
        // Set default tint color
        [[UIView appearance] setTintColor:defaultAVNAppTintColor];
    }
    
    // Set UITabBar selected image tint color for all iOS versions
    [[UITabBar appearance] setSelectedImageTintColor:defaultAVNAppTintColor];

    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    // Don't forget to unregister for all notifications!
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
