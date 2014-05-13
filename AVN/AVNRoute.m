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
              @"kmzDownloadURL": @"kmzDownloadURL",
              @"startWaypoint": @"startWaypoint" };
}

+ (NSValueTransformer *)URLJSONTransformer
{
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSValueTransformer *)waypointsTransformer
{
    return [NSValueTransformer mtl_JSONArrayTransformerWithModelClass:[AVNWaypoint class]];
}


@end
