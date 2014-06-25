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

+ (BFTask *)tk_saveAllAsync:(NSArray *)objects {
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

+ (BFTask *)tk_deleteAllAsync:(NSArray *)objects {
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

+ (BFTask *)tk_fetchAllAsync:(NSArray *)objects {
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


- (BFTask *)tk_refreshAsync {
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

- (BFTask *)tk_fetchAsync {
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

- (BFTask *)tk_fetchIfNeededAsync {
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

- (BFTask *)tk_deleteAsync {
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

- (BFTask *)tk_saveAsync {
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

- (BFTask *)tk_findObjectsAsync {
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

- (BFTask *)tk_countOfObjectsAsync {
    BFTaskCompletionSource *countTask = [BFTaskCompletionSource taskCompletionSource];
    
    [self countObjectsInBackgroundWithBlock:^(int number, NSError *error) {
        if (error) {
            [countTask setError:error];
        }
        else {
            [countTask setResult:@(number)];
        }
    }];
    
    return countTask.task;
}

@end

@implementation PFFile (Bolts)

- (BFTask *)tk_saveAsync {
    BFTaskCompletionSource *upload = [BFTaskCompletionSource taskCompletionSource];
    
    [self saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (error) {
            [upload setError:error];
        }
        else {
            [upload setResult:@(succeeded)];
        }
    }];
    
    return upload.task;
}

- (BFTask *)tk_getDataAsync {
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

- (BFTask *)tk_getDataAsyncWithProgressBlock:(PFProgressBlock)progressBlock {
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