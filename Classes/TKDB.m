//
//  TKDB.m
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-19.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "TKDB.h"
#import "RMParseSync.h"
#import "TKParseServerSyncManager.h"
#import "TKServerObject.h"
#import "TKServerObjectHelper.h"
#import "TKDBCacheManager.h"
#import "NSManagedObject+Sync.h"
#import "NSManagedObjectContext+Sync.h"
#ifdef COCOAPODS
#import <DDLog.h>
#else
#import "DDLog.h"
#endif

int ddLogLevel = LOG_LEVEL_VERBOSE;

NSString * const TKDBSyncDidSucceedNotification = @"TKDBSyncDidSucceedNotification";
NSString * const TKDBSyncFailedNotification = @"TKDBSyncFailedNotification";

@interface TKDB ()
@property (nonatomic, strong) TKParseServerSyncManager *manager;
@end

@implementation TKDB {
    /**
     *  Used to stop notifications form firing during sync.
     */
    BOOL disableNotifications;
}

+ (instancetype)defaultDB
{
    static dispatch_once_t pred = 0;
    __strong static TKDB* _defaultDB = nil;
    dispatch_once(&pred, ^{
        _defaultDB = [[self alloc] init];
    });
    
    return _defaultDB;
}

- (NSArray *)entities {
    if (!_entities) {
        _entities = kEntities;
    }
    return _entities;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        disableNotifications = NO;
        // init logging
        [TKSyncLogger initializeDefaults];
    }
    return self;
}


- (void) contextDidSave:(NSNotification*)notification {

    if (disableNotifications) {
        return;
    }
    
    NSDictionary *dictChanges = notification.userInfo;
    
    for (NSManagedObject *object in dictChanges[NSInsertedObjectsKey]) {
        if ([object tk_serverObjectID] != nil) {
            continue;
        }
        TKDBCacheEntry *entry = [[TKDBCacheEntry alloc] initWithType:TKDBCacheInsert];
        entry.localObjectIDURL = [[[object objectID] URIRepresentation] absoluteString];
        entry.uniqueObjectID = object.tk_uniqueObjectID;
        entry.entity = object.entity.name;
        [[TKDBCacheManager sharedManager] addCacheEntry:entry];
        [[TKDBCacheManager sharedManager] mapLocalObjectWithURL:entry.localObjectIDURL toUniqueObjectWithID:entry.uniqueObjectID];
    }
    
    for (NSManagedObject *object in dictChanges[NSUpdatedObjectsKey]) {
        
        TKDBCacheEntry *entry = [[TKDBCacheManager sharedManager] entryForObjectID:object.tk_uniqueObjectID withType:TKDBCacheUpdate];
        
        // Check if there is an update entry for this object in the cache.
        if (entry) {
            // Check if the entry is pending save (which normally should be the case).
            if (entry.entryState == TKDBCachePendingSave) {
                entry.entryState = TKDBCacheSaved;
                entry.changedFields = entry.tempChangedFields;
                entry.tempChangedFields = nil;
            }
            // If the entry is not pending save, it might be the case that it is updated
            // inadvertently when saving due to a relationship getting updated. In this
            // case, we do nothing.
            else {
                
            }
        }
        // If no entry exists, do nothing. This will happen if we were saving server info.
        else {
        }
    }
    
    [[TKDB defaultDB].syncContext mergeChangesFromContextDidSaveNotification:notification];
    [[TKDBCacheManager sharedManager] saveToFileSystem];
}

- (void) contextWillSave:(NSNotification*)notification {
    
    if (disableNotifications) {
        return;
    }
    
    for (NSManagedObject *object in [TKDB defaultDB].rootContext.insertedObjects) {
        if ([object tk_serverObjectID] != nil) {
            continue;
        }
        [object setValue:[NSDate date] forKey:kTKDBCreatedDateField];
        [object setValue:[NSDate date] forKey:kTKDBUpdatedDateField];
        [object assignUniqueObjectID];
    }
    
    for (NSManagedObject *object in [TKDB defaultDB].rootContext.updatedObjects) {
        
        if ([[TKDB defaultDB].rootContext.insertedObjects containsObject:object]) {
            continue;
        }
        // Do not create cache entries if we are modifying server based data.
        if (object.changedValues[kTKDBServerIDField] != nil) {
            continue;
        }
        
        // Set the updated date on the object to be saved in local db.
        [object setValue:[NSDate date] forKey:kTKDBUpdatedDateField];
        
        // Check whether there is an insert entry for this object. If there is,
        // we should ignore this update event since uploading inserted objects
        // will read from the database ayway.
        TKDBCacheEntry *entry = [[TKDBCacheManager sharedManager] entryForObjectID:object.tk_uniqueObjectID withType:TKDBCacheInsert];
        
        if (entry) {
            continue;
        }
        
        // Check if there is an update entry for this object.
        entry = [[TKDBCacheManager sharedManager] entryForObjectID:object.tk_uniqueObjectID withType:TKDBCacheUpdate];
        
        // If there is no update entry, we create a new entry.
        if (!entry) {
            entry = [[TKDBCacheEntry alloc] initWithType:TKDBCacheUpdate];
            entry.localObjectIDURL = [[[object objectID] URIRepresentation] absoluteString];
            entry.serverObjectID = object.tk_serverObjectID;
            entry.uniqueObjectID = object.tk_uniqueObjectID;
            entry.entity = object.entity.name;
            entry.lastModificationDate = [NSDate date];
            [[TKDBCacheManager sharedManager] addCacheEntry:entry];
        }
        
        // Mark the entry as pending save.
        entry.entryState = TKDBCachePendingSave;
        
        // If there are no temp changed values dictionary, create it.
        if (!entry.tempChangedFields) {
            // If there are changed values, copy them to temp to later
            // add the new changed values.
            if (entry.changedFields) {
                entry.tempChangedFields = [NSMutableSet setWithSet:entry.changedFields];
            }
            else {
                entry.tempChangedFields = [NSMutableSet set];
            }
        }
        
        // Merge the new changed values with the ones in the entry.
        [entry.tempChangedFields addObjectsFromArray:[object.changedValues allKeys]];
        
        if (!entry.originalObject) {
            TKServerObject *original = [object toServerObjectInContext:[TKDB defaultDB].referenceContext];
            original.isOriginal = YES;
            entry.originalObject = original;
        }
    }
    
    for (NSManagedObject *object in [TKDB defaultDB].rootContext.deletedObjects) {
        // If there is an insert entry for this object, we remove it.
        // check if this was a nil object ==> weird issue where deleted objects sent multiple notifications on different save operations.
        if (object.tk_uniqueObjectID == nil) {
            continue;
        }
        TKDBCacheEntry *entry = [[TKDBCacheManager sharedManager] entryForObjectID:object.tk_uniqueObjectID withType:TKDBCacheInsert];
        
        if (entry) {
            [[TKDBCacheManager sharedManager] removeEntry:entry];
            // We continue here because we do not need to inform the
            // server with the deletion of an object that hasn't been
            // uploaded.
            continue;
        }
        
        // If there is an update entry we remove it so as to not do any
        // needless work.
        entry = [[TKDBCacheManager sharedManager] entryForObjectID:object.tk_uniqueObjectID withType:TKDBCacheUpdate];
        
        if (entry) {
            [[TKDBCacheManager sharedManager] removeEntry:entry];
        }
        
        // Create the deletion entry.
        entry = [[TKDBCacheEntry alloc] initWithType:TKDBCacheDelete];
        entry.localObjectIDURL = [[[object objectID] URIRepresentation] absoluteString];
        entry.serverObjectID = [object tk_serverObjectID];
        entry.uniqueObjectID = object.tk_uniqueObjectID;
        entry.lastModificationDate = [NSDate date];
        entry.entity = object.entity.name;
        [[TKDBCacheManager sharedManager] addCacheEntry:entry];
    }
    
}

- (void) setRootContext:(NSManagedObjectContext*)rootContext {
    _rootContext = rootContext;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextDidSave:) name:NSManagedObjectContextDidSaveNotification object:_rootContext];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextWillSave:) name:NSManagedObjectContextWillSaveNotification object:_rootContext];
    
    NSManagedObjectContext *syncContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    syncContext.parentContext = _rootContext;
    _syncContext = syncContext;
    
    NSManagedObjectContext *referenceContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    referenceContext.persistentStoreCoordinator = _rootContext.persistentStoreCoordinator;
    _referenceContext = referenceContext;
    _referenceContext.mergePolicy = NSOverwriteMergePolicy;
    
    self.entities = [rootContext.persistentStoreCoordinator.managedObjectModel entitiesByName].allKeys;
}

- (NSDate*) lastSyncDate {
    NSDate *date = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastSyncDate"];
    if (!date) {
        [[NSUserDefaults standardUserDefaults] setValue:[NSDate dateWithTimeIntervalSince1970:0] forKey:@"lastSyncDate"];
    }
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"lastSyncDate"];
}

- (void) setLastSyncDate:(NSDate*)date {
     [[NSUserDefaults standardUserDefaults] setValue:date forKey:@"lastSyncDate"];
}

// step 1
- (BFTask *)downloadAllServerUpdatesWithManager:(TKParseServerSyncManager *)manager {
    
    return [[BFTask taskWithResult:nil] continueWithBlock:^id(BFTask *task) {

        NSMutableArray __block *arrServerObjects = [NSMutableArray array];

        NSMutableArray *tasks = @[].mutableCopy;
        for (NSString *entity in self.entities) {
            BFTaskCompletionSource *source = [BFTaskCompletionSource taskCompletionSource];
            
            [[manager downloadUpdatedObjectsAsyncForEntity:entity] continueWithBlock:^id(BFTask *task) {
                if (task.isCancelled) {
                    [source cancel];
                }
                else if (task.error) {
                    [source setError:task.error];
                }
                else {
                    NSArray *obejcts = task.result;
                    [arrServerObjects addObjectsFromArray:obejcts];
                    [source setResult:obejcts];
                }
                return nil;
            }];
            
            [tasks addObject:source.task];
        }
        return [[BFTask taskForCompletionOfAllTasks:tasks] continueWithBlock:^id(BFTask *task) {
            // this will be executed after *all* the group tasks have completed
            if (task.error) {
                [[TKDBCacheManager sharedManager] rollbackToCheckpoint];
                return [BFTask taskWithError:task.error];
            }
            else {
                return [BFTask taskWithResult:arrServerObjects];
            }
        }];
    }];
}

// step 2
- (BFTask *)insertServerObjects:(NSArray *)serverObjects thenUploadLocalData:(NSArray *)localInsertedObjects withManager:(TKParseServerSyncManager *)manager {
    BFTaskCompletionSource *sourceTask = [BFTaskCompletionSource taskCompletionSource];
    
    // insert server objects
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"creationDate > %@", [self lastSyncDate]];
    NSArray *newServerObjects = [serverObjects filteredArrayUsingPredicate:predicate];
    [TKServerObjectHelper insertServerObjectsInLocalDatabase:newServerObjects];
    
    // upload local objects
    [[manager uploadInsertedObjectsAsync:localInsertedObjects] continueWithBlock:^id(BFTask *task) {
        if (task.isCancelled) {
            [sourceTask cancel];
        }
        else if (task.error) {
            [sourceTask setError:task.error];
            [[TKDBCacheManager sharedManager] rollbackToCheckpoint];
        }
        else {
            [sourceTask setResult:task.result];
        }
        return nil;
    }];
    
    return sourceTask.task;
}

// step 3
- (void)updateManagedObjectsWithServerIDs:(NSArray *)insertedObjectsWithServerIDs {
    [TKServerObjectHelper updateServerIDInLocalDatabase:insertedObjectsWithServerIDs];
}

// step 4
- (BFTask *)uploadInsertedObjectsAsUpdates:(NSArray *)insertedObjects withManager:(TKParseServerSyncManager *)manager {
    BFTaskCompletionSource *uploadTask = [BFTaskCompletionSource taskCompletionSource];
    
    [[manager uploadUpdatedObjectsAsync:insertedObjects] continueWithBlock:^id(BFTask *task) {
        if (task.isCancelled) {
            [uploadTask cancel];
        }
        else if (task.error) {
            [uploadTask setError:task.error];
            [[TKDBCacheManager sharedManager] rollbackToCheckpoint];
        }
        else {
            [uploadTask setResult:task.result];
        }
        return nil;
    }];
    
    return uploadTask.task;
}

// step 5
- (NSMutableSet *)getConflictsWithServerObjects:(NSArray *)serverObjects localObjects:(NSArray *)localObjects shadowObjects:(NSMutableArray **)arrShadowObjects withLocalUpdates:(NSMutableSet **)localUpdatesNoConflict andServerUpdates:(NSMutableSet **)serverUpdatesNoConflict {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"creationDate <= %@", [self lastSyncDate]];
    NSArray *updatedServerObjects = [serverObjects filteredArrayUsingPredicate:predicate];
    
    NSSet *updatedServerObjectsSet = [NSSet setWithArray:updatedServerObjects];
    NSSet *updatedLocalObjectsSet = [NSSet setWithArray:localObjects];
    
    NSMutableSet *conflictPairs = [NSMutableSet set];
    
    *serverUpdatesNoConflict = [[updatedServerObjectsSet objectsPassingTest:^BOOL(id obj, BOOL *stop) {
        return ![updatedLocalObjectsSet containsObject:obj];
    }] mutableCopy];
    
    *localUpdatesNoConflict = [[updatedLocalObjectsSet objectsPassingTest:^BOOL(id obj, BOOL *stop) {
        return ![updatedServerObjectsSet containsObject:obj];
    }] mutableCopy];
    
    for (TKServerObject *serverObject in updatedServerObjectsSet) {
        for (TKServerObject *localObject in updatedLocalObjectsSet) {
            if ([serverObject isEqual:localObject]) {
                TKDBCacheEntry *entry = [[TKDBCacheManager sharedManager] entryForObjectID:localObject.uniqueObjectID withType:TKDBCacheUpdate];
                TKServerObject *shadowServerObject = entry.originalObject;
                [conflictPairs addObject:[[TKServerObjectConflictPair alloc] initWithServerObject:serverObject localObject:localObject shadowObject:shadowServerObject]];
            }
        }
    }

    return conflictPairs;
}

// step 6
- (void)_resolveConflicts:(NSArray *)conflictPairs withLocalUpdates:(NSMutableSet **)localUpdatesNoConflict andServerUpdates:(NSMutableSet **)serverUpdatesNoConflict {
    for (TKServerObjectConflictPair *conflictPair in conflictPairs) {
        [TKServerObjectHelper resolveConflict:conflictPair localUpdates:[*localUpdatesNoConflict allObjects] serverUpdates:[*serverUpdatesNoConflict allObjects]];
        if (conflictPair.resolutionType == TKDBMergeLocalWins) {
            [*serverUpdatesNoConflict addObject:conflictPair.outputObject];
        }
        else if (conflictPair.resolutionType == TKDBMergeServerWins) {
            [*localUpdatesNoConflict addObject:conflictPair.outputObject];
        }
        else if (conflictPair.resolutionType == TKDBMergeBothUpdated) {
            [*serverUpdatesNoConflict addObject:conflictPair.outputObject];
            [*localUpdatesNoConflict addObject:conflictPair.outputObject];
        }
    }
}

// step 7
- (void)saveServerObjectsToLocalDB:(NSArray *)serverObjects {
    [TKServerObjectHelper updateServerObjectsInLocalDatabase:serverObjects];
}

// setp 8
- (BFTask *)uploadLocalObjects:(NSArray *)localObjects withManager:(TKParseServerSyncManager *)manager {
    BFTaskCompletionSource *uploadTask = [BFTaskCompletionSource taskCompletionSource];
    
    [[manager uploadUpdatedObjectsAsync:localObjects] continueWithBlock:^id(BFTask *task) {
        if (task.isCancelled) {
            [uploadTask cancel];
        }
        else if (task.error) {
            [uploadTask setError:task.error];
            [[TKDBCacheManager sharedManager] rollbackToCheckpoint];
        }
        else {
            [uploadTask setResult:task.result];
        }
        return nil;
    }];
    
    return uploadTask.task;
    
}

// step 9
- (void)deleteShadowObjects:(NSArray *)shadowObjects {
    
    NSManagedObjectContext __weak *weakSyncContext = self.syncContext;
    for (NSManagedObject *shadowObject in shadowObjects) {
        NSManagedObject __weak *weakShadowObject = shadowObject;
        [self.syncContext performBlockAndWait:^{
            [weakSyncContext deleteObject:weakShadowObject];
        }];
    }
}

// final step
- (void)saveAll:(NSError **)error {
    NSManagedObjectContext __weak *weakSyncContext = self.syncContext;
    [self.syncContext performBlockAndWait:^{
        [weakSyncContext save:error];
        disableNotifications = YES;
        [weakSyncContext.parentContext save:error];
        disableNotifications = NO;
    }];

    [self setLastSyncDate:[NSDate date]];
    [[TKDBCacheManager sharedManager] clearCache];
    [[TKDBCacheManager sharedManager] endCheckpointSuccessfully];
}


/*
 
 1-  pull server changes
 2-  get local changes
 3-  detect conflicts
 4-  resolve conflicts
 5-  save locals.
 6-  upload new inserts.
 7-  update local inserts with serverIds
 8-  wire relations
 9-  push all changes.
 10- clean & save to db
 */

- (BFTask *)pullServerChanges {
    __weak TKDB *weakself = self;
    return [[BFTask taskWithResult:nil] continueWithBlock:^id(BFTask *task) {
        NSMutableArray __block *arrServerObjects = [NSMutableArray array];
        
        NSMutableArray *tasks = @[].mutableCopy;
        for (NSString *entity in weakself.entities) {
            BFTaskCompletionSource *source = [BFTaskCompletionSource taskCompletionSource];
            
            [[weakself.manager downloadUpdatedObjectsAsyncForEntity:entity] continueWithBlock:^id(BFTask *task) {
                if (task.isCancelled) {
                    [source cancel];
                }
                else if (task.error) {
                    [source setError:task.error];
                }
                else {
                    NSArray *obejcts = task.result;
                    [arrServerObjects addObjectsFromArray:obejcts];
                    [source setResult:obejcts];
                }
                return nil;
            }];
            
            [tasks addObject:source.task];
        }
        return [[BFTask taskForCompletionOfAllTasks:tasks] continueWithBlock:^id(BFTask *task) {
            // this will be executed after *all* the group tasks have completed
            if (task.error) {
                [[TKDBCacheManager sharedManager] rollbackToCheckpoint];
                return [BFTask taskWithError:task.error];
            }
            else {
                return [BFTask taskWithResult:arrServerObjects];
            }
        }];
    }];
}

- (NSArray *)detectConflictsWithServerObjects:(NSArray *)serverObjects localObjects:(NSArray *)localObjects localUpdatesNoConflicts:(NSMutableSet **)localUpdatesNoConflicts serverUpdatesNoConflicts:(NSMutableSet **)serverUpdatesNoConflicts {
    
    NSMutableSet *conflictPairs = [NSMutableSet set];
    
    NSMutableSet *updatedObjects = [NSMutableSet setWithArray:serverObjects];
    
    NSSet *updatedServerObjectsSet = [NSSet setWithArray:serverObjects];
    NSSet *updatedLocalObjectsSet = [NSSet setWithArray:localObjects];
    
    *serverUpdatesNoConflicts = [[updatedServerObjectsSet objectsPassingTest:^BOOL(id obj, BOOL *stop) {
        return ![updatedLocalObjectsSet containsObject:obj];
    }] mutableCopy];
    
    *localUpdatesNoConflicts = [[updatedLocalObjectsSet objectsPassingTest:^BOOL(id obj, BOOL *stop) {
        return ![updatedServerObjectsSet containsObject:obj];
    }] mutableCopy];
    
    
    for (TKServerObject *serverObject in updatedObjects) {
        
        for (TKServerObject *otherObject in localObjects) {
            if ([serverObject isEqual:otherObject]) {
                TKDBCacheEntry *entry = [[TKDBCacheManager sharedManager] entryForObjectID:serverObject.uniqueObjectID withType:TKDBCacheUpdate];
                TKServerObject *shadowServerObject = entry.originalObject;
                [conflictPairs addObject:[[TKServerObjectConflictPair alloc] initWithServerObject:serverObject localObject:otherObject shadowObject:shadowServerObject]];
                
                if (serverObject.isDeleted) {
                    // get relatedObjects of serverObject
                    for (NSString *key in serverObject.relatedObjects) {
                        id val = serverObject.relatedObjects[key];
                        if ([val isKindOfClass:[NSArray class]]) {
                            for (TKServerObject *_relatedObject in val) {
                                TKServerObject *relatedObject = _relatedObject;
                                for (TKServerObject *_server in serverObjects) {
                                    if ([_server.uniqueObjectID isEqualToString:relatedObject.uniqueObjectID]) {
                                        relatedObject = _server;
                                        // remove that object from serverUpadatesNoConflicts
                                        [*serverUpdatesNoConflicts removeObject:_server];
                                        break;
                                    }
                                }
                                
                                NSManagedObject *localRelatedObject = [self objectOfEntity:relatedObject.entityName withUniqueID:relatedObject.uniqueObjectID];
                                if (localRelatedObject == nil) {
                                    // object not found
                                } else {
                                    // get entry for it
                                    TKDBCacheEntry *entry = [self entryWithObject:localRelatedObject];
                                    TKServerObject *shadowServerObject = entry.originalObject;
                                    TKServerObject *localServerObject = [localRelatedObject toServerObject];
                                    localServerObject.lastModificationDate = otherObject.lastModificationDate;
                                    [conflictPairs addObject:[[TKServerObjectConflictPair alloc] initWithServerObject:relatedObject localObject:localServerObject shadowObject:shadowServerObject]];
                                }
                            }
                        }
                        else if ([val isKindOfClass:[TKServerObject class]]) {
                            TKServerObject *relatedObject = val;
                            // search for relatedObject in the serverObjects
                            for (TKServerObject *_server in serverObjects) {
                                if ([_server.uniqueObjectID isEqualToString:relatedObject.uniqueObjectID]) {
                                    relatedObject = _server;
                                    // remove that object from serverUpadatesNoConflicts
                                    [*serverUpdatesNoConflicts removeObject:_server];
                                    break;
                                }
                            }
                            // get the localObject of it
                            NSManagedObject *localRelatedObject = [self objectOfEntity:relatedObject.entityName withUniqueID:relatedObject.uniqueObjectID];
                            if (localRelatedObject == nil) {
                                // object not found
                            } else {
                                // get entry for it
                                TKDBCacheEntry *entry = [self entryWithObject:localRelatedObject];
                                TKServerObject *shadowServerObject = entry.originalObject;
                                TKServerObject *localServerObject = [localRelatedObject toServerObject];
                                localServerObject.lastModificationDate = otherObject.lastModificationDate;
                                [conflictPairs addObject:[[TKServerObjectConflictPair alloc] initWithServerObject:relatedObject localObject:localServerObject shadowObject:shadowServerObject]];
                            }
                        }
                    }
                }
            }
        }
    }
    
    return [conflictPairs allObjects];
}

- (TKDBCacheEntry *)entryWithObject:(NSManagedObject *)managedObject {
    TKDBCacheEntry *entry = [[TKDBCacheManager sharedManager] entryForObjectID:managedObject.tk_uniqueObjectID withType:TKDBCacheUpdate];
    if (!entry) {
        entry = [[TKDBCacheEntry alloc] initWithType:TKDBCacheUpdate];
        entry.localObjectIDURL = [[[managedObject objectID] URIRepresentation] absoluteString];
        entry.serverObjectID = managedObject.tk_serverObjectID;
        entry.uniqueObjectID = managedObject.tk_uniqueObjectID;
        entry.entity = managedObject.entity.name;
        [[TKDBCacheManager sharedManager] addCacheEntry:entry];
        
        TKServerObject *original = [managedObject toServerObjectInContext:[TKDB defaultDB].referenceContext];
        original.isOriginal = YES;
        entry.originalObject = original;
    }
    return entry;
}

- (NSManagedObject *)objectOfEntity:(NSString *)entity withUniqueID:(NSString *)uniqueID {
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:entity];
    fetch.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kTKDBUniqueIDField, uniqueID];
    NSError *error;
    
    NSArray *array = [self.syncContext executeFetchRequest:fetch error:&error];
    
    return [array lastObject];
}

- (void)resolveConflicts:(NSArray *)conflicts withLocalUpdates:(NSMutableSet **)localUpdatesNoConflicts andServerUpdates:(NSMutableSet **)serverUpdatesNoConflicts {
    for (TKServerObjectConflictPair *conflictPair in conflicts) {
        [TKServerObjectHelper resolveConflict:conflictPair localUpdates:[*localUpdatesNoConflicts allObjects] serverUpdates:[*serverUpdatesNoConflicts allObjects]];
        if (conflictPair.resolutionType == TKDBMergeLocalWins) {
            [*serverUpdatesNoConflicts addObject:conflictPair.outputObject];
        }
        else if (conflictPair.resolutionType == TKDBMergeServerWins) {
            [*localUpdatesNoConflicts addObject:conflictPair.outputObject];
        }
        else if (conflictPair.resolutionType == TKDBMergeBothUpdated) {
            [*serverUpdatesNoConflicts addObject:conflictPair.outputObject];
            [*localUpdatesNoConflicts addObject:conflictPair.outputObject];
        }
    }
}

- (BFTask *)pushNewLocalObjects:(NSArray *)newObjects {
    // upload local objects
    return [[self.manager uploadInsertedObjectsAsync:newObjects] continueWithBlock:^id(BFTask *task) {
        if (task.error) {
            [[TKDBCacheManager sharedManager] rollbackToCheckpoint];
            return [BFTask taskWithError:task.error];
        }
        else {
            return [BFTask taskWithResult:task.result];
        }
    }];
}

- (BFTask *)pushNewLocalObjectsWithRelations:(NSArray *)objectsWithRelations {
    return [[self.manager uploadUpdatedObjectsAsync:objectsWithRelations] continueWithBlock:^id(BFTask *task) {
        if (task.error) {
            [[TKDBCacheManager sharedManager] rollbackToCheckpoint];
            return [BFTask taskWithError:task.error];
        }
        else {
            return [BFTask taskWithResult:task.result];
        }
    }];

}

- (BFTask *)sync {
    
    [TKSyncLogger startLogging];
    
    DDLogVerbose(@"Starting Sync");
    DDLogVerbose(@"Last Sync Date: %@\n\n", self.lastSyncDate);
    
    CFTimeInterval SYNC_START_TIME = CACurrentMediaTime();
    
    self.manager = [[TKParseServerSyncManager alloc] init];

    [[TKDBCacheManager sharedManager] startCheckpoint];
    
    __weak TKDB *weakself = self;

    CFTimeInterval __block startTime = CACurrentMediaTime();

    DDLogVerbose(@"Pulling Server Changes...\n");
    
    return [[self pullServerChanges] continueWithSuccessBlock:^id(BFTask *pullTask) {
        CFTimeInterval __block endTime = CACurrentMediaTime();
        NSNumber __block *step1Time = @(endTime - startTime);

        startTime = CACurrentMediaTime();
        
        NSMutableArray *arrServerObjects = pullTask.result;

        DDLogVerbose(@"Pulling Server Changes took : %@ seconds\n\n", step1Time);
        DDLogVerbose(@"Server Changes <%lu object(s)>: %@\n\n", (unsigned long)arrServerObjects.count, [NSSet setWithArray:arrServerObjects]);
        
        NSArray *localInsertedObjects = [TKServerObjectHelper getInsertedObjectsFromCache];
        DDLogVerbose(@"Local new objects <%lu object(s)>: %@\n\n", (unsigned long)localInsertedObjects.count, [NSSet setWithArray:localInsertedObjects]);
        
        NSArray *localUpdatedObjects = [TKServerObjectHelper getUpdatedObjectsFromCache];
        DDLogVerbose(@"Local Updated/Deleted objects <%lu object(s)>: %@\n\n", (unsigned long)localUpdatedObjects.count, [NSSet setWithArray:localUpdatedObjects]);
        
        NSMutableSet *localUpdatesNoConflicts = [NSMutableSet set];
        NSMutableSet *serverUpdatesNoConflicts = [NSMutableSet set];
        
        DDLogVerbose(@"Checking for Conflicts...");
        
        NSArray *conflicts = [weakself detectConflictsWithServerObjects:arrServerObjects localObjects:[localUpdatedObjects arrayByAddingObjectsFromArray:localInsertedObjects] localUpdatesNoConflicts:&localUpdatesNoConflicts serverUpdatesNoConflicts:&serverUpdatesNoConflicts];
        
        DDLogVerbose(@"Detected Conflicts <%lu object(s)>: %@\n\n", (unsigned long)conflicts.count, [NSSet setWithArray:conflicts]);
        
        DDLogVerbose(@"Resolving Conflicts...");
        
        [weakself resolveConflicts:conflicts withLocalUpdates:&localUpdatesNoConflicts andServerUpdates:&serverUpdatesNoConflicts];
        
        DDLogVerbose(@"Changes after resolving conflicts:\nLocal Updates<%lu object(s)>:%@\nServer Updates<%lu object(s)>:%@\n\n\n\n", localUpdatesNoConflicts.count, localUpdatesNoConflicts, serverUpdatesNoConflicts.count, serverUpdatesNoConflicts);
        
        endTime = CACurrentMediaTime();
        NSNumber __block *step2Time = @(endTime - startTime);
        
        // conflict management should return all server updates
        // @param serverUpdatesNoConflicts should have all server changes with conflicts resolved.
        
        DDLogVerbose(@"Adding server changes to Database...");
        // save serverChanges
        [TKServerObjectHelper updateServerObjectsInLocalDatabase:[serverUpdatesNoConflicts allObjects]];
        
        NSSet *insertedObjects = weakself.syncContext.insertedObjects;
        NSSet *updatedObjects = weakself.syncContext.updatedObjects;
        NSSet *deletedObejcts = weakself.syncContext.deletedObjects;
        DDLogVerbose(@"Database's Inserted objects<%lu object(s)>:%@\n\n", insertedObjects.count, insertedObjects);
        DDLogVerbose(@"Database's Updated objects<%lu object(s)>:%@\n\n", updatedObjects.count, updatedObjects);
        DDLogVerbose(@"Database's Deleted objects<%lu object(s)>:%@\n\n", deletedObejcts.count, deletedObejcts);
        
        NSMutableSet *objectsSet = [NSMutableSet setWithSet:localUpdatesNoConflicts];
        // detect new objects
        NSSet *newObjects = [objectsSet filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"serverObjectID == nil"]];
        
        [objectsSet minusSet:newObjects];
        
        DDLogVerbose(@"Pushing local Changes...");
        DDLogVerbose(@"Local new objects<%lu object(s)>: %@\n\n", newObjects.count, newObjects);
        startTime = CACurrentMediaTime();
        return [[weakself pushNewLocalObjects:newObjects.allObjects] continueWithSuccessBlock:^id(BFTask *task) {
            endTime = CACurrentMediaTime();
            NSNumber __block *uploadingLocalInserts = @(endTime - startTime);
            
            DDLogVerbose(@"Pushing new objects completed in %@ seconds\n", uploadingLocalInserts);
            
            NSArray *newObjectsWithServerIDs = task.result;
            
            DDLogVerbose(@"Adding server IDs to Database :%@\n\n", [NSSet setWithArray:newObjectsWithServerIDs]);
            [TKServerObjectHelper updateServerIDInLocalDatabase:newObjectsWithServerIDs];
            
            // combine newObjectsWithServerIDs with localUpdates
            NSArray *allObjects = [objectsSet.allObjects arrayByAddingObjectsFromArray:newObjectsWithServerIDs];
            
            DDLogVerbose(@"Pushing All local changes with relations...");
            DDLogVerbose(@"Changes <%lu object(s)>: %@\n\n", allObjects.count, [NSSet setWithArray:allObjects]);
            
            // then push local relations
            startTime = CACurrentMediaTime();
            return [[weakself pushNewLocalObjectsWithRelations:allObjects] continueWithSuccessBlock:^id(BFTask *task) {
                endTime = CACurrentMediaTime();
                NSNumber __block *uploadingLocalChanges = @(endTime - startTime);
                
                DDLogVerbose(@"Pushing to server completed in %@ seconds\n\n", uploadingLocalChanges);
                
                DDLogVerbose(@"Saving database changes...");
                // save to Db
                NSError __block *savingError;
                [weakself.syncContext performBlockAndWait:^{
                    [weakself.syncContext save:&savingError];
                    disableNotifications = YES;
                    [weakself.syncContext.parentContext save:&savingError];
                    disableNotifications = NO;
                }];
                
                if (savingError) {
                    DDLogError(@"Saving Failed with error: %@", savingError);
                    // rollback and
                    [[TKDBCacheManager sharedManager] rollbackToCheckpoint];
                    return [BFTask taskWithError:savingError];
                }
                else {
                    DDLogVerbose(@"Saving Finished Successfully\n\n");
                    [weakself setLastSyncDate:[NSDate date]];
                    [[TKDBCacheManager sharedManager] clearCache];
                    [[TKDBCacheManager sharedManager] endCheckpointSuccessfully];
                }
                
                CFTimeInterval SYNC_END_TIME = CACurrentMediaTime();
                NSNumber *SYNC_TIME = @(SYNC_END_TIME - SYNC_START_TIME);
                DDLogVerbose(@"Sync Finished in %@ seconds", SYNC_TIME);
                
                [TKSyncLogger endLogging];
                return [BFTask taskWithResult:@{@"Downloading server changes": step1Time, @"Resolving Conflicts" : step2Time, @"Uploading local Inserts": uploadingLocalInserts, @"Uploading local updates": uploadingLocalChanges}];
            }];
        }];
    }];
}

- (BFTask *)_sync {
    TKParseServerSyncManager *manager = [[TKParseServerSyncManager alloc] init];
    
    NSMutableArray __block *arrShadowObjects;
    NSArray __block *localInsertedObjects = [TKServerObjectHelper getInsertedObjectsFromCache];
    NSArray __block *localUpdatedObjects = [TKServerObjectHelper getUpdatedObjectsFromCache];
    
    [[TKDBCacheManager sharedManager] startCheckpoint];
    
#pragma mark Step 1: Download all objects updated on the server since last sync
    BFTask *pullFromServerTask = [self downloadAllServerUpdatesWithManager:manager];
    
    return [pullFromServerTask continueWithSuccessBlock:^id(BFTask *pullTask) {
        
        NSMutableArray __block *arrServerObjects = pullTask.result;

#pragma mark Step 2: Insert newly created objects on local from server and vice versa.
        BFTask *insertThenUploadLocalDataTask = [self insertServerObjects:arrServerObjects thenUploadLocalData:localInsertedObjects withManager:manager];
        
        return [insertThenUploadLocalDataTask continueWithSuccessBlock:^id(BFTask *insertTask) {
            NSArray *insertedObjectsWithServerIDs = insertTask.result;
#pragma mark Step 3: Update managed objects with server IDs
            [self updateManagedObjectsWithServerIDs:insertedObjectsWithServerIDs];
            
#pragma mark Step 4: Upload inserted objects as updates to wire relationships on the cloud.
            BFTask *pushNewObjectsTask = [self uploadInsertedObjectsAsUpdates:insertedObjectsWithServerIDs withManager:manager];
            
            return [pushNewObjectsTask continueWithSuccessBlock:^id(BFTask *pushTask) {
                
#pragma mark Step 5: Separate updated objects into local no conflict, server no conflict, and conflict
                arrShadowObjects = [NSMutableArray array];
                NSMutableSet *localUpdatesNoConflict = [NSMutableSet set];
                NSMutableSet *serverUpdatesNoConflict = [NSMutableSet set];
                NSMutableSet *conflictPairs = [self getConflictsWithServerObjects:arrServerObjects localObjects:localUpdatedObjects shadowObjects:&arrShadowObjects withLocalUpdates:&localUpdatesNoConflict andServerUpdates:&serverUpdatesNoConflict];
#pragma mark Step 6: Resolve conflicts
                [self resolveConflicts:[conflictPairs allObjects] withLocalUpdates:&localUpdatesNoConflict andServerUpdates:&serverUpdatesNoConflict];
                
#pragma mark Step 7: Save objects updated on the server to local db (no conflict + conflict resolved)
                [self saveServerObjectsToLocalDB:[serverUpdatesNoConflict allObjects]];
                
#pragma mark Step 8: Save objects updated locally to server (no conflict + conflict resolved)
                BFTask *pushUpdatedObjectsTask = [self uploadLocalObjects:[localUpdatesNoConflict allObjects] withManager:manager];
                
                return [pushUpdatedObjectsTask continueWithSuccessBlock:^id(BFTask *task) {
                    
#pragma mark Step 9: Delete all shadow objects
                    [self deleteShadowObjects:arrShadowObjects];

                    NSError *savingError;
                    [self saveAll:&savingError];
                    
                    if (savingError) {
                        return [BFTask taskWithError:savingError];
                    }
                    else {
                        [[NSNotificationCenter defaultCenter] postNotificationName:TKDBSyncDidSucceedNotification object:nil userInfo:nil];
                        return [BFTask taskWithResult:nil];
                    }
                }];
            }];
        }];
    }];
}

- (BFTask *)checkServerForExistingObjects {
    return [[BFTask taskWithResult:nil] continueWithBlock:^id(BFTask *task) {
        
        TKParseServerSyncManager *manager = [[TKParseServerSyncManager alloc] init];
            
        return [manager countOfObjectsForEntity:@"Gradetype"];
    }];

}

@end
