//
//  AVNWaypoint.h
//  AVN
//
//  Created by Marten Tamerius on 12-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <Mantle.h>
#import "AVNRoute.h"

@interface AVNWaypoint : MTLModel <MTLJSONSerializing>
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) CLLocation *gpsCoordinate;

@property (nonatomic, strong) AVNRoute *parentRoute;

- (AVNWaypoint *)previousWaypoint;
- (AVNWaypoint *)nextWaypoint;

@end
