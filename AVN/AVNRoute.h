//
//  AVNRoute.h
//  AVN
//
//  Created by Marten Tamerius on 10-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Mantle.h>

@interface AVNRoute : MTLModel <MTLJSONSerializing>
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) NSString *title;
@property (nonatomic) double length;
@property (nonatomic, strong) NSURL *kmzDownloadURL;
@property (nonatomic, strong) NSString *startWaypoint;

@property (nonatomic, strong) NSArray *waypoints;

@end
