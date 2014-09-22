//
//  AVNWaypointMapViewController.h
//  AVN
//
//  Created by Marten Tamerius on 22-09-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AVNWaypoint.h"

@interface AVNWaypointMapViewController : UIViewController
@property (strong, nonatomic) AVNWaypoint *selectedWaypoint;
@end
