
//
//  AVNMapViewController.m
//  AVN
//
//  Created by Marten Tamerius on 11-06-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNMapViewController.h"
#import <MapKit/MapKit.h>
#import "AVNAppDelegate.h"
#import "AVNWaypoint.h"
#import "AVNWaypointViewController.h"
#import "KML.h"
#import "KML+MapKit.h"
#import "MKMap+KML.h"
#import <MBProgressHUD.h>
#import <TSMessage.h>


@interface AVNMapViewController () <MKMapViewDelegate>
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *mapTypeControl;

@property (nonatomic, strong) NSArray *geometries;

@property (strong, nonatomic) AVNWaypoint *tappedWaypoint;
@end


@implementation AVNMapViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialize variables
        self.geometries = @[];
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setSelectedRoute:(AVNRoute *)selectedRoute
{
    if (_selectedRoute != selectedRoute) {
        [self willChangeValueForKey:@"selectedRoute"];
        _selectedRoute = selectedRoute;
        [self didChangeValueForKey:@"selectedRoute"];
        
        // Update the view
        if (self.selectedRoute && self.selectedRoute.kmzDownloadURL) {
            [self loadKMLForSelectedRoute];
        }
    }
}

- (void)setSelectedWaypoint:(AVNWaypoint *)selectedWaypoint
{
    if (_selectedWaypoint != selectedWaypoint) {
        [self willChangeValueForKey:@"selectedWaypoint"];
        _selectedWaypoint = selectedWaypoint;
        [self didChangeValueForKey:@"selectedWaypoint"];
        
        // Update the view
        if (self.selectedWaypoint && self.selectedWaypoint.parentRoute && self.selectedWaypoint.parentRoute.kmzDownloadURL) {
            [self loadKMLForRoute:self.selectedWaypoint.parentRoute];
        }
    }
}

- (void)dealloc
{
    // Remove self from notification center
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - UIView

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Set the map view type according user settings
    [self loadMapType];
}


#pragma mark - Map View URL

- (void)loadKMLForSelectedRoute
{
    [self loadKMLForRoute:self.selectedRoute];
}

- (void)loadKMLForRoute:(AVNRoute *)route
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
    
    // Set up completion block for work after asynchronous downloading of KML
    __weak AVNRoute *weakRoute = route;
    __weak typeof(self) weakSelf = self;
    void (^completionBlock)() = ^void() {
        if (weakRoute.kml) {
            weakSelf.geometries = weakRoute.kml.geometries;
            
            [MBProgressHUD hideAllHUDsForView:weakSelf.view animated:YES];
            weakSelf.navigationController.view.userInteractionEnabled = YES;
            
            [weakSelf reloadMapView];
            
        } else {
            [MBProgressHUD hideAllHUDsForView:weakSelf.view animated:YES];
            weakSelf.navigationController.view.userInteractionEnabled = YES;
            
            // Show error message to user
            [TSMessage showNotificationInViewController:weakSelf title:@"Laden van route-informatie is mislukt."
                                               subtitle:@""
                                                   type:TSMessageNotificationTypeError
                                               duration:5
                                   canBeDismissedByUser:YES];
        }
    };
    
    if ((!route.kml) && (route.kmzDownloadURL)) {
        // A KML/KMZ file exists, but has not yet been downloaded/parsed...
        [self.selectedRoute loadRouteKMLWithCompletionBlock:completionBlock];
    } else {
        // The KML has already been downloaded; just reuse it
        completionBlock();
    }
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
    NSNumber *mapType = [[NSUserDefaults standardUserDefaults] objectForKey:kAVNSetting_MapViewType];
    if (!mapType)
        mapType = @(0);
    
    self.mapView.mapType = [mapType integerValue];
    self.mapTypeControl.selectedSegmentIndex = [mapType integerValue];
}

- (void)saveMapType
{    
    [[NSUserDefaults standardUserDefaults] setObject:@(self.mapView.mapType) forKey:kAVNSetting_MapViewType];
    [[NSUserDefaults standardUserDefaults] synchronize];
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
    
    // Zoom out to complete route if a specific waypoint is not available
    BOOL zoomToFullRoute = (self.selectedWaypoint==nil);
    
    // set zoom in next run loop
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __block MKMapRect zoomRect = MKMapRectNull;
        [weakSelf.mapView.annotations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id<MKAnnotation> annotation = (id<MKAnnotation>)obj;
            BOOL shouldAddPoint = (zoomToFullRoute && (annotation != weakSelf.mapView.userLocation));
            double zoomInset = -800.0f;
            
            if (weakSelf.selectedWaypoint) {
                CLLocationCoordinate2D annCoord = annotation.coordinate;
                CLLocation *annLocation = [[CLLocation alloc] initWithLatitude:annCoord.latitude longitude:annCoord.longitude];
                CLLocationDistance distanceFromSelection = [weakSelf.selectedWaypoint.gpsCoordinate distanceFromLocation:annLocation];

                shouldAddPoint |= (distanceFromSelection<25.0);
                if (shouldAddPoint)
                    zoomInset *= 2;
            }
            
            if (shouldAddPoint) {
                MKMapPoint annotationPoint = MKMapPointForCoordinate(annotation.coordinate);
                MKMapRect pointRect = MKMapRectMake(annotationPoint.x+zoomInset, annotationPoint.y+zoomInset, (-2*zoomInset), (-2*zoomInset));
                if (MKMapRectIsNull(zoomRect)) {
                    zoomRect = pointRect;
                } else {
                    zoomRect = MKMapRectInset(MKMapRectUnion(zoomRect, pointRect), zoomInset, zoomInset);
                }
            }
        }];
        
        [self.mapView setVisibleMapRect:zoomRect animated:YES];
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

// for iOS7+; see 'viewForOverlay' for earlier versions
- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MKPolygon class]]) {
        MKPolygonRenderer *renderer = [[MKPolygonRenderer alloc] initWithPolygon:overlay];
        renderer.fillColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2];
        renderer.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
        renderer.lineWidth = 3;
        
        return renderer;
    }
    
    if ([overlay isKindOfClass:[MKCircle class]]) {
        MKCircleRenderer *renderer = [[MKCircleRenderer alloc] initWithCircle:overlay];
        renderer.fillColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2];
        renderer.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
        renderer.lineWidth = 3;
        
        return renderer;
    }
    
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline:overlay];
        renderer.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
        renderer.lineWidth = 3;
        
        return renderer;
    }
    
    return nil;
}

// for iOS versions prior to 7; see 'rendererForOverlay' for iOS7 and later
- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MKPolygon class]]) {
        MKPolygonView *overlayView = [[MKPolygonView alloc] initWithPolygon:overlay];
        overlayView.fillColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2];
        overlayView.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
        overlayView.lineWidth = 3;
        
        return overlayView;
    }
    
    if ([overlay isKindOfClass:[MKCircle class]]) {
        MKCircleView *overlayView = [[MKCircleView alloc] initWithCircle:overlay];
        overlayView.fillColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2];
        overlayView.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
        overlayView.lineWidth = 3;
        
        return overlayView;
    }
    
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        MKPolylineView *overlayView = [[MKPolylineView alloc] initWithPolyline:overlay];
        overlayView.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
        overlayView.lineWidth = 3;
        
        return overlayView;
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
        NSArray *routeWaypoints;
    
        if (self.selectedRoute && self.selectedRoute.waypoints) {
            routeWaypoints = self.selectedRoute.waypoints;
        } else if (self.selectedWaypoint && self.selectedWaypoint.parentRoute) {
            routeWaypoints = self.selectedWaypoint.parentRoute.waypoints;
        }
        
        if (routeWaypoints) {
            [routeWaypoints enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
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
            self.tappedWaypoint = routeWaypoints[waypointIndex];
            if (!self.selectedWaypoint) {
                [self performSegueWithIdentifier:kSegueRouteMapSpecificWaypointTapped sender:self];
            } else {
                [self performSegueWithIdentifier:kSegueSpecificWaypointTappedOnWaypointMap sender:self];
            }
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
    } else if ([[segue identifier] isEqualToString:kSegueSpecificWaypointTappedOnWaypointMap]) {
        
        if (self.tappedWaypoint) {
            // The link to a specific waypoint has been tapped
            [[segue destinationViewController] setSelectedWaypoint:self.tappedWaypoint];
            self.tappedWaypoint = nil;
        }
    }
}

@end
