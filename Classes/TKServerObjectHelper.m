//
//  TKServerObjectHelper.m
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-18.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "TKServerObjectHelper.h"
#import "TKDBCacheManager.h"
#import "TKServerObject.h"
#import "NSManagedObject+Sync.h"
#import "NSManagedObjectContext+Sync.h"

@implementation TKServerObjectHelper

+ (NSManagedObject*) managedObjectWithoutRelationshipsFromServerObject:(TKServerObject*)object {
    NSManagedObject *__block managedObject;
    NSManagedObjectContext __weak *weakSyncContext = [TKDB defaultDB].syncContext;
    
    [[TKDB defaultDB].syncContext performBlockAndWait:^{
        managedObject =[NSEntityDescription insertNewObjectForEntityForName:object.entityName inManagedObjectContext:weakSyncContext];
    }];

    [managedObject setValue:object.uniqueObjectID forKeyPath:kTKDBUniqueIDField];
    [managedObject setValue:object.serverObjectID forKey:kTKDBServerIDField];
    [managedObject setValue:object.creationDate forKey:kTKDBCreatedDateField];
    [managedObject setValue:object.lastModificationDate forKey:kTKDBUpdatedDateField];
    
    for (NSString *key in [object.attributeValues allKeys]) {
        if ([key isEqualToString:@"ACL"]) {
            continue;
        }
        [managedObject setValue:object.attributeValues[key] forKey:key];
    }
    
    return managedObject;
}

+ (void) wireRelationshipsForManagedObject:(NSManagedObject*)managedObject withServerObject:(TKServerObject*)serverObject {
    
    for (NSString *key in [serverObject.relatedObjects allKeys]) {
        if ([serverObject.relatedObjects[key] isKindOfClass:[TKServerObject class]]) {
            TKServerObject *relatedServerObject = serverObject.relatedObjects[key];
            if (relatedServerObject.isDeleted) {
                [managedObject setValue:nil forKey:key];
            }
            else {
                NSManagedObject *relatedManagedObject = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:[[TKDBCacheManager sharedManager] localObjectURLForUniqueObjectID:relatedServerObject.uniqueObjectID]]];
                [managedObject setValue:relatedManagedObject forKey:key];
            }
        }
        else if ([serverObject.relatedObjects[key] isKindOfClass:[NSArray class]]) {
            NSMutableSet *relatedObjects = [NSMutableSet set];
            for (TKServerObject *relatedServerObject in serverObject.relatedObjects[key]) {
                if (relatedServerObject.isDeleted) {
                    continue;
                }
                NSManagedObject *relatedManagedObject = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:[[TKDBCacheManager sharedManager] localObjectURLForUniqueObjectID:relatedServerObject.uniqueObjectID]]];
                [relatedObjects addObject:relatedManagedObject];
                [managedObject setValue:relatedObjects forKey:key];
            }
        }
        else if ([serverObject.relatedObjects[key] isEqual:[NSNull null]]) {
            [managedObject setValue:nil forKey:key];
        }
    }
}

+ (NSArray*)getInsertedObjectsFromCache {
    NSMutableArray *insertedObjects = [NSMutableArray array];
    TKDBCacheManager *manager = [TKDBCacheManager sharedManager];
    for (TKDBCacheEntry *entry in [[manager dictInserts] allValues]) {
        NSManagedObject *managedObject = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:entry.localObjectIDURL]];
        TKServerObject *serverObject = [managedObject toServerObject];
        [insertedObjects addObject:serverObject];
    }
    return insertedObjects;
}

+ (NSArray*)getUpdatedObjectsFromCache {
    NSMutableArray *updatedObjects = [NSMutableArray array];
    TKDBCacheManager *manager = [TKDBCacheManager sharedManager];
    for (TKDBCacheEntry *entry in [[manager dictUpdates] allValues]) {
        NSManagedObject *managedObject = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:entry.localObjectIDURL]];
        TKServerObject *serverObject = [managedObject toServerObject];
        [updatedObjects addObject:serverObject];
    }
    for (TKDBCacheEntry *entry in [[manager dictDeletes] allValues]) {
        TKServerObject *serverObject = [[TKServerObject alloc] init];
        serverObject.localObjectIDURL = entry.localObjectIDURL;
        serverObject.serverObjectID = entry.serverObjectID;
        serverObject.uniqueObjectID = entry.uniqueObjectID;
        serverObject.entityName = entry.entity;
        serverObject.isDeleted = YES;
        [updatedObjects addObject:serverObject];
    }
    return updatedObjects;
}

+ (void) insertServerObjectsInLocalDatabase:(NSArray*)serverObjects {
    NSMutableDictionary *dictManagedObjects = [NSMutableDictionary dictionary];
    
    if ([serverObjects count] == 0) {
        return;
    }
    
    // filter deleted objects
    serverObjects = [serverObjects filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TKServerObject *serverObject, NSDictionary *bindings) {
        if (serverObject.isDeleted) {
            // get it from local and delete
            NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:serverObject.entityName];
            request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kTKDBUniqueIDField, serverObject.uniqueObjectID];
            NSError *error;
            NSArray *objects = [[TKDB defaultDB].syncContext executeFetchRequest:request error:&error];
            if (objects.count == 1) {
                NSManagedObject *obj = [objects lastObject];
                [[TKDB defaultDB].syncContext deleteObject:obj];
            }
            else {
                // it doesn't exist then ignore
            }
            return NO;
        }
        else {
            return YES;
        }
    }]];
    
    // First, insert objects without wiring for relationships.
    for (TKServerObject *serverObject in serverObjects) {
        [dictManagedObjects setObject:[TKServerObjectHelper managedObjectWithoutRelationshipsFromServerObject:serverObject] forKey:serverObject.serverObjectID];
    }
    
    // Second, obtain permanent IDs and map them in the cache
    NSManagedObjectContext __weak *weakSyncContext = [TKDB defaultDB].syncContext;
    [[TKDB defaultDB].syncContext performBlockAndWait:^{
        [weakSyncContext obtainPermanentIDsForObjects:[dictManagedObjects allValues] error:nil];
    }];
    
    for (TKServerObject *serverObject in serverObjects) {
        NSManagedObject *object = dictManagedObjects[serverObject.serverObjectID];
        serverObject.localObjectIDURL = [[[object objectID] URIRepresentation] absoluteString];
        [[TKDBCacheManager sharedManager] mapLocalObjectWithURL:serverObject.localObjectIDURL toUniqueObjectWithID:serverObject.uniqueObjectID];
    }
    
    // Second, wire relationships.
    for (TKServerObject *serverObject in serverObjects) {
        NSManagedObject *object = dictManagedObjects[serverObject.serverObjectID];
        [TKServerObjectHelper wireRelationshipsForManagedObject:object withServerObject:serverObject];
    }
}

+ (void) updateServerIDInLocalDatabase:(NSArray*)serverObjects {
    for (TKServerObject *serverObject in serverObjects) {
        NSManagedObject *object = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:serverObject.localObjectIDURL]];
        [object setValue:serverObject.serverObjectID forKey:kTKDBServerIDField];
    }
}

+ (void) updateServerObjectsInLocalDatabase:(NSArray*)serverObjects {
    
    if ([serverObjects count] == 0) {
        return;
    }
   
    // Second, wire relationships.
    for (TKServerObject *serverObject in serverObjects) {
        NSManagedObject *object = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:[[TKDBCacheManager sharedManager] localObjectURLForUniqueObjectID:serverObject.uniqueObjectID]]];
        
        if (serverObject.isDeleted) {
            [[TKDB defaultDB].syncContext deleteObject:object];
        }
        else {
            for (NSString *key in serverObject.attributeValues) {
                if ([key isEqualToString:@"ACL"]) {
                    continue;
                }
                [object setValue:serverObject.attributeValues[key] forKey:key];
            }
            
            [TKServerObjectHelper wireRelationshipsForManagedObject:object withServerObject:serverObject];
        }
    }
}

+ (void) resolveConflict:(TKServerObjectConflictPair*)conflictPair localUpdates:(NSArray*)localUpdates serverUpdates:(NSArray*)serverUpdates {
    TKServerObject *newerObject;
    
    if ([conflictPair.localObject.lastModificationDate compare:conflictPair.serverObject.lastModificationDate] == NSOrderedAscending) {
        newerObject = conflictPair.serverObject;
    }
    else {
        newerObject = conflictPair.localObject;
    }
    
    TKServerObject *outputObject = [[TKServerObject alloc] initWithUniqueID:conflictPair.localObject.uniqueObjectID];
    outputObject.entityName = conflictPair.localObject.entityName;
    outputObject.creationDate = conflictPair.localObject.creationDate;
    outputObject.serverObjectID = conflictPair.serverObject.serverObjectID;
    outputObject.localObjectIDURL = conflictPair.localObject.localObjectIDURL;
    outputObject.lastModificationDate = [NSDate date];
    
    NSMutableDictionary *dictAttributes = [NSMutableDictionary dictionary];
    
    for (NSString *key in [conflictPair.localObject.attributeValues allKeys]) {
        
        id localValue = [conflictPair.localObject.attributeValues valueForKey:key];
        id serverValue = [conflictPair.serverObject.attributeValues valueForKey:key];
        id shadowValue = [conflictPair.shadowObject.attributeValues valueForKey:key];
        
        BOOL localChanged = ![localValue isEqual:shadowValue];
        BOOL serverChanged = ![serverValue isEqual:shadowValue];
        
        if (localChanged && serverChanged) {
            dictAttributes[key] = newerObject.attributeValues[key];
        }
        else if (localChanged) {
            dictAttributes[key] = localValue;
        }
        else if (serverChanged) {
            dictAttributes[key] = serverValue;
        }
        else {
            dictAttributes[key] = shadowValue;
        }
    }
    
    outputObject.attributeValues = dictAttributes;
    
    NSMutableDictionary *dictRelationships = [NSMutableDictionary dictionary];
    
    for (NSString *key in [conflictPair.localObject.relatedObjects allKeys]) {
        id localValue = [conflictPair.localObject.relatedObjects valueForKey:key];
        id serverValue = [conflictPair.serverObject.relatedObjects valueForKey:key];
        id shadowValue = [conflictPair.shadowObject.relatedObjects valueForKey:key];
        
        
        if ([localValue isKindOfClass:[NSArray class]]) {
            NSSet *localSet = [NSSet setWithArray:localValue];
            NSSet *serverSet = [NSSet setWithArray:serverValue];
            NSSet *shadowSet = [NSSet setWithArray:shadowValue];
            
            BOOL localChanged = ![localSet isEqualToSet:shadowSet];
            BOOL serverChanged = ![serverSet isEqualToSet:shadowSet];
            
            if (localChanged && serverChanged) {
                NSMutableSet *commonSet = [NSMutableSet setWithSet:localSet];
                [commonSet intersectSet:serverSet];
                
                NSMutableSet *localOnlySet = [NSMutableSet setWithSet:localSet];
                [localOnlySet minusSet:commonSet];
                
                NSMutableSet *serverOnlySet = [NSMutableSet setWithSet:serverSet];
                [serverOnlySet minusSet:commonSet];
                
                NSMutableSet *localAdditionsSet = [NSMutableSet setWithSet:localOnlySet];
                [localAdditionsSet minusSet:shadowSet];
                
                NSMutableSet *serverDeletionsSet = [NSMutableSet setWithSet:localOnlySet];
                [serverDeletionsSet minusSet:localAdditionsSet];
                
                NSMutableSet *serverAdditionsSet = [NSMutableSet setWithSet:serverOnlySet];
                [serverAdditionsSet minusSet:shadowSet];
                
                NSMutableSet *localDeletionsSet = [NSMutableSet setWithSet:serverOnlySet];
                [localDeletionsSet minusSet:serverAdditionsSet];
                
                [commonSet unionSet:localAdditionsSet];
                [commonSet unionSet:serverAdditionsSet];
                
                if (newerObject == conflictPair.localObject) {
                    // Rollback all server deletions except objects that weren't modified locally.
                    [serverDeletionsSet intersectSet:[NSSet setWithArray:localUpdates]];
                    [commonSet unionSet:serverDeletionsSet];
                }
                else {
                    // Rollback all local deletions except objects that weren't modified on server.
                    [localDeletionsSet intersectSet:[NSSet setWithArray:serverUpdates]];
                    [commonSet unionSet:localDeletionsSet];
                }
                
                dictRelationships[key] = [commonSet allObjects];
            }
            else if (localChanged) {
                dictRelationships[key] = localValue;
            }
            else if (serverChanged) {
                dictRelationships[key] = serverValue;
            }
            else {
                dictRelationships[key] = shadowValue;
            }
        }
        else {
            dictRelationships[key] = newerObject.relatedObjects[key];            
        }
    }
    
    outputObject.relatedObjects = dictRelationships;
    
    conflictPair.outputObject = outputObject;
    conflictPair.resolutionType = TKDBMergeBothUpdated;
}

@end
