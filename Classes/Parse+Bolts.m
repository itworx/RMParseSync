//
//  PFObject+Bolts.m
//  ParseSync
//
//  Created by Ahmed AlMoraly on 5/8/14.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "Parse+Bolts.h"
#import <Bolts/Bolts.h>

@implementation PFObject (Bolts)

+ (BFTask *)saveAllAsync:(NSArray *)objects {
    BFTaskCompletionSource *saveAll = [BFTaskCompletionSource taskCompletionSource];
    
    [self saveAllInBackground:objects block:^(BOOL succeeded, NSError *error) {
        if (error) {
            [saveAll setError:error];
        }
        else {
            [saveAll setResult:@(succeeded)];
        }
    }];
    
    return saveAll.task;
}

+ (BFTask *)deleteAllAsync:(NSArray *)objects {
    BFTaskCompletionSource *deleteAll = [BFTaskCompletionSource taskCompletionSource];
    
    [self deleteAllInBackground:objects block:^(BOOL succeeded, NSError *error) {
        if (error) {
            [deleteAll setError:error];
        }
        else {
            [deleteAll setResult:@(succeeded)];
        }
    }];
    
    return deleteAll.task;
}

+ (BFTask *)fetchAllAsync:(NSArray *)objects {
    BFTaskCompletionSource *fetchAll = [BFTaskCompletionSource taskCompletionSource];
    [self fetchAllInBackground:objects block:^(NSArray *fetchedObjects, NSError *error) {
        if (error) {
            [fetchAll setError:error];
        }
        else {
            [fetchAll setResult:fetchedObjects];
        }
    }];
    
    return fetchAll.task;
}


- (BFTask *)refreshAsync {
    BFTaskCompletionSource *refresh = [BFTaskCompletionSource taskCompletionSource];
    
    [self refreshInBackgroundWithBlock:^(PFObject *object, NSError *error) {
        if (error) {
            [refresh setError:error];
        }
        else {
            [refresh setResult:object];
        }
    }];
    
    return refresh.task;
}

- (BFTask *)fetchAsync {
    BFTaskCompletionSource *fetch = [BFTaskCompletionSource taskCompletionSource];
    
    [self fetchInBackgroundWithBlock:^(PFObject *object, NSError *error) {
        if (error) {
            [fetch setError:error];
        }
        else {
            [fetch setResult:object];
        }
    }];
    
    return fetch.task;
}

- (BFTask *)fetchIfNeededAsync {
    BFTaskCompletionSource *fetch = [BFTaskCompletionSource taskCompletionSource];
    
    [self fetchIfNeededInBackgroundWithBlock:^(PFObject *object, NSError *error) {
        if (error) {
            [fetch setError:error];
        }
        else {
            [fetch setResult:object];
        }
    }];
    
    return fetch.task;
}

- (BFTask *)deleteAsync {
    BFTaskCompletionSource *delete = [BFTaskCompletionSource taskCompletionSource];
    
    [self deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (error) {
            [delete setError:error];
        }
        else {
            [delete setResult:@(succeeded)];
        }
    }];
    
    return delete.task;
}

- (BFTask *)saveAsync {
    BFTaskCompletionSource *save = [BFTaskCompletionSource taskCompletionSource];
    
    [self saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (error) {
            [save setError:error];
        }
        else {
            [save setResult:@(succeeded)];
        }
    }];
    
    return save.task;
}

@end

@implementation PFQuery (Bolts)

- (BFTask *)findObjectsAsync {
    BFTaskCompletionSource *find = [BFTaskCompletionSource taskCompletionSource];
    
    [self findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (error) {
            [find setError:error];
        }
        else {
            [find setResult:objects];
        }
    }];
    
    return find.task;
}

@end

@implementation PFFile (Bolts)

- (BFTask *)getDataAsync {
    BFTaskCompletionSource *getData = [BFTaskCompletionSource taskCompletionSource];
    
    [self getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        if (error) {
            [getData setError:error];
        }
        else {
            [getData setResult:data];
        }
    }];
    
    return getData.task;
}

- (BFTask *)getDataAsyncWithProgressBlock:(PFProgressBlock)progressBlock {
    BFTaskCompletionSource *getData = [BFTaskCompletionSource taskCompletionSource];
    
    [self getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        if (error) {
            [getData setError:error];
        }
        else {
            [getData setResult:data];
        }
    } progressBlock:progressBlock];
    
    return getData.task;
}

@end