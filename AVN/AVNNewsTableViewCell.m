//
//  AVNNewsTableViewCell.m
//  AVN
//
//  Created by Marten Tamerius on 14-06-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNNewsTableViewCell.h"

@interface AVNNewsTableViewCell ()
@property (weak, nonatomic) IBOutlet UIImageView *unreadDotImageView;
@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;
@property (weak, nonatomic) IBOutlet UILabel *newsTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *newsSubtitleLabel;
@end

@implementation AVNNewsTableViewCell

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


#pragma mark - Setting the news item

- (void)setUnread:(BOOL)unread
{
    self.unreadDotImageView.hidden = (!unread);
}

- (void)setThumbnail:(UIImage *)thumbnail
{
    self.thumbnailImageView.image = (thumbnail)?:[UIImage imageNamed:@"newsitem_placeholder"];
}

- (void)setTitle:(NSString *)title
{
    self.newsTitleLabel.text = title;
}

- (void)setSubtitle:(NSString *)subtitle
{
    self.newsSubtitleLabel.text = subtitle;
}




@end
