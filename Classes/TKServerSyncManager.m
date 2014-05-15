//
//  TKServerSyncManager.m
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-18.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "TKServerSyncManager.h"

@implementation TKServerSyncManager

- (NSArray*) toManyRelationshipKeysForEntity:(NSString*)name {
    NSMutableArray *arrRelationships = [NSMutableArray array];
    NSDictionary* relationships = [[NSEntityDescription entityForName:name inManagedObjectContext:[TKDB defaultDB].rootContext] relationshipsByName];
    
    for (NSString *key in [relationships allKeys]) {
        NSRelationshipDescription *description = relationships[key];
        if (description.isToMany) {
            [arrRelationships addObject:key];
        }
    }
    return arrRelationships;
}

- (void)uploadInsertedObjects:(NSArray *)serverObjects withSuccessBlock:(TKSyncSuccessBlock)successBlock andFailureBlock:(TKSyncFailureBlock)failureBlock {
    
}

- (BFTask *)uploadInsertedObjectsAsync:(NSArray *)serverObjects {
    return nil;
}

- (void)uploadUpdatedObjects:(NSArray *)serverObjects WithSuccessBlock:(TKSyncSuccessBlock)successBlock andFailureBlock:(TKSyncFailureBlock)failureBlock {
    
}

- (BFTask *)uploadUpdatedObjectsAsync:(NSArray *)serverObjects {
    return nil;
}

- (BFTask *)downloadUpdatedObjectsAsyncForEntity:(NSString *)entityName {
    return nil;
}

- (void)downloadUpdatedObjectsForEntity:(NSString *)entityName withSuccessBlock:(TKSyncSuccessBlock)successBlock andFailureBlock:(TKSyncFailureBlock)failureBlock {
    
}

@end
