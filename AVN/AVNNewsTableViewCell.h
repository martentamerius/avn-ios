//
//  AVNNewsTableViewCell.h
//  AVN
//
//  Created by Marten Tamerius on 14-06-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AVNNewsTableViewCell : UITableViewCell
- (void)setUnread:(BOOL)unread;
- (void)setThumbnail:(UIImage *)thumbnail;
- (void)setTitle:(NSString *)title;
- (void)setSubtitle:(NSString *)subtitle;
@end
