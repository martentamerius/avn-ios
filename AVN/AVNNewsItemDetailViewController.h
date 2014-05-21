//
//  AVNNewsItemDetailViewController.h
//  AVN
//
//  Created by Marten Tamerius on 21-05-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AVNNewsItem.h"

@interface AVNNewsItemDetailViewController : UIViewController
@property (strong, nonatomic) AVNNewsItem *selectedNewsItem;
@end
