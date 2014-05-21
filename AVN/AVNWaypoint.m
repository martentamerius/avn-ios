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
              @"coordinate": @"gpsCoordinate" };
}

+ (NSValueTransformer *)coordinateJSONTransformer
{
    return [MTLValueTransformer transformerWithBlock:^NSValue *(NSArray *arr) {
        NSValue *coordValue;
        if (arr && ([arr count]==2)) {
            CLLocationCoordinate2D gpsCoord = CLLocationCoordinate2DMake([arr[0] doubleValue], [arr[1] doubleValue]);
            coordValue = [NSValue valueWithMKCoordinate:gpsCoord];
        }
        return coordValue;
    }];
}


- (CLLocationCoordinate2D)gpsCoordinate
{
    return [self.coordinate MKCoordinateValue];
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
