//
//  AVNRoute.h
//  AVN
//
//  Created by Marten Tamerius on 10-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Mantle.h>
#import <CoreLocation/CoreLocation.h>
#import "KML.h"

@class AVNWaypoint;

@interface AVNRoute : MTLModel <MTLJSONSerializing>
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) NSString *title;
@property (nonatomic) double length;
@property (nonatomic, strong) NSURL *kmzDownloadURL;
@property (nonatomic, strong) KMLRoot *kml;
@property (nonatomic, strong) NSString *startWaypoint;

@property (nonatomic, strong) NSArray *waypoints;

- (CLLocationDistance)calculateTotalRouteLengthWithCompletionBlock:(void (^)(void))completionBlock;
- (void)loadRouteKMLWithCompletionBlock:(void (^)(void))completionBlock;

- (AVNWaypoint *)firstWaypoint;
@end
