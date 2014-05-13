//
//  AVNWaypointViewController.h
//  AVN
//
//  Created by Marten Tamerius on 12-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "AVNRoute.h"
#import "AVNWaypoint.h"

@interface AVNWaypointViewController : UIViewController
@property (nonatomic, strong) CLLocation *currentLocation;
@property (nonatomic, strong) AVNWaypoint *selectedWaypoint;
@property (nonatomic, strong) AVNRoute *selectedRoute;
@end
