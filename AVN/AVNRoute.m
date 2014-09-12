//
//  AVNRoute.m
//  AVN
//
//  Created by Marten Tamerius on 10-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNRoute.h"
#import "AVNWaypoint.h"
#import "KML+MapKit.h"
#import "MKMap+KML.h"
#import <zlib.h>
#import "ZipFile.h"
#import "ZipException.h"
#import "FileInZipInfo.h"
#import "ZipWriteStream.h"
#import "ZipReadStream.h"


@implementation AVNRoute

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{ @"identifier": @"identifier",
              @"title": @"title",
              //@"length": @"length",
              @"kmzDownloadURL": @"kmzDownloadURL",
              @"startWaypoint": @"startWaypoint",
              @"waypoints": @"waypoints" };
}

+ (NSValueTransformer *)kmzDownloadURLJSONTransformer
{
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSValueTransformer *)waypointsJSONTransformer
{
    return [NSValueTransformer mtl_JSONArrayTransformerWithModelClass:[AVNWaypoint class]];
}


#pragma mark - Route length calculation

- (CLLocationDistance)calculateTotalRouteLengthWithCompletionBlock:(void (^)(void))completionBlock
{
    __block CLLocationDistance length = 0.0;
    
    if (self.kmzDownloadURL) {
        
        // Define KML download completion block for use after downloading KML, if necessary
        __weak AVNRoute *weakSelf = self;
        void (^kmlDownloadCompletionBlock)() = ^void {
            // Calculate distance from MKShape geometries
            if (weakSelf.kml) {
                __block KMLLineString *lines;
                [weakSelf.kml.geometries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj isKindOfClass:[KMLLineString class]]) {
                        lines = (KMLLineString *)obj;
                        *stop = YES;
                    }
                }];
                if (lines) {
                    // Calculate total route length from KML path
                    [lines.coordinates enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        KMLCoordinate *currentCoord = (KMLCoordinate *)obj;
                        KMLCoordinate *nextCoord;
                        if (idx == ([lines.coordinates count]-1)) {
                            nextCoord = [lines.coordinates firstObject];
                        } else {
                            nextCoord = [lines.coordinates objectAtIndex:(idx+1)];
                        }
                        
                        if (currentCoord && nextCoord) {
                            // Convert KMLCoordinates to CLLocation coordinates
                            CLLocation *currentLocation = [[CLLocation alloc] initWithLatitude:currentCoord.latitude longitude:currentCoord.longitude];
                            CLLocation *nextLocation = [[CLLocation alloc] initWithLatitude:nextCoord.latitude longitude:nextCoord.longitude];
                            
                            // Let CoreLocation measure the distance between gps coordinates
                            CLLocationDistance distance = [currentLocation distanceFromLocation:nextLocation];
                            // Route length is in kilometers...
                            length += (distance / 1000.0);                        }
                    }];
                    
                } else {
                    
                    if (self.waypoints && ([self.waypoints count]>0)) {
                        // Try to calculate the length according to the waypoints (Note: as the crow flies!)
                        [weakSelf.waypoints enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            // Calculate distance to next waypoint
                            AVNWaypoint *currentWaypoint = (AVNWaypoint *)obj;
                            AVNWaypoint *nextWaypoint = [currentWaypoint nextWaypoint];
                            if (!nextWaypoint) {
                                nextWaypoint = [currentWaypoint firstWaypoint];
                            }
                            
                            if (currentWaypoint && nextWaypoint) {
                                CLLocationDistance distance = [currentWaypoint.gpsCoordinate distanceFromLocation:nextWaypoint.gpsCoordinate];
                                // Route length is in kilometers...
                                length += (distance / 1000.0);
                            }
                        }];
                    }
                }
            }
            
            if (completionBlock != NULL) {
                // Call completion block on main thread!
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock();
                });
            }
        };
        
        if (!self.kml) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [weakSelf loadRouteKMLWithCompletionBlock:kmlDownloadCompletionBlock];
            });
        } else {
            // Call kml download completion block right away; we already have the KML
            kmlDownloadCompletionBlock();
        }
    }
    
    return length;
}


#pragma mark - KML downloading

- (void)loadRouteKMLWithCompletionBlock:(void (^)(void))completionBlock
{
    // load new KML
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // observe KML format error
        [[NSNotificationCenter defaultCenter] addObserverForName:kKMLInvalidKMLFormatNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          NSString *description = [[note userInfo] valueForKey:kKMLDescriptionKey];
                                                          DLog(@"%@", description);
                                                      }
         ];
        
        if ([[[self.kmzDownloadURL absoluteString] pathExtension] isEqualToString:@"kmz"]) {
            NSString *fileName = [[self.kmzDownloadURL absoluteString] lastPathComponent];
            NSString *filePath = nil;
            
            // Download kmz to temporary location
            filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
            
            NSURLRequest *request = [NSURLRequest requestWithURL:self.kmzDownloadURL];
            NSError *downloadError;
            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&downloadError];
            if (downloadError) {
                DLog(@"error, %@", downloadError);
            } else {
                [data writeToFile:filePath atomically:YES];
            }
            
            if (filePath) {
                __block NSMutableData *data;
                ZipFile *kmzFile;
                @try {
                    kmzFile = [[ZipFile alloc] initWithFileName:filePath mode:ZipFileModeUnzip];
                    
                    [kmzFile.listFileInZipInfos enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        FileInZipInfo *info = (FileInZipInfo *)obj;
                        
                        NSString *ext = info.name.pathExtension.lowercaseString;
                        
                        if ([ext isEqualToString:@"kml"]) {
                            [kmzFile locateFileInZip:info.name];
                            
                            ZipReadStream *reader = kmzFile.readCurrentFileInZip;
                            data = [[NSMutableData alloc] initWithLength:info.length];
                            [reader readDataWithBuffer:data];
                            [reader finishedReading];
                            
                            *stop = YES;
                        }
                    }];
                }
                @catch (NSException *exception) {
                    DLog(@"Caught exception: %@", [exception debugDescription]);
                }
                @finally {
                    if (kmzFile) {
                        [kmzFile close];
                    }
                }
                
                if (data) {
                    self.kml = [KMLParser parseKMLWithData:data];
                }
            }
            
        } else {
            self.kml = [KMLParser parseKMLAtURL:self.kmzDownloadURL];
        }
        
        // remove KML format error observer
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kKMLInvalidKMLFormatNotification object:nil];
        
        if (completionBlock != NULL) {
            // Call completion block on main thread!
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}


#pragma mark - Waypoints

- (AVNWaypoint *)firstWaypoint
{
    __block AVNWaypoint *first;
    
    if(self.waypoints && ([self.waypoints count]>0)) {
        if (self.startWaypoint) {
            NSString *idOfWaypointToFind = self.startWaypoint;
            [self.waypoints enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                AVNWaypoint *currentWaypoint = (AVNWaypoint *)obj;
                if ([currentWaypoint.identifier isEqualToString:idOfWaypointToFind]) {
                    first = currentWaypoint;
                    *stop = YES;
                }
            }];
        } else  {
            first = [self.waypoints firstObject];
        }
    }
    
    return first;
}

@end
