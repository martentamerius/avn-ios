//
//  AVNNewsItem.m
//  AVN
//
//  Created by Marten Tamerius on 21-05-14.
//  Copyright (c) 2014 AVN. All rights reserved.
//

#import "AVNNewsItem.h"

@implementation AVNNewsItem

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{ @"identifier": @"identifier",
              @"title": @"title",
              @"date": @"date",
              @"shortDescription": @"shortdescription",
              @"imageURL": @"imageURL",
              @"fullPageURL": @"fullpageURL" };
}

+ (NSDateFormatter *)dateFormatter {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter.dateFormat = @"dd-MM-yyyy";
    return dateFormatter;
}

+ (NSValueTransformer *)dateJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *dateString) {
        return [self.dateFormatter dateFromString:dateString];
    } reverseBlock:^(NSDate *date) {
        return [self.dateFormatter stringFromDate:date];
    }];
}

+ (NSValueTransformer *)imageURLJSONTransformer
{
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSValueTransformer *)fullPageURLJSONTransformer
{
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

@end
