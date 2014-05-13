//
//  AVNHTTPRequestFactory.m
//  AVN
//
//  Created by Marten Tamerius on 12-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNHTTPRequestFactory.h"
#import "AVNRoute.h"
#import "AVNWaypoint.h"

static NSArray *_actions, *_pageTypes;


@implementation AVNHTTPRequestFactory

+ (NSString *)urlForAVNRouteInfo
{
    // Assemble the HTTP request string
    NSString *urlString = [NSString stringWithFormat:@"http://%@/%@", kAVNHostname, kAVNRelRouteInfoURL ];
    return urlString;
}

+ (NSString *)urlForAVNRoute:(AVNRoute *)avnRoute forAction:(AVNActions)action
{
    // Assemble the HTTP request string from specified route id and action
    NSString *urlString = [NSString stringWithFormat:@"http://%@/%@?id=%@&%@", kAVNHostname, kAVNRelWaypointURL,
                           avnRoute.identifier, [AVNHTTPRequestFactory actionStringForAction:action] ];
    return urlString;
}

+ (NSString *)urlForAVNWaypoint:(AVNWaypoint *)avnWaypoint
{
    // Assemble the HTTP request string from specified waypoint id and its parent route id
    NSString *urlString = [NSString stringWithFormat:@"http://%@/%@?id=%@_%@", kAVNHostname, kAVNRelWaypointURL,
                           avnWaypoint.parentRoute.identifier, avnWaypoint.identifier ];
    return urlString;
}

+ (NSString *)urlForAVNPage:(AVNPageTypes)pageType
{
    // Assemble the HTTP request string for the kAVNRelPageURL of type "pageType".
    NSString *urlString = [NSString stringWithFormat:@"http://%@/%@?id=%@", kAVNHostname, kAVNRelPageURL,
                           [AVNHTTPRequestFactory pageTypeStringForAction:pageType] ];
    return urlString;
}


#pragma mark - Helper methods

+ (NSString *)actionStringForAction:(AVNActions)action
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Dictionary of actions to perform on routes/waypoints.
        // Used when assembling the URL for the HTTP request. The initialization will happen only once.
        _actions = @[ @"wp=main", @"wp=start", @"wp=nearest&ll=", @"wp=next", @"wp=previous" ];
    });
    
    return [_actions objectAtIndex:action];
}

+ (NSString *)pageTypeStringForAction:(AVNPageTypes)pageType
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Dictionary of page types for kAVNRelPageURL.
        // Used when assembling the URL for the HTTP request. The initialization will happen only once.
        _pageTypes = @[ @"overavn", @"nieuws" ];
    });
    
    return [_pageTypes objectAtIndex:pageType];
}


@end
