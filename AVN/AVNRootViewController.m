//
//  AVNRootViewController.m
//  AVN
//
//  Created by Marten Tamerius on 22-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNRootViewController.h"

#define kDefaultAnimationDuration   0.5

@interface AVNRootViewController ()
@end

@implementation AVNRootViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {


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
    // Set selected tabbar item tint color... this does not seem to work properly from storyboard editor
    UIColor *defaultAVNAppTintColor = [UIColor colorWithRed:(195.0f/255) green:(162.0f/255) blue:(27.0f/255) alpha:1.0f];
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
