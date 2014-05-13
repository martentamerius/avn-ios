//
//  AVNWaypoint.m
//  AVN
//
//  Created by Marten Tamerius on 12-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNWaypoint.h"

@implementation AVNWaypoint

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{ @"identifier": @"identifier",
              @"title": @"title",
              @"gpsCoordinate": @"gpsCoordinate" };
}

@end
