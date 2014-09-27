//
//  AVNRootViewController.m
//  AVN
//
//  Created by Marten Tamerius on 22-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNRootViewController.h"
#import "AVNAppDelegate.h"

#define kNewsItemTabBarIndex        1
#define kDefaultAnimationDuration   0.5

@implementation AVNRootViewController

- (void)viewWillAppear:(BOOL)animated
{
    // Application-wide tint color (the yellow background from the AVN logo.)
    UIColor *defaultAVNAppTintColor = [UIColor colorWithRed:(231.0f/255) green:(180.0f/255) blue:(43.0f/255) alpha:1.0f];
    
    // Set UITabBar selected image tint color independent of iOS version;
    // this does not seem to work propertly from storyboard editor.
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


#pragma mark - Badge count for News Items tab bar item

- (void)updateNewsItemBadge:(NSInteger)unreadItemCount
{
    UITabBarItem *newsTabBarItem;
    
    // Save the new specified value into the UserDefaults
    [[NSUserDefaults standardUserDefaults] setInteger:unreadItemCount forKey:kAVNSetting_UnreadNewsItemsCount];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Set the application's badge to include the unread news items count
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:unreadItemCount];
    
    if ([self.tabBar.items count]>=kNewsItemTabBarIndex) {
        newsTabBarItem = self.tabBar.items[kNewsItemTabBarIndex];
        newsTabBarItem.badgeValue = (unreadItemCount<=0)?nil:[NSString stringWithFormat:@"%ld", (long)unreadItemCount];
    } else {
        DLog(@"Error: could not find the news tab bar index to update the badge count!");
    }
}

@end
