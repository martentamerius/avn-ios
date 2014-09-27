//
//  AVNAppDelegate.h
//  AVN
//
//  Created by Marten Tamerius on 09-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kAVNSetting_ResetApp                        @"reset_app"
#define kAVNSetting_ReadNewsItems                   @"read_news_items"
#define kAVNSetting_DownloadedNewsItems             @"downloaded_news_items"
#define kAVNSetting_UnreadNewsItemsCount            @"unread_news_items_count"
#define kAVNSetting_MapViewType                     @"mapview_type"
#define kAVNSetting_HideAlertForExternalURL         @"hide_alert_for_external_url"
#define kAVNSetting_TimestampForLastNewsDownload    @"timestamp_for_last_news_download"

@class AVNNewsTableViewController;

@interface AVNAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;

- (void)openExternalURL:(NSURL *)url;
- (void)refreshNewsItemListForController:(AVNNewsTableViewController *)newsItemListController withCompletionHandler:(void (^)())completionHandler;
@end
