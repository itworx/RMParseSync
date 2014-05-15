//
//  NSManagedObjectContext+Sync.h
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-21.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMParseSync.h"

@interface NSManagedObjectContext (Sync)

- (NSManagedObject *)objectWithURI:(NSURL *)uri;

@end
