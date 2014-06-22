//
//  AVNRouteListTableViewCell.m
//  AVN
//
//  Created by Marten Tamerius on 20-06-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNRouteListTableViewCell.h"

@implementation AVNRouteListTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
