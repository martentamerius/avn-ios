//
//  AVNNewsItem.h
//  AVN
//
//  Created by Marten Tamerius on 21-05-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Mantle.h>

@interface AVNNewsItem : MTLModel <MTLJSONSerializing>
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) NSString *shortDescription;
@property (nonatomic, strong) NSURL *imageURL;
@property (nonatomic, strong) NSURL *fullPageURL;
@end
