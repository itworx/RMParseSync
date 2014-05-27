//
//  PFObject+Bolts.h
//  ParseSync
//
//  Created by Ahmed AlMoraly on 5/8/14.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "RMParseSync.h"

@interface PFObject (Bolts)

+ (BFTask *)tk_saveAllAsync:(NSArray *)objects;

+ (BFTask *)tk_deleteAllAsync:(NSArray *)objects;

+ (BFTask *)tk_fetchAllAsync:(NSArray *)objects;


- (BFTask *)tk_refreshAsync;

- (BFTask *)tk_fetchAsync;

- (BFTask *)tk_fetchIfNeededAsync;

- (BFTask *)tk_deleteAsync;

- (BFTask *)tk_saveAsync;

@end


@interface PFQuery (Bolts)

- (BFTask *)tk_findObjectsAsync;

@end

@interface PFFile (Bolts)

- (BFTask *)tk_getDataAsync;

- (BFTask *)tk_getDataAsyncWithProgressBlock:(PFProgressBlock)progressBlock;

@end