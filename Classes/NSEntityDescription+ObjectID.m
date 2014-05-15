//
//  NSEntityDescription+ObjectID.m
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-06.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "NSEntityDescription+ObjectID.h"

@implementation NSEntityDescription (ObjectID)

- (NSString*) entityIDField {
    return [[[self name ] lowercaseString] stringByAppendingString:@"ID"];
}

@end
