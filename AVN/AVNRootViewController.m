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

    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        // Load resources for iOS 6.1 or earlier
        
    } else {
        // Load resources for iOS 7 or later
        
        // Set default tint color for some control types
        [[UIToolbar appearance] setTintColor:defaultAVNAppTintColor];
        [[UINavigationBar appearance] setTintColor:defaultAVNAppTintColor];
    }
    
    // Check if the disk cache should be cleared before starting the app
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kAVNSetting_ResetCache]) {
        DLog(@"Disk cache will be cleared.");
        
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        
        // Also reset defaults in Settings bundle
        [[NSUserDefaults standardUserDefaults] setValue:@NO forKey:kAVNSetting_ResetCache];
        [[NSUserDefaults standardUserDefaults] setValue:@[] forKey:kAVNSetting_ReadNewsItems];
        [[NSUserDefaults standardUserDefaults] setValue:@(0) forKeyPath:kAVNSetting_UnreadNewsItemsCount];
        [[NSUserDefaults standardUserDefaults] setValue:@(0) forKeyPath:kAVNSetting_MapViewType];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    // Update the unread news items badge count (look for it in the UserDefaults)
    NSInteger unreadNewsItemCount = [[NSUserDefaults standardUserDefaults] integerForKey:kAVNSetting_UnreadNewsItemsCount];
    [self updateNewsItemBadge:MAX(0, unreadNewsItemCount)];

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
    
    if ([self.tabBar.items count]>=kNewsItemTabBarIndex) {
        newsTabBarItem = self.tabBar.items[kNewsItemTabBarIndex];
        newsTabBarItem.badgeValue = (unreadItemCount<=0)?nil:[NSString stringWithFormat:@"%ld", (long)unreadItemCount];
        
        // Save the new specified value into the UserDefaults
        [[NSUserDefaults standardUserDefaults] setInteger:unreadItemCount forKey:kAVNSetting_UnreadNewsItemsCount];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    } else {
        DLog(@"Error: could not find the news tab bar index to update the badge count!");
    }
}

@end
