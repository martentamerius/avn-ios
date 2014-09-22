//
//  Storyboard.h
//  AVN
//
//  Created by Marten Tamerius on 11-06-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#ifndef AVN_Storyboard_h
#define AVN_Storyboard_h


#pragma mark - Storyboard Segues

// Route List View
#define kSegueRouteListToRouteDetail                    @"RouteListToRouteDetailSegue"

// Route Detail View
#define kSegueRouteDetailToStartRouteAtFirstWaypoint    @"RouteDetailToStartRouteAtFirstWaypointSegue"
#define kSegueRouteDetailToFindNearestWaypoint          @"RouteDetailToFindNearestWaypointSegue"
#define kSegueRouteDetailSpecificWaypointTapped         @"RouteDetailSpecificWaypointTappedSegue"
#define kSegueRouteDetailToMapView                      @"RouteDetailToMapViewSegue"

// Waypoint View
#define kSegueSpecificWaypointMapButtonTapped           @"SpecificWaypointMapButtonTappedSegue"

// Route Map View
#define kSegueRouteMapToStartRouteAtFirstWaypoint       @"RouteMapToStartRouteAtFirstWaypointSegue"
#define kSegueRouteMapToFindNearestWaypoint             @"RouteMapToFindNearestWaypointSegue"
#define kSegueRouteMapSpecificWaypointTapped            @"RouteMapSpecificWaypointTappedSegue"

// News TableView
#define kSegueNewsItemListToShowDetail                  @"NewsItemListToShowDetailSegue"



#pragma mark - TableView Cell Identifiers

// Route List TableView
#define kCellRouteDescription           @"CellRouteDescription"

// News TableView
#define kCellNewsItem                   @"CellNewsItem"


#endif
