//
//  AVNRouteListTableViewCell.h
//  AVN
//
//  Created by Marten Tamerius on 20-06-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AVNRouteListTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *routeTitle;
@property (weak, nonatomic) IBOutlet UILabel *routeLength;
@end
