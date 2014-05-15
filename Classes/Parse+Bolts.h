//
//  PFObject+Bolts.h
//  ParseSync
//
//  Created by Ahmed AlMoraly on 5/8/14.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "RMParseSync.h"
#import <Parse/Parse.h>

@interface PFObject (Bolts)

+ (BFTask *)saveAllAsync:(NSArray *)objects;

+ (BFTask *)deleteAllAsync:(NSArray *)objects;

+ (BFTask *)fetchAllAsync:(NSArray *)objects;


- (BFTask *)refreshAsync;

- (BFTask *)fetchAsync;

- (BFTask *)fetchIfNeededAsync;

- (BFTask *)deleteAsync;

- (BFTask *)saveAsync;

@end


@interface PFQuery (Bolts)

- (BFTask *)findObjectsAsync;

@end

@interface PFFile (Bolts)

- (BFTask *)getDataAsync;

- (BFTask *)getDataAsyncWithProgressBlock:(PFProgressBlock)progressBlock;

@end
