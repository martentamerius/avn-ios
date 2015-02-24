//
//  AVNAppDelegate.m
//  AVN
//
//  Created by Marten Tamerius on 09-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNAppDelegate.h"
#import "AVNRootViewController.h"
#import "AVNHTTPRequestFactory.h"
#import "AVNNewsTableViewController.h"
#import "AVNNewsItem.h"
#import <SDURLCache.h>
#import <AFNetworkActivityIndicatorManager.h>
#import <AFNetworking.h>
#import <Mantle.h>
#import <TSMessage.h>

#define kAVNNewsItemCodeKey    @"AVNNewsItemCode"

@interface AVNAppDelegate () <UIAlertViewDelegate>
@property (nonatomic, strong) NSURL *externalURL;
@property (nonatomic, copy) void (^backgroundFetchCompletionHandler)(UIBackgroundFetchResult result);
@property (nonatomic, copy) void (^scheduleNotificationBlock)();
@property (nonatomic, strong) AFHTTPRequestOperation *backgroundFetchNewsItemRequest;
@property (nonatomic) NSInteger numberOfNewPostedNewsItems;
@property (nonatomic) NSInteger numberOfUnreadNewsItems;
@property (nonatomic, strong) AVNNewsItem *singleNewPostedNewsItem;
@property (nonatomic) BOOL shouldShowAlertView;
@property (nonatomic) BOOL alertViewActive;
@end


@implementation AVNAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Register defaults for Settings bundle
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ kAVNSetting_ResetApp:@NO,
                                                               kAVNSetting_ReadNewsItems:@[],
                                                               kAVNSetting_UnreadNewsItemsCount:@(0),
                                                               kAVNSetting_MapViewType:@(1),
                                                               kAVNSetting_HideAlertForExternalURL:@NO,
                                                               kAVNSetting_TimestampForLastNewsDownload:@"",
                                                               kAVNSetting_ShowNewsItemsAsNotifications:@(-1) }];
    
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(setMinimumBackgroundFetchInterval:)]) {
        // iOS 7+: Set background fetch interval to once a day for fetching news items
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:(3600*24)];
    }
    
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        // iOS 8: Register the notification types
        UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
        UIUserNotificationSettings *mySettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:mySettings];
    }
    
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
    // We're backgrounded. Don't show any alert dialogs
    self.shouldShowAlertView = NO;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Reinitialize automatic network activity indicator
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    
    // Check if the disk cache should be cleared before starting the app
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kAVNSetting_ResetApp]) {
        DLog(@"App settings will be cleared.");
        
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        
        // Also reset defaults in Settings bundle
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAVNSetting_ResetApp];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAVNSetting_ReadNewsItems];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAVNSetting_DownloadedNewsItems];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAVNSetting_UnreadNewsItemsCount];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAVNSetting_MapViewType];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAVNSetting_HideAlertForExternalURL];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAVNSetting_TimestampForLastNewsDownload];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAVNSetting_ShowNewsItemsAsNotifications];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    // Update the unread news items badge count (look for it in the UserDefaults)
    NSInteger unreadNewsItemCount = [[NSUserDefaults standardUserDefaults] integerForKey:kAVNSetting_UnreadNewsItemsCount];
    
    // App has become active, so alert dialogs are permitted
    self.shouldShowAlertView = YES;
    
    // Check for new AVN news items
    AVNNewsTableViewController *newsItemListController;
    if (self.window && self.window.rootViewController) {
        AVNRootViewController *rootVC = (AVNRootViewController *)self.window.rootViewController;
        [rootVC updateNewsItemBadge:MAX(0, unreadNewsItemCount)];
        
        if ([rootVC.viewControllers count]>2) {
            UINavigationController *secondTabController = (UINavigationController *)rootVC.viewControllers[1];
            if ([secondTabController.viewControllers count]>0)
                newsItemListController = secondTabController.viewControllers[0];
        }
    }
    [self refreshNewsItemListForController:newsItemListController withCompletionHandler:nil];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


#pragma mark - Background fetch news articles

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    // The user tapped a local notification (for a recently downloaded news item) generated by the AVN app.
    AVNNewsTableViewController *newsItemListController;
    
    // Display the AVN News tab right away
    if (self.window && self.window.rootViewController) {
        AVNRootViewController *rootVC = (AVNRootViewController *)self.window.rootViewController;
        if ([rootVC.viewControllers count]>2) {
            [rootVC setSelectedIndex:1];
            
            UINavigationController *secondTabController = (UINavigationController *)rootVC.viewControllers[1];
            if ([secondTabController.viewControllers count]>0)
                newsItemListController = secondTabController.viewControllers[0];
        }
    }
    
    // Retrieve the news item, if specified in the notification
    if (newsItemListController && notification.userInfo && [notification.userInfo objectForKey:kAVNNewsItemCodeKey]) {
        NSString *newsItemID = [notification.userInfo objectForKey:kAVNNewsItemCodeKey];
        // Push the news item right away onto the view stack, if possible
        [newsItemListController pushNewsItemWithIdentifier:newsItemID];
    }
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler
{
    // Background fetch: don't show any alert dialogs
    self.shouldShowAlertView = NO;
    __weak typeof(self) weakSelf = self;
    
    // Reinitialize automatic network activity indicator
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];

    // Check if we have permission to show notifications
    [self checkPermissionsForLocalNotificationOfType:UIUserNotificationTypeAlert thenScheduleBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            
            // Check if we have already fetched the news items in the last 8 hours
            NSDate *timestamp = [[NSUserDefaults standardUserDefaults] objectForKey:kAVNSetting_TimestampForLastNewsDownload];
            if (timestamp && ([timestamp timeIntervalSinceNow]>=(-8*3600))) {
                // Skip the current roundtrip to the server
                completionHandler(UIBackgroundFetchResultNoData);
                
            } else {
                // Save completion handler for later; it should ALWAYS be executed!
                strongSelf.backgroundFetchCompletionHandler = completionHandler;
                
                [strongSelf refreshNewsItemListForController:nil withCompletionHandler:^{
                    
                    // Turn off automatic network activity indicator
                    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:NO];

                    // Check the fetch result
                    UIBackgroundFetchResult backgroundFetchResult = (strongSelf.backgroundFetchError)?UIBackgroundFetchResultFailed:UIBackgroundFetchResultNoData;
                    
                    if (strongSelf.numberOfNewPostedNewsItems >= 1) {
                        backgroundFetchResult = UIBackgroundFetchResultNewData;
                        
                        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
                        localNotification.fireDate = nil; // Show immediately
                        localNotification.applicationIconBadgeNumber = strongSelf.numberOfUnreadNewsItems;
                        
                        if (strongSelf.singleNewPostedNewsItem) {
                            localNotification.alertBody = strongSelf.singleNewPostedNewsItem.title;
                            localNotification.userInfo = @{ kAVNNewsItemCodeKey : strongSelf.singleNewPostedNewsItem.identifier };
                        } else {
                            localNotification.alertBody = [NSString stringWithFormat:@"Er zijn %@ nieuwsartikelen beschikbaar.", @(strongSelf.numberOfNewPostedNewsItems)];
                        }
                        
                        // Schedule the local notification
                        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
                    }
                    
                    if (strongSelf.backgroundFetchCompletionHandler) {
                        void (^bfCompletionHandler)(UIBackgroundFetchResult result) = strongSelf.backgroundFetchCompletionHandler;
                        strongSelf.backgroundFetchCompletionHandler = nil;
                        
                        // Always execute the background fetch completion handler!
                        bfCompletionHandler(backgroundFetchResult);
                    }
                }];
            }
        }
    }];
}

- (void)refreshNewsItemListForController:(AVNNewsTableViewController *)newsItemListController withCompletionHandler:(void (^)())completionHandler
{
    // Request header should have a field with content-type: "application/json"
    NSString *contentType = [NSString stringWithFormat:@"application/json; charset=%@", (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))];
    
    // Init request manager (with JSON serializer) and URL request object
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFHTTPRequestSerializer new];
    [manager.requestSerializer setTimeoutInterval:8];
    manager.responseSerializer = [AFJSONResponseSerializer new];
    [manager.requestSerializer setValue:contentType forHTTPHeaderField:@"Content-Type"];
    
    self.backgroundFetchError = nil;
    
    // Init actual HTTP request operation
    __weak AVNAppDelegate *weakSelf = self;
    self.backgroundFetchNewsItemRequest = [manager GET:[AVNHTTPRequestFactory urlForAVNNewsItemList] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        weakSelf.numberOfNewPostedNewsItems = 0;
        weakSelf.numberOfUnreadNewsItems = 0;
        weakSelf.singleNewPostedNewsItem = nil;
        weakSelf.backgroundFetchError = nil;
        
        // Process the received response with Mantle
        NSError *error = nil;
        NSArray *jsonResponseArray = ([responseObject isKindOfClass:[NSArray class]])?(NSArray *)responseObject:[NSArray arrayWithObject:responseObject];
        
        NSMutableArray *downloadedNewsItems = [NSMutableArray array];
        NSArray *previouslyDownloadedNewsItems = [[NSUserDefaults standardUserDefaults] arrayForKey:kAVNSetting_DownloadedNewsItems];
        if (!previouslyDownloadedNewsItems)
            previouslyDownloadedNewsItems = @[];
        NSArray *readNewsItems = [[NSUserDefaults standardUserDefaults] arrayForKey:kAVNSetting_ReadNewsItems];
        if (!readNewsItems)
            readNewsItems = @[];
        
        NSMutableArray *newsItemsListFromServer = [NSMutableArray arrayWithCapacity:[jsonResponseArray count]];
        for (id jsonObject in jsonResponseArray) {
            AVNNewsItem *newsItem = [MTLJSONAdapter modelOfClass:[AVNNewsItem class] fromJSONDictionary:jsonObject error:&error];
            if (!newsItem) {
                DLog(@"Error converting AVN JSON news item info: %@, %@", [error localizedDescription], [error userInfo]);
            } else {
                
                // Check in UserDefaults if the app has already downloaded this news item
                newsItem.isNewPostedNewsItem = (![previouslyDownloadedNewsItems containsObject:newsItem.identifier]);
                if (newsItem.isNewPostedNewsItem) {
                    weakSelf.numberOfNewPostedNewsItems++;
                    if (weakSelf.numberOfNewPostedNewsItems == 1) {
                        weakSelf.singleNewPostedNewsItem = newsItem;
                    } else {
                        weakSelf.singleNewPostedNewsItem = nil;
                    }
                }
                [downloadedNewsItems addObject:newsItem.identifier];
                
                // Check in UserDefaults if the user has already seen this news item
                newsItem.hasReadItem = [readNewsItems containsObject:newsItem.identifier];
                if (!newsItem.hasReadItem)
                    weakSelf.numberOfUnreadNewsItems++;
                
                // Add the news item to the list
                [newsItemsListFromServer addObject:newsItem];
            }
        }
        
        // Check if we have permission to show app badge
        NSInteger unreadNewsItemCount = weakSelf.numberOfUnreadNewsItems;
        [weakSelf checkPermissionsForLocalNotificationOfType:UIUserNotificationTypeBadge thenScheduleBlock:^{
            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:unreadNewsItemCount];
        }];
        
        if (newsItemsListFromServer && newsItemListController) {
            // Save the converted AVN route list
            newsItemListController.newsItemsList = newsItemsListFromServer;
            dispatch_async(dispatch_get_main_queue(), ^{
                // Update UI on main thread
                [newsItemListController.tableView reloadData];
            });
        }
        
        if (weakSelf.window && weakSelf.window.rootViewController) {
            // Set unread news item badge count
            AVNRootViewController *rootViewController = (AVNRootViewController *)weakSelf.window.rootViewController;
            [rootViewController updateNewsItemBadge:weakSelf.numberOfUnreadNewsItems];
        }

        if (downloadedNewsItems) {
            // Remember which news items have already been downloaded
            [[NSUserDefaults standardUserDefaults] setObject:downloadedNewsItems forKey:kAVNSetting_DownloadedNewsItems];
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kAVNSetting_TimestampForLastNewsDownload];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        if (completionHandler) {
            // Finally, refresh UI on main thread
            dispatch_async(dispatch_get_main_queue(), completionHandler);
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DLog(@"Error downloading AVN news items list info: %@, %@", [error localizedDescription], [error userInfo]);
        
        weakSelf.backgroundFetchError = error;
        
        if (completionHandler) {
            // Refresh UI on main thread
            dispatch_async(dispatch_get_main_queue(), completionHandler);
        }
    }];
}


#pragma mark - Local notification user permissions and scheduling

- (void)checkPermissionsForLocalNotificationOfType:(UIUserNotificationType)type thenScheduleBlock:(void (^)())notificationBlock
{
    // Check user permissions for local notifications (badge/sound/alert) and if permission is granted, schedule the block.
    BOOL permissionGranted = NO;
    
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)]) {
        
        // iOS 8: Check if we have permission for the notification type with UIApplication
        UIUserNotificationSettings *currentSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
        if ((currentSettings.types & type) != 0) {
            // We have permission!
            permissionGranted = YES;
        }
        
    } else {
        
        // iOS 6/7: Check user defaults for permission to show news item notifications
        NSNumber *showNewsItemsAsNotifications = [[NSUserDefaults standardUserDefaults] valueForKey:kAVNSetting_ShowNewsItemsAsNotifications];
        
        if ([showNewsItemsAsNotifications integerValue] == 1) {
            // We already have permission!
            permissionGranted = YES;
            
        } else if ((!showNewsItemsAsNotifications) || ([showNewsItemsAsNotifications integerValue]<0)) {
            
            if (self.shouldShowAlertView && (!self.alertViewActive)) {
                // Permission has not been asked yet; question user first.
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Meldingen" message:@"De AVN app wil u graag op de hoogte houden van AVN nieuws.\nWilt u daarvoor meldingen inschakelen?" delegate:self cancelButtonTitle:@"Nee" otherButtonTitles:@"Ja", nil];
                alert.tag = 2;
                [alert show];
                self.alertViewActive = YES;
                
                // Remember the block to schedule; we may run it after the user granted permission...
                self.scheduleNotificationBlock = notificationBlock;
            }
        }
    }
    
    if (permissionGranted && notificationBlock) {
        // Run the specified notification block.
        notificationBlock();
    }
}


#pragma mark - External URLs

- (void)openExternalURL:(NSURL *)url
{
    self.externalURL = url;
    
    BOOL showAlert = (![[NSUserDefaults standardUserDefaults] boolForKey:kAVNSetting_HideAlertForExternalURL]);
    if (showAlert && self.shouldShowAlertView) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Let op"
                                                        message:@"Openen van links naar externe sites wordt niet ondersteund in deze app.\n\nWilt u de link openen in een andere app?"
                                                       delegate:self
                                              cancelButtonTitle:@"Nee"
                                              otherButtonTitles:@"Ja", @"Altijd", nil];
        alert.tag = 1;
        [alert show];
        self.alertViewActive = YES;
        
    } else {
        
        // User already tapped "Always" in a previous alert view; open link right away!
        [self userPermittedOpeningOfExternalURL];
    }
}

- (void)userPermittedOpeningOfExternalURL
{
    // Open the external URL in Safari
    if ([[UIApplication sharedApplication] canOpenURL:self.externalURL]) {
        if (![[UIApplication sharedApplication] openURL:self.externalURL]) {
            NSLog(@"Failed to open URL: %@",[self.externalURL description]);
            
            // Show error message to user
            [TSMessage showNotificationInViewController:self.window.rootViewController
                                                  title:@"Laden van externe pagina is mislukt."
                                               subtitle:nil
                                                   type:TSMessageNotificationTypeError
                                               duration:5
                                   canBeDismissedByUser:YES];
        }
    } else {
        NSLog(@"Cannot open URL with apps currently installed on this device: %@",[self.externalURL description]);
        
        // Show error message to user
        [TSMessage showNotificationInViewController:self.window.rootViewController
                                              title:@"Laden van externe pagina is mislukt."
                                           subtitle:@"Er is geen app geinstalleerd die deze URL kan afhandelen."
                                               type:TSMessageNotificationTypeError
                                           duration:5
                               canBeDismissedByUser:YES];
    }
}


#pragma mark - UIAlertView delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    self.alertViewActive = NO;
    
    switch (alertView.tag) {
        case 1: {
            // External links dialog
            if (self.externalURL && (buttonIndex != alertView.cancelButtonIndex)) {
                
                // Check if the "Always" button has been tapped... remember this setting!
                if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Altijd"]) {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kAVNSetting_HideAlertForExternalURL];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
                
                // Open the external URL in Safari
                if ([[UIApplication sharedApplication] canOpenURL:self.externalURL]) {
                    if (![[UIApplication sharedApplication] openURL:self.externalURL]) {
                        NSLog(@"Failed to open URL: %@",[self.externalURL description]);
                        
                        // Show error message to user
                        [TSMessage showNotificationInViewController:self.window.rootViewController
                                                              title:@"Laden van externe pagina is mislukt."
                                                           subtitle:nil
                                                               type:TSMessageNotificationTypeError
                                                           duration:5
                                               canBeDismissedByUser:YES];
                    }
                } else {
                    NSLog(@"Cannot open URL with apps currently installed on this device: %@",[self.externalURL description]);
                    
                    // Show error message to user
                    [TSMessage showNotificationInViewController:self.window.rootViewController
                                                          title:@"Laden van externe pagina is mislukt."
                                                       subtitle:@"Er is geen app geinstalleerd die deze URL kan afhandelen."
                                                           type:TSMessageNotificationTypeError
                                                       duration:5
                                           canBeDismissedByUser:YES];
                }
                
                self.externalURL = nil;
            }
            break;
        }
            
        case 2: {
            // (Dis)allow local notifications in iOS 6/7
            if (buttonIndex != alertView.cancelButtonIndex) {
                // User granted permission
                [[NSUserDefaults standardUserDefaults] setValue:@(1) forKey:kAVNSetting_ShowNewsItemsAsNotifications];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                // Run schedule notification block, if appropriate.
                if (self.scheduleNotificationBlock)
                    self.scheduleNotificationBlock();
                
            } else {
                // Permission denied
                [[NSUserDefaults standardUserDefaults] setValue:@(0) forKey:kAVNSetting_ShowNewsItemsAsNotifications];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                // Reset app badge
                [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
            }
            
            self.scheduleNotificationBlock = nil;
            break;
        }
    }
}

@end
