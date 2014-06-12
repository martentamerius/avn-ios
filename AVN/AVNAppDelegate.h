//
//  AVNAppDelegate.h
//  AVN
//
//  Created by Marten Tamerius on 09-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kAVNSetting_ResetCache              @"reset_cache"
#define kAVNSetting_ReadNewsItems           @"read_news_items"
#define kAVNSetting_UnreadNewsItemsCount    @"unread_news_items_count"
#define kAVNSetting_MapViewType             @"mapview_type"

@interface AVNAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
