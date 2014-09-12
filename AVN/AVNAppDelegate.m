//
//  AVNAppDelegate.m
//  AVN
//
//  Created by Marten Tamerius on 09-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNAppDelegate.h"
#import "AVNRootViewController.h"
#import <SDURLCache.h>
#import <AFNetworkActivityIndicatorManager.h>

@implementation AVNAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Register defaults for Settings bundle
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ kAVNSetting_ResetCache:@NO,
                                                               kAVNSetting_ReadNewsItems:@[],
                                                               kAVNSetting_UnreadNewsItemsCount:@(0),
                                                               kAVNSetting_MapViewType:@(0) }];
    
    // Initialize disk cache for offline viewing of webpages
    SDURLCache *urlCache = [[SDURLCache alloc] initWithMemoryCapacity:(16*1024*1024)
                                                         diskCapacity:(64*1024*1024)
                                                             diskPath:[SDURLCache defaultCachePath]];
    urlCache.ignoreMemoryOnlyStoragePolicy = YES;
    [NSURLCache setSharedURLCache:urlCache];

    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Turn off automatic network activity indicator
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:NO];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Reinitialize automatic network activity indicator
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
