//
//  AVNRootViewController.h
//  AVN
//
//  Created by Marten Tamerius on 22-04-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AVNRootViewController : UITabBarController
- (void)updateNewsItemBadge:(NSInteger)unreadItemCount;
@end
