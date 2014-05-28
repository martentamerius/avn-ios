//
//  AVNWaypoint.m
//  AVN
//
//  Created by Marten Tamerius on 12-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNWaypoint.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

@interface AVNWaypoint ()
@property (nonatomic, strong) NSValue *coordinate; // Shadow-value to store gps coordinate for value transformer
@end


@implementation AVNWaypoint

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{ @"identifier": @"identifier",
              @"title": @"title",
              @"gpsCoordinate": @"gpsCoordinate" };
}

+ (NSValueTransformer *)gpsCoordinateJSONTransformer
{
    return [MTLValueTransformer transformerWithBlock:^CLLocation *(NSArray *arr) {
        CLLocation *gpsCoord;
        if (arr && ([arr count]==2)) {
            gpsCoord = [[CLLocation alloc] initWithLatitude:[arr[0] doubleValue] longitude:[arr[1] doubleValue]];
        }
        return gpsCoord;
    }];
}


- (AVNWaypoint *)previousWaypoint
{
    AVNWaypoint *previous = nil;
    
    // Check if there are other waypoints available in parent AVNRoute
    if (self.parentRoute && self.parentRoute.waypoints && ([self.parentRoute.waypoints indexOfObject:self] != NSNotFound)) {
        
        NSInteger currentIndex = [self.parentRoute.waypoints indexOfObject:self];
        if (currentIndex>0)
            previous = self.parentRoute.waypoints[currentIndex-1];
        
    }
    
    return previous;
}

- (AVNWaypoint *)nextWaypoint
{
    AVNWaypoint *next = nil;
    
    // Check if there are other waypoints available in parent AVNRoute
    if (self.parentRoute && self.parentRoute.waypoints && ([self.parentRoute.waypoints indexOfObject:self] != NSNotFound)) {
        
        NSInteger currentIndex = [self.parentRoute.waypoints indexOfObject:self];
        if (currentIndex<([self.parentRoute.waypoints count]-1))
            next = self.parentRoute.waypoints[currentIndex+1];
        
    }
    
    return next;
}

@end
