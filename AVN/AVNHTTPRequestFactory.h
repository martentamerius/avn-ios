//
//  AVNHTTPRequestFactory.h
//  AVN
//
//  Created by Marten Tamerius on 12-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <Foundation/Foundation.h>

// AVN URL stuff
#define kAVNHostname            @"www.avn.nl"
#define kGoogleMapsHostname     @"maps.google.nl"
#define kAVNRelRouteInfoURL     @"app.routeinfo.aspx"
#define kAVNRelWaypointURL      @"app.waypoint.aspx"
#define kAVNRelPageURL          @"app.pagina.aspx"

// Define possible actions for kAVNRelWaypointURL
typedef NS_ENUM(NSInteger, AVNActions) {
    AVNAction_GetMain = 0,
    AVNAction_GetStart,
    AVNAction_GetNearest,
    AVNAction_GetNext,
    AVNAction_GetPrevious
};

// Define possible types of pages for kAVNRelPageURL
typedef NS_ENUM(NSInteger, AVNPageTypes) {
    AVNPage_About = 0,
    AVNPage_News = 1
};


@class AVNRoute;
@class AVNWaypoint;

@interface AVNHTTPRequestFactory : NSObject
+ (NSString *)urlForAVNRouteInfo;
+ (NSString *)urlForAVNRoute:(AVNRoute *)avnRoute forAction:(AVNActions)action;
+ (NSString *)urlForAVNWaypoint:(AVNWaypoint *)avnWaypoint;

+ (NSString *)urlForAVNPage:(AVNPageTypes)pageType;
@end
