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
    AVNWaypoint *previousWP = nil;
    
    // Check if there are other waypoints available in parent AVNRoute
    if (self.parentRoute && self.parentRoute.waypoints && ([self.parentRoute.waypoints indexOfObject:self] != NSNotFound)) {
        
        NSInteger currentIndex = [self.parentRoute.waypoints indexOfObject:self];
        if (currentIndex>0)
            previousWP = self.parentRoute.waypoints[currentIndex-1];
        
    }
    
    return previousWP;
}

- (AVNWaypoint *)nextWaypoint
{
    AVNWaypoint *nextWP = nil;
    
    // Check if there are other waypoints available in parent AVNRoute
    if (self.parentRoute && self.parentRoute.waypoints && ([self.parentRoute.waypoints indexOfObject:self] != NSNotFound)) {
        
        NSInteger currentIndex = [self.parentRoute.waypoints indexOfObject:self];
        if (currentIndex<([self.parentRoute.waypoints count]-1))
            nextWP = self.parentRoute.waypoints[currentIndex+1];
        
    }
    
    return nextWP;
}

- (AVNWaypoint *)firstWaypoint
{
    __block AVNWaypoint *firstWP = nil;
    
    // Check if there are other waypoints available in parent AVNRoute
    if (self.parentRoute && self.parentRoute.waypoints &&
        ([self.parentRoute.waypoints count]>0) && ([self.parentRoute.waypoints indexOfObject:self] != NSNotFound)) {
        
        if ((!self.parentRoute.startWaypoint) || ([self.parentRoute.startWaypoint length]==0)) {
            
            // Parent route does not define the "start waypoint". Just return the first one available.
            firstWP = self.parentRoute.waypoints[0];
            
        } else {
            
            // Get the first waypoint according to the defined "start waypoint" in parent route
            NSString *startID = self.parentRoute.startWaypoint;
            [self.parentRoute.waypoints enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                AVNWaypoint *wp = (AVNWaypoint *)obj;
                if ([wp.identifier isEqualToString:startID]) {
                    firstWP = wp;
                    *stop = YES;
                }
            }];
        }
 
    }
    
    return firstWP;
}
@end
