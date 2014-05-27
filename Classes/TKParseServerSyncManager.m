//
//  TKParseServerSyncManager.m
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-18.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "TKParseServerSyncManager.h"
#import "TKServerObject.h"
#import "TKDBCacheManager.h"
#import <Bolts/Bolts.h>
#import "Parse+Bolts.h"

@implementation TKParseServerSyncManager

- (TKServerObject*) serverObjectBasicInfoForParseObject:(PFObject*)parseObject {
    TKServerObject *serverObject = [[TKServerObject alloc] init];
    serverObject.entityName = parseObject.parseClassName;
    serverObject.uniqueObjectID = [parseObject valueForKey:kTKDBUniqueIDField];
    serverObject.serverObjectID = parseObject.objectId;
    serverObject.creationDate = parseObject.createdAt;
    serverObject.lastModificationDate = [parseObject valueForKey:kTKDBUpdatedDateField];
    serverObject.isDeleted = [[parseObject valueForKey:kTKDBIsDeletedField] boolValue];
    return serverObject;
}


- (PFObject*) newParseObjectBasicInfoForServerObject:(TKServerObject*)serverObject {
    PFObject *object = [PFObject objectWithClassName:serverObject.entityName];
    
    NSMutableDictionary *dictAttributes = [serverObject.attributeValues mutableCopy];
    [dictAttributes removeObjectsForKeys:@[kTKDBCreatedDateField, kTKDBServerIDField]];
    [dictAttributes setObject:@(serverObject.isDeleted) forKey:kTKDBIsDeletedField];
    [dictAttributes setObject:serverObject.uniqueObjectID forKey:kTKDBUniqueIDField];
    [object setValuesForKeysWithDictionary:dictAttributes];
    return object;
}

- (PFObject*) existingParseObjectBasicInfoForServerObject:(TKServerObject*)serverObject {
    PFObject *object = [PFObject objectWithoutDataWithClassName:serverObject.entityName objectId:serverObject.serverObjectID];
    
    NSMutableDictionary *dictAttributes = [serverObject.attributeValues mutableCopy];
    [dictAttributes removeObjectsForKeys:@[kTKDBCreatedDateField, kTKDBServerIDField]];
    [dictAttributes setObject:@(serverObject.isDeleted) forKey:kTKDBIsDeletedField];
    [dictAttributes setObject:serverObject.uniqueObjectID forKey:kTKDBUniqueIDField];
    [object setValuesForKeysWithDictionary:dictAttributes];
    return object;
}

- (BFTask *)serverObjectForParseObjectAsync:(PFObject *)parseObject {
    
    return [[BFTask taskWithResult:nil] continueWithBlock:^id(BFTask *task) {
        
        TKServerObject *serverObject = [self serverObjectBasicInfoForParseObject:parseObject];
        
        NSMutableDictionary *dictAttributes = [NSMutableDictionary dictionary];
        NSMutableDictionary *relatedObjects = [NSMutableDictionary dictionary];
        
        NSMutableArray *tasks = @[].mutableCopy;
        
        for (NSString *key in [parseObject allKeys]) {
            if ([key isEqualToString:kTKDBIsDeletedField]) {
                continue;
            }
            
            BFTaskCompletionSource *subTask = [BFTaskCompletionSource taskCompletionSource];
            
            if ([[parseObject valueForKey:key] isKindOfClass:[PFObject class]]) {

                PFObject *relatedObject = [parseObject valueForKey:key];
                
                [[relatedObject tk_refreshAsync] continueWithBlock:^id(BFTask *task) {
                    if (task.isCancelled) {
                        [subTask cancel];
                    }
                    else if (task.error) {
                        [subTask setError:task.error];
                    }
                    else {
                        PFObject *object = task.result;
                        TKServerObject *toOneServerObject = [self serverObjectBasicInfoForParseObject:object];
                        if (toOneServerObject.isDeleted) {
                            [relatedObjects setObject:[NSNull null] forKey:key];
                        }
                        else {
                            [relatedObjects setObject:toOneServerObject forKey:key];
                        }
                        [subTask setResult:toOneServerObject];
                    }
                    return nil;
                }];
            }
            else if ([[parseObject valueForKey:key] isKindOfClass:[PFRelation class]]) {
                
                PFRelation *relation = [parseObject relationForKey:key];
                // get related objects using [relation query]
                PFQuery *query = [relation query];
                
                [[query tk_findObjectsAsync] continueWithBlock:^id(BFTask *task) {
                    if (task.isCancelled) {
                        [subTask cancel];
                    }
                    else if (task.error) {
                        [subTask setError:task.error];
                    }
                    else {
                        NSArray *parseObjects = task.result;
                        NSMutableArray *arrServerObjects = [NSMutableArray array];
                        
                        for (PFObject *relatedObject in parseObjects) {
                            TKServerObject *serverRelatedObject = [self serverObjectBasicInfoForParseObject:relatedObject];
                            if (!serverRelatedObject.isDeleted) {
                                [arrServerObjects addObject:serverRelatedObject];
                            }
                        }
                        [relatedObjects setObject:arrServerObjects forKey:key];
                        [subTask setResult:arrServerObjects];
                    }
                    return nil;
                }];
            }
            else {
                id value = [parseObject valueForKey:key];
                [dictAttributes setValue:value forKey:key];
                [subTask setResult:value];
            }
            [tasks addObject:subTask.task];
        }
        return [[BFTask taskForCompletionOfAllTasks:tasks] continueWithBlock:^id(BFTask *task) {
            // this will be executed after *all* the group tasks have completed
            if (task.error) {
                return [BFTask taskWithError:task.error];
            }
            else {
                serverObject.attributeValues = dictAttributes;
                serverObject.relatedObjects = relatedObjects;
                
                return [BFTask taskWithResult:serverObject];
            }
        }];
    }];
}

- (TKServerObject*) serverObjectForParseObject:(PFObject*)parseObject {
    TKServerObject *serverObject = [self serverObjectBasicInfoForParseObject:parseObject];
    
    NSMutableDictionary *dictAttributes = [NSMutableDictionary dictionary];
    NSMutableDictionary *relatedObjects = [NSMutableDictionary dictionary];
    
    for (NSString* key in [parseObject allKeys]) {
        
        if ([key isEqualToString:kTKDBIsDeletedField] || [key isEqualToString:kTKDBUniqueIDField]) {
            continue;
        }
        
        if ([[parseObject valueForKey:key] isKindOfClass:[PFObject class]]) {
            PFObject *relatedObject = [parseObject valueForKey:key];
            [relatedObject refresh];
            TKServerObject *toOneServerObject = [self serverObjectBasicInfoForParseObject:relatedObject];
            if (toOneServerObject.isDeleted) {
                [relatedObjects setObject:[NSNull null] forKey:key];
            }
            else {
                [relatedObjects setObject:toOneServerObject forKey:key];
            }
        }
        else if ([[parseObject valueForKey:key] isKindOfClass:[PFRelation class]]) {
            PFRelation *relation = [parseObject relationForKey:key];
            // get related objects using [relation query]
            PFQuery *query = [relation query];
            NSArray *parseObjects = [query findObjects];
            NSMutableArray *arrServerObjects = [NSMutableArray array];
            
            for (PFObject *relatedObject in parseObjects) {
                TKServerObject *serverRelatedObject = [self serverObjectBasicInfoForParseObject:relatedObject];
                if (!serverRelatedObject.isDeleted) {
                    [arrServerObjects addObject:serverRelatedObject];
                }
            }
            
            [relatedObjects setObject:arrServerObjects forKey:key];
        }
        else {
            [dictAttributes setValue:[parseObject valueForKey:key] forKey:key];
        }
    }
    
    serverObject.attributeValues = dictAttributes;
    serverObject.relatedObjects = relatedObjects;
    return serverObject;
}

- (void) uploadInsertedObjects:(NSArray*)serverObjects withSuccessBlock:(TKSyncSuccessBlock)successBlock andFailureBlock:(TKSyncFailureBlock)failureBlock {
    NSMutableDictionary __block *dictServerObjects = [NSMutableDictionary dictionary];
    NSMutableArray __block *arrayParseObjects = [NSMutableArray array];
    
    if ([serverObjects count] == 0) {
        successBlock([NSArray array]);
        return;
    }
    
    for (TKServerObject *serverObject in serverObjects) {
        // Put the object in the dictionary to be later retrieved for setting relationships.
        [dictServerObjects setObject:serverObject forKey:serverObject.uniqueObjectID];
        
        // Create Parse object.
        PFObject *object = [self newParseObjectBasicInfoForServerObject:serverObject];
        [arrayParseObjects addObject:object];
    }
    
    [PFObject saveAllInBackground:arrayParseObjects block:^(BOOL succeeded, NSError *error) {
        if (error) {
            failureBlock(nil, error);
        }
        else {
            // Save all server IDs of objects to their respective server objects.
            for (PFObject *parseObject in arrayParseObjects) {
                NSString *uniqueID = [parseObject valueForKey:kTKDBUniqueIDField];
                TKServerObject *serverObject = (TKServerObject*)dictServerObjects[uniqueID];
                serverObject.serverObjectID = [parseObject objectId];
                [[TKDBCacheManager sharedManager] mapServerObjectWithID:serverObject.serverObjectID toUniqueObjectWithID:serverObject.uniqueObjectID];
            }
            
            successBlock([dictServerObjects allValues]);
        }
    }];
}

- (BFTask *)uploadInsertedObjectsAsync:(NSArray *)serverObjects {
    BFTaskCompletionSource *task = [BFTaskCompletionSource taskCompletionSource];
    
    if ([serverObjects count] == 0) {
        [task setResult:@[]];
    }
    else {
        NSMutableDictionary __block *dictServerObjects = [NSMutableDictionary dictionary];
        NSMutableArray __block *arrayParseObjects = [NSMutableArray array];
        
        for (TKServerObject *serverObject in serverObjects) {
            // Put the object in the dictionary to be later retrieved for setting relationships.
            [dictServerObjects setObject:serverObject forKey:serverObject.uniqueObjectID];
            
            // Create Parse object.
            PFObject *object = [self newParseObjectBasicInfoForServerObject:serverObject];
            [arrayParseObjects addObject:object];
        }
        
        [PFObject saveAllInBackground:arrayParseObjects block:^(BOOL succeeded, NSError *error) {
            if (error) {
                [task setError:error];
            }
            else {
                for (PFObject *parseObject in arrayParseObjects) {
                    NSString *uniqueID = [parseObject valueForKey:kTKDBUniqueIDField];
                    TKServerObject *serverObject = (TKServerObject *)dictServerObjects[uniqueID];
                    serverObject.serverObjectID = [parseObject objectId];
                    [[TKDBCacheManager sharedManager] mapServerObjectWithID:serverObject.serverObjectID toUniqueObjectWithID:serverObject.uniqueObjectID];
                }
                
                [task setResult:[dictServerObjects allValues]];
            }
        }];
    }
    
    return task.task;
}

- (void) downloadUpdatedObjectsForEntity:(NSString*)entityName withSuccessBlock:(TKSyncSuccessBlock)successBlock andFailureBlock:(TKSyncFailureBlock)failureBlock {
    PFQuery *query = [PFQuery queryWithClassName:entityName];
    [query whereKey:@"updatedAt" greaterThan:[TKDB defaultDB].lastSyncDate];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (error) {
            failureBlock(nil, error);
        }
        else {
            NSMutableArray *arrayServerObjects = [NSMutableArray array];
            
            // Convert objects to server objects.
            for (PFObject *parseObject in objects) {
                TKServerObject *serverObject = [self serverObjectForParseObject:parseObject];
                [arrayServerObjects addObject:serverObject];
                [[TKDBCacheManager sharedManager] mapServerObjectWithID:serverObject.serverObjectID toUniqueObjectWithID:serverObject.uniqueObjectID];
            }
            
            successBlock(arrayServerObjects);
        }
    }];
}

- (BFTask *)downloadUpdatedObjectsAsyncForEntity:(NSString *)entityName {
    return [[BFTask taskWithResult:nil] continueWithBlock:^id(BFTask *task) {
        
        PFQuery *query = [PFQuery queryWithClassName:entityName];
        [query whereKey:@"updatedAt" greaterThan:[TKDB defaultDB].lastSyncDate];
        
        return [[query tk_findObjectsAsync] continueWithSuccessBlock:^id(BFTask *task) {
            
            NSMutableArray *arrayServerObjects = [NSMutableArray array];
            NSArray *parseObjects = task.result;
            NSMutableArray *tasks = @[].mutableCopy;
            
            // Convert objects to server objects.
            for (PFObject *parseObject in parseObjects) {
                
                BFTaskCompletionSource *subTask = [BFTaskCompletionSource taskCompletionSource];
                
                [[self serverObjectForParseObjectAsync:parseObject] continueWithBlock:^id(BFTask *_task) {
                    if (_task.error) {
                        [subTask setError:_task.error];
                    }
                    else {
                        TKServerObject *serverObject = _task.result;
                        [arrayServerObjects addObject:serverObject];
                        [[TKDBCacheManager sharedManager] mapServerObjectWithID:serverObject.serverObjectID toUniqueObjectWithID:serverObject.uniqueObjectID];
                        [subTask setResult:serverObject];
                    }
                    
                    return nil;
                }];
                
                [tasks addObject:subTask.task];
            }
            
            return [[BFTask taskForCompletionOfAllTasks:tasks] continueWithBlock:^id(BFTask *task) {
                // this will be executed after *all* the group tasks have completed
                if (task.error) {
                    return [BFTask taskWithError:task.error];
                }
                else {
                    return [BFTask taskWithResult:arrayServerObjects];
                }
            }];
        }];
    }];
}

- (void) uploadUpdatedObjects:(NSArray*)serverObjects WithSuccessBlock:(TKSyncSuccessBlock)successBlock andFailureBlock:(TKSyncFailureBlock)failureBlock {
    NSMutableArray *parseObjects = [NSMutableArray array];
    
    if ([serverObjects count] == 0) {
        successBlock([NSArray array]);
        return;
    }
    
    for (TKServerObject *serverObject in serverObjects) {
        PFObject *parseObject = [self existingParseObjectBasicInfoForServerObject:serverObject];
        [parseObject fetchIfNeeded];
        
        for (NSString *key in serverObject.relatedObjects) {
            if ([serverObject.relatedObjects[key] isKindOfClass:[TKServerObject class]]) {
                TKServerObject *relatedServerObject = serverObject.relatedObjects[key];
                NSString *serverObjectID = (relatedServerObject.serverObjectID == nil) ? [[TKDBCacheManager sharedManager] serverObjectIDForUniqueObjectID:relatedServerObject.uniqueObjectID] : relatedServerObject.serverObjectID;
                PFObject *relatedParseObject = [PFObject objectWithoutDataWithClassName:relatedServerObject.entityName objectId:serverObjectID];
                [parseObject setValue:relatedParseObject forKey:key];
            }
            else if ([serverObject.relatedObjects[key] isKindOfClass:[NSArray class]]) {
                PFRelation *relation = [parseObject relationForKey:key];
                NSArray *arrChildObjects = [[relation query] findObjects];
                for (PFObject *childObject in arrChildObjects) {
                    [relation removeObject:childObject];
                }
                
                for (TKServerObject *childObject in serverObject.relatedObjects[key]) {
                    NSString *serverObjectID = (childObject.serverObjectID == nil) ? [[TKDBCacheManager sharedManager] serverObjectIDForUniqueObjectID:childObject.uniqueObjectID] : childObject.serverObjectID;
                    [relation addObject:[PFObject objectWithoutDataWithClassName:childObject.entityName objectId:serverObjectID]];
                }
            }
            else if (serverObject.relatedObjects[key] == [NSNull null]) {
                [parseObject removeObjectForKey:key];
            }
        }
        
        [parseObjects addObject:parseObject];
    }
    
    [PFObject saveAllInBackground:parseObjects block:^(BOOL succeeded, NSError *error) {
        if (error) {
            failureBlock(nil, error);
        }
        else {
            successBlock(parseObjects);
        }
    }];
}

- (BFTask *)uploadUpdatedObjectsAsync:(NSArray *)serverObjects {
    
    if ([serverObjects count] == 0) {
        return [BFTask taskWithResult:@[]];
    }
    
    return [[BFTask taskWithResult:nil] continueWithBlock:^id(BFTask *task) {
        NSMutableArray __block *parseObjects = [NSMutableArray array];
        
        NSMutableArray __block *fetchTasks = @[].mutableCopy;
        // get the Parse object
        for (TKServerObject *serverObject in serverObjects) {

            BFTaskCompletionSource *fetchTask = [BFTaskCompletionSource taskCompletionSource];

            PFObject *parseObj = [self existingParseObjectBasicInfoForServerObject:serverObject];
            
            [[parseObj tk_fetchIfNeededAsync] continueWithSuccessBlock:^id(BFTask *task) {
                PFObject *parseObject = task.result;
                
                // enumerate and get the related object(s)
                
                NSMutableArray __block *relationTasks = @[].mutableCopy;
                
                for (NSString *key in serverObject.relatedObjects) {
                    
                    BFTaskCompletionSource *relationTask = [BFTaskCompletionSource taskCompletionSource];
                    
                    // to-one relation
                    if ([serverObject.relatedObjects[key] isKindOfClass:[TKServerObject class]]) {
                        TKServerObject *relatedServerObject = serverObject.relatedObjects[key];
                        NSString *serverObjectID = (relatedServerObject.serverObjectID == nil) ? [[TKDBCacheManager sharedManager] serverObjectIDForUniqueObjectID:relatedServerObject.uniqueObjectID] : relatedServerObject.serverObjectID;
                        PFObject *relatedParseObject = [PFObject objectWithoutDataWithClassName:relatedServerObject.entityName objectId:serverObjectID];
                        [parseObject setValue:relatedParseObject forKey:key];
                        
                        [relationTask setResult:parseObject];
                    }
                    // to-Many relation
                    else if ([serverObject.relatedObjects[key] isKindOfClass:[NSArray class]]) {
                        PFRelation *relation = [parseObject relationForKey:key];
                        // get all objects
                        [[[relation query] tk_findObjectsAsync] continueWithSuccessBlock:^id(BFTask *task) {
                            NSArray *arrChildObjects = task.result;
                            
                            for (PFObject *childObject in arrChildObjects) {
                                [relation removeObject:childObject];
                            }
                            
                            for (TKServerObject *childObject in serverObject.relatedObjects[key]) {
                                NSString *serverObjectID = (childObject.serverObjectID == nil) ? [[TKDBCacheManager sharedManager] serverObjectIDForUniqueObjectID:childObject.uniqueObjectID] : childObject.serverObjectID;
                                [relation addObject:[PFObject objectWithoutDataWithClassName:childObject.entityName objectId:serverObjectID]];
                            }
                            
                            [relationTask setResult:nil];
                            return nil;
                        }];
                    }
                    // nil relation
                    else if ([serverObject.relatedObjects[key] isEqual:[NSNull null]]) {
                        [parseObject removeObjectForKey:key];
                        [relationTask setResult:parseObject];
                    }
                    
                    [relationTasks addObject:relationTask.task];
                }
                
                return [[BFTask taskForCompletionOfAllTasks:relationTasks] continueWithBlock:^id(BFTask *task) {
                    // this will be executed after *all* the group tasks have completed
                    if (task.error) {
                        [fetchTask setError:task.error];
                        return [BFTask taskWithError:task.error];
                    }
                    else {
                        [parseObjects addObject:parseObject];
                        [fetchTask setResult:parseObject];
                        return [BFTask taskWithResult:parseObject];
                    }
                }];
            }];
            
            [fetchTasks addObject:fetchTask.task];
        }
        
        return [[BFTask taskForCompletionOfAllTasks:fetchTasks] continueWithBlock:^id(BFTask *task) {
            // this will be executed after *all* the group tasks have completed
            if (task.error) {
                return [BFTask taskWithError:task.error];
            }
            else {
                return [[BFTask taskWithResult:parseObjects] continueWithBlock:^id(BFTask *task) {
                    // save those objects
                    return [PFObject tk_saveAllAsync:task.result];
                }];
            }
        }];
    }];
}


- (BFTask *)_uploadUpdatedObjectsAsync:(NSArray *)serverObjects {
    BFTaskCompletionSource *task = [BFTaskCompletionSource taskCompletionSource];
    
    if ([serverObjects count] == 0) {
        [task setResult:@[]];
    }
    else {
        NSMutableArray *parseObjects = [NSMutableArray array];
        for (TKServerObject *serverObject in serverObjects) {
            PFObject *parseObject = [self existingParseObjectBasicInfoForServerObject:serverObject];
            [parseObject fetchIfNeeded];
            
            for (NSString *key in serverObject.relatedObjects) {
                if ([serverObject.relatedObjects[key] isKindOfClass:[TKServerObject class]]) {
                    TKServerObject *relatedServerObject = serverObject.relatedObjects[key];
                    NSString *serverObjectID = (relatedServerObject.serverObjectID == nil) ? [[TKDBCacheManager sharedManager] serverObjectIDForUniqueObjectID:relatedServerObject.uniqueObjectID] : relatedServerObject.serverObjectID;
                    PFObject *relatedParseObject = [PFObject objectWithoutDataWithClassName:relatedServerObject.entityName objectId:serverObjectID];
                    [parseObject setValue:relatedParseObject forKey:key];
                }
                else if ([serverObject.relatedObjects[key] isKindOfClass:[NSArray class]]) {
                    PFRelation *relation = [parseObject relationForKey:key];
                    NSArray *arrChildObjects = [[relation query] findObjects];
                    for (PFObject *childObject in arrChildObjects) {
                        [relation removeObject:childObject];
                    }
                    
                    for (TKServerObject *childObject in serverObject.relatedObjects[key]) {
                        NSString *serverObjectID = (childObject.serverObjectID == nil) ? [[TKDBCacheManager sharedManager] serverObjectIDForUniqueObjectID:childObject.uniqueObjectID] : childObject.serverObjectID;
                        [relation addObject:[PFObject objectWithoutDataWithClassName:childObject.entityName objectId:serverObjectID]];
                    }
                }
                else if (serverObject.relatedObjects[key] == [NSNull null]) {
                    [parseObject removeObjectForKey:key];
                }
            }
            
            [parseObjects addObject:parseObject];
        }
        
        [PFObject saveAllInBackground:parseObjects block:^(BOOL succeeded, NSError *error) {
            if (error) {
                [task setError:error];
            }
            else {
                [task setResult:parseObjects];
            }
        }];
        
    }
    return task.task;
}
@end
