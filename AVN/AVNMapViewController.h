//
//  AVNMapViewController.h
//  AVN
//
//  Created by Marten Tamerius on 11-06-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AVNRoute.h"

@interface AVNMapViewController : UIViewController
@property (strong, nonatomic) AVNRoute *selectedRoute;
@property (strong, nonatomic) AVNWaypoint *selectedWaypoint;
@end
