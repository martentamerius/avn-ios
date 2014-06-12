
//
//  AVNRouteMapViewController.m
//  AVN
//
//  Created by Marten Tamerius on 11-06-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNRouteMapViewController.h"
#import <MapKit/MapKit.h>
#import "AVNAppDelegate.h"
#import "AVNWaypoint.h"
#import "AVNWaypointViewController.h"
#import <zlib.h>
#import "KML.h"
#import "KML+MapKit.h"
#import "MKMap+KML.h"
#import "ZipFile.h"
#import "ZipException.h"
#import "FileInZipInfo.h"
#import "ZipWriteStream.h"
#import "ZipReadStream.h"
#import <MBProgressHUD.h>
#import <TSMessage.h>


@interface AVNRouteMapViewController () <MKMapViewDelegate>
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *mapTypeControl;

@property (nonatomic, strong) KMLRoot *kml;
@property (nonatomic, strong) NSArray *geometries;

@property (strong, nonatomic) AVNWaypoint *tappedWaypoint;
@end


@implementation AVNRouteMapViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialize variables
        self.geometries = @[];
    }
    return self;
}

- (void)awakeFromNib
{
    // Set the map view type according user settings
    [self loadMapType];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setSelectedRoute:(AVNRoute *)newSelectedRoute
{
    if (_selectedRoute != newSelectedRoute) {
        _selectedRoute = newSelectedRoute;
        
        // Update the view
        if (self.selectedRoute && self.selectedRoute.kmzDownloadURL)
            [self loadKMLAtURL:self.selectedRoute.kmzDownloadURL];
    }
}

- (void)dealloc
{
    // Remove self from notification center
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



#pragma mark - Map View URL

- (void)loadKMLAtURL:(NSURL *)url
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.navigationController.view.userInteractionEnabled = NO;
    
    // remove all annotations and overlays
    NSMutableArray *annotations = @[].mutableCopy;
    [self.mapView.annotations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (![obj isKindOfClass:[MKUserLocation class]]) {
            [annotations addObject:obj];
        }
    }];
    [self.mapView removeAnnotations:annotations];
    [self.mapView removeOverlays:self.mapView.overlays];
    
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
        
        if ([[[url absoluteString] pathExtension] isEqualToString:@"kmz"]) {
            NSString *fileName = [[url absoluteString] lastPathComponent];
            NSString *filePath = nil;
            
            // Download kmz to temporary location
            filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
            
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
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
            self.kml = [KMLParser parseKMLAtURL:url];
        }
        
        // remove KML format error observer
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kKMLInvalidKMLFormatNotification object:nil];
        
        if (self.kml) {
            self.geometries = self.kml.geometries;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
                self.navigationController.view.userInteractionEnabled = YES;
                
                [self reloadMapView];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
                self.navigationController.view.userInteractionEnabled = YES;
                
                // Show error message to user
                [TSMessage showNotificationInViewController:self title:@"Laden van route informatie is mislukt."
                                                   subtitle:@""
                                                       type:TSMessageNotificationTypeError
                                                   duration:5
                                       canBeDismissedByUser:YES];
            });
        }
    });
}


#pragma mark - Map View interaction

- (IBAction)mapTypeChanged:(id)sender
{
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    self.mapView.mapType = segmentedControl.selectedSegmentIndex;
    
    [self saveMapType];
}

- (void)loadMapType
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *mapType = [defaults objectForKey:kAVNSetting_MapViewType];
    if (!mapType) {
        mapType = @(0);
    }
    
    self.mapView.mapType = [mapType integerValue];
    self.mapTypeControl.selectedSegmentIndex = [mapType integerValue];
}

- (void)saveMapType
{
    NSNumber *mapType = @(self.mapView.mapType);
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:mapType forKey:kAVNSetting_MapViewType];
    [defaults synchronize];
}

- (void)reloadMapView
{
    NSMutableArray *annotations = @[].mutableCopy;
    NSMutableArray *overlays = @[].mutableCopy;
    
    [self.geometries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        KMLAbstractGeometry *geometry = (KMLAbstractGeometry *)obj;
        MKShape *mkShape = [geometry mapkitShape];
        if (mkShape) {
            if ([mkShape conformsToProtocol:@protocol(MKOverlay)]) {
                [overlays addObject:mkShape];
            } else if ([mkShape isKindOfClass:[MKPointAnnotation class]]) {
                [annotations addObject:mkShape];
            }
        }
    }];
    
    [self.mapView addAnnotations:annotations];
    [self.mapView addOverlays:overlays];
    
    // set zoom in next run loop
    dispatch_async(dispatch_get_main_queue(), ^{
        //
        // Thanks for elegant code!
        // https://gist.github.com/915374
        //
        __block MKMapRect zoomRect = MKMapRectNull;
        [self.mapView.annotations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id<MKAnnotation> annotation = (id<MKAnnotation>)obj;
            MKMapPoint annotationPoint = MKMapPointForCoordinate(annotation.coordinate);
            MKMapRect pointRect = MKMapRectMake(annotationPoint.x, annotationPoint.y, 0, 0);
            if (MKMapRectIsNull(zoomRect)) {
                zoomRect = pointRect;
            } else {
                zoomRect = MKMapRectUnion(zoomRect, pointRect);
            }
        }];
        [self.mapView setVisibleMapRect:MKMapRectInset(zoomRect, -1500.0f, -1500.0f) animated:YES];
    });
}


#pragma mark - MKMapView Delegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    }
    else if ([annotation isKindOfClass:[MKPointAnnotation class]]) {
        MKPointAnnotation *pointAnnotation = (MKPointAnnotation *)annotation;
        return [pointAnnotation annotationViewForMapView:mapView];
    }
    
    return nil;
}

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id<MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        return [(MKPolyline *)overlay overlayViewForMapView:mapView];
    }
    else if ([overlay isKindOfClass:[MKPolygon class]]) {
        return [(MKPolygon *)overlay overlayViewForMapView:mapView];
    }
    
    return nil;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    if ([view.annotation isKindOfClass:[MKPointAnnotation class]]) {
        MKPointAnnotation *pointAnnotation = (MKPointAnnotation *)view.annotation;
        CLLocation *annotationCoordinate = [[CLLocation alloc] initWithLatitude:pointAnnotation.coordinate.latitude
                                                                      longitude:pointAnnotation.coordinate.longitude];
        __block NSInteger waypointIndex = NSNotFound;
        
        if ((self.selectedRoute) && (self.selectedRoute.waypoints)) {
            [self.selectedRoute.waypoints enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                AVNWaypoint *waypoint = (AVNWaypoint *)obj;
                CLLocationDistance distance = [waypoint.gpsCoordinate distanceFromLocation:annotationCoordinate];
                if (distance<25.0 ) {
                    waypointIndex = idx;
                    *stop = YES;
                }
            }];
        }
        
        if (waypointIndex != NSNotFound) {
            // Get the tapped waypoint
            self.tappedWaypoint = self.selectedRoute.waypoints[waypointIndex];
            [self performSegueWithIdentifier:kSegueRouteMapSpecificWaypointTapped sender:self];
        }
    }
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:kSegueRouteMapToStartRouteAtFirstWaypoint]) {
        // Try to get indicated start waypoint
        __block AVNWaypoint *startWaypoint = nil;
        if (self.selectedRoute && self.selectedRoute.waypoints &&
            ([self.selectedRoute.waypoints count]>0) && (self.selectedRoute.startWaypoint)) {
            
            NSString *startID = self.selectedRoute.startWaypoint;
            [self.selectedRoute.waypoints enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                AVNWaypoint *wp = (AVNWaypoint *)obj;
                if ([wp.identifier isEqualToString:startID]) {
                    startWaypoint = wp;
                    *stop = YES;
                }
            }];
            
            // If the start waypoint has not been found, just select the first one available
            startWaypoint = startWaypoint?:self.selectedRoute.waypoints[0];
        }
        
        if (startWaypoint)
            [[segue destinationViewController] setSelectedWaypoint:startWaypoint];
        
    } else if ([[segue identifier] isEqualToString:kSegueRouteMapToFindNearestWaypoint]) {
        
        if (self.selectedRoute) {
            // Set the currently selected route to find nearest waypoint
            [[segue destinationViewController] setSelectedRouteToDetermineNearestWaypoint:self.selectedRoute];
            [[segue destinationViewController] setSelectedWaypoint:nil];
        }
        
    } else if ([[segue identifier] isEqualToString:kSegueRouteMapSpecificWaypointTapped]) {
        
        if (self.tappedWaypoint) {
            // The link to a specific waypoint has been tapped
            [[segue destinationViewController] setSelectedWaypoint:self.tappedWaypoint];
            self.tappedWaypoint = nil;
        }
        
    }
}

@end
