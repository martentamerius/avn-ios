//
//  AVNRoute.m
//  AVN
//
//  Created by Marten Tamerius on 10-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNRoute.h"
#import "AVNWaypoint.h"

@implementation AVNRoute

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{ @"identifier": @"identifier",
              @"title": @"title",
              //@"length": @"length",
              @"kmzDownloadURL": @"kmzDownloadURL",
              @"startWaypoint": @"startWaypoint",
              @"waypoints": @"waypoints" };
}

+ (NSValueTransformer *)kmzDownloadURLJSONTransformer
{
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSValueTransformer *)waypointsJSONTransformer
{
    return [NSValueTransformer mtl_JSONArrayTransformerWithModelClass:[AVNWaypoint class]];
}


@end
