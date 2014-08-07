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
#import "NSManagedObjectContext+Sync.h"

@interface TKParseServerSyncManager ()
/**
 *  A dictionary of dictionaries. holds the files of each server object
 */
@property (nonatomic, strong) NSMutableDictionary *sessionFiles;

@end

@implementation TKParseServerSyncManager

- (NSString *)homeDirectory {
    return NSHomeDirectory();
}

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
    for (NSString *key in dictAttributes) {
        if ([dictAttributes[key] isEqual:[NSNull null]]) {
            // ignore
        }
        else {
            object[key] = dictAttributes[key];
        }
    }
    return object;
}

- (PFObject*) existingParseObjectBasicInfoForServerObject:(TKServerObject*)serverObject {
    PFObject *object = [PFObject objectWithoutDataWithClassName:serverObject.entityName objectId:serverObject.serverObjectID];
    
    NSMutableDictionary *dictAttributes = [serverObject.attributeValues mutableCopy];
    [dictAttributes removeObjectsForKeys:@[kTKDBCreatedDateField, kTKDBServerIDField]];
    [dictAttributes setObject:@(serverObject.isDeleted) forKey:kTKDBIsDeletedField];
    [dictAttributes setObject:serverObject.uniqueObjectID forKey:kTKDBUniqueIDField];
    [dictAttributes setObject:serverObject.lastModificationDate forKey:kTKDBUpdatedDateField];// for deleted objects
    for (NSString *key in dictAttributes) {
        if ([dictAttributes[key] isEqual:[NSNull null]]) {
            // can't remove it right now, ignore and remove later after refresh.
        }
        else {
            object[key] = dictAttributes[key];
        }
    }
    return object;
}

- (BFTask *)serverObjectForParseObjectAsync:(PFObject *)parseObject {
    
    return [[BFTask taskWithResult:nil] continueWithBlock:^id(BFTask *task) {
        
        TKServerObject *serverObject = [self serverObjectBasicInfoForParseObject:parseObject];
        
        NSMutableDictionary *dictAttributes = [NSMutableDictionary dictionary];
        NSMutableDictionary *dictBinaryKeysAttributes = [NSMutableDictionary dictionary];
        NSMutableDictionary *relatedObjects = [NSMutableDictionary dictionary];
        
        NSMutableArray *tasks = @[].mutableCopy;
        
        // get entity's properties
        NSEntityDescription *entity = [NSEntityDescription entityForName:serverObject.entityName inManagedObjectContext:[TKDB defaultDB].syncContext];
        
        NSArray *properties = [entity.propertiesByName allKeys];
        NSMutableSet *allProperties = [NSMutableSet setWithArray:properties];
        [allProperties addObjectsFromArray:parseObject.allKeys];

        // these properties are set to the serverObject. so remove them from the allProprties
        [allProperties removeObject:kTKDBServerIDField];
        [allProperties removeObject:kTKDBCreatedDateField];
        [allProperties removeObject:kTKDBIsDeletedField];
//        [allProperties removeObject:kTKDBUpdatedDateField];
        [allProperties removeObject:kTKDBServerIDField];
        [allProperties removeObject:@"ACL"];
        
        for (NSString *key in allProperties) {
            
            BFTaskCompletionSource *subTask = [BFTaskCompletionSource taskCompletionSource];
            id value = [parseObject valueForKey:key];
            // ignore Roles.
            if ([value isKindOfClass:[PFRole class]]) {
                continue;
            }
            else if ([value isKindOfClass:[PFObject class]]) {

                PFObject *relatedObject = value;
                
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
                        if (toOneServerObject.isDeleted &&
                            [toOneServerObject.lastModificationDate compare:[TKDB defaultDB].lastSyncDate] == NSOrderedAscending) {
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
            else if ([value isKindOfClass:[PFRelation class]]) {
                
                PFRelation *relation = value;
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
                            if (serverRelatedObject.isDeleted &&
                                [serverRelatedObject.lastModificationDate compare:[TKDB defaultDB].lastSyncDate] == NSOrderedAscending) {
//                                [arrServerObjects addObject:[NSNull null]];
                            }
                            else {
                                [arrServerObjects addObject:serverRelatedObject];
                            }
                        }
                        [relatedObjects setObject:arrServerObjects forKey:key];
                        [subTask setResult:arrServerObjects];
                    }
                    return nil;
                }];
            }
            else if ([value isKindOfClass:[PFFile class]]) {
                PFFile *file = value;
                // save the file if it doesn't exist
                // get the path
                [[file tk_getDataAsync] continueWithBlock:^id(BFTask *task) {
                    if (task.result) {
                        NSString *fieldKey = [key stringByAppendingString:kTKDBBinaryFieldKeySuffix];
                        NSString *relativePath = parseObject[fieldKey];
                        if (relativePath.length) {
                            NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:relativePath];
                            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:path];
                            if (fileExists) {
                                // remove
                                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                            }
                            // save the new file
                            NSData *data = task.result;
                            NSString *directory = [path stringByDeletingLastPathComponent];
                            if ([[NSFileManager defaultManager] fileExistsAtPath:directory] == NO) {
                                [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
                            }
                            [data writeToFile:path atomically:YES];
                        }
                        
                        [subTask setResult:value];
                    }
                    else {
                        [subTask setError:task.error];
                    }

                    return nil;
                }];
            }
            else {
                if (value == nil) {
                    value = [NSNull null];
                }
                [dictAttributes setValue:value forKey:key];
                if ([key hasSuffix:kTKDBBinaryFieldKeySuffix]) {
                    dictBinaryKeysAttributes[key] = value;
                }
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
                serverObject.binaryKeysFields = dictBinaryKeysAttributes;
                
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

- (BFTask *)downloadUpdatedObjectsAsyncForEntity:(NSString *)entityName {
    return [[BFTask taskWithResult:nil] continueWithBlock:^id(BFTask *task) {
        
        PFQuery *query = [PFQuery queryWithClassName:entityName];
        if ([[TKDB defaultDB].lastSyncDate isEqualToDate:[NSDate dateWithTimeIntervalSince1970:0]]) {
            [query whereKey:@"isDeleted" equalTo:@NO];
        }
        [query whereKey:@"updatedAt" greaterThan:[TKDB defaultDB].lastSyncDate];
        
        
        return [[query tk_findObjectsAsync] continueWithSuccessBlock:^id(BFTask *task) {
            
            NSMutableArray *arrayServerObjects = [NSMutableArray array];
            NSArray *parseObjects = task.result;
            NSMutableArray *tasks = @[].mutableCopy;
            
            // Convert objects to server objects.
            for (PFObject *parseObject in parseObjects) {
                // ignore anonymous data
                if (parseObject.ACL == nil) {
                    continue;
                }
                
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

- (BFTask *)uploadInsertedObjectsAsync:(NSArray *)serverObjects {
    
    if ([serverObjects count] == 0) {
        return [BFTask taskWithResult:@[]];
    }
    else {
        return [[BFTask taskWithResult:nil] continueWithBlock:^id(BFTask *task) {
            NSMutableDictionary __block *dictServerObjects = [NSMutableDictionary dictionary];
            NSMutableArray __block *arrayParseObjects = [NSMutableArray array];
            NSMutableDictionary __block *dictParseObjects = [NSMutableDictionary dictionary];
            
            NSMutableArray __block *arrayParseFiles = [NSMutableArray array];
            NSMutableDictionary __block *dictParseFiles = [NSMutableDictionary dictionary];
            
            self.sessionFiles = [NSMutableDictionary dictionaryWithCapacity:serverObjects.count];
            NSMutableDictionary __block *session = self.sessionFiles;
            
            for (TKServerObject *serverObject in serverObjects) {
                // Put the object in the dictionary to be later retrieved for setting relationships.
                [dictServerObjects setObject:serverObject forKey:serverObject.uniqueObjectID];
                
                // Create Parse object.
                PFObject *parseObject = [self newParseObjectBasicInfoForServerObject:serverObject];

                if ([serverObject.binaryKeysFields count]) {
                    // get binary fields
                    NSMutableDictionary *objectFiles = [NSMutableDictionary dictionaryWithCapacity:serverObject.binaryKeysFields.count];
                    for (NSString *key in serverObject.binaryKeysFields) {
                        // get the file
                        NSString *relativePath = serverObject.binaryKeysFields[key];
                        if ([relativePath isKindOfClass:[NSNull class]]) {
                            // ignore
                        }
                        else if (relativePath && relativePath.length) {
                            NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:relativePath];
                            PFFile *file = [PFFile fileWithName:[relativePath lastPathComponent] contentsAtPath:path];
                            objectFiles[key] = file;
                            [arrayParseFiles addObject:file];
                            dictParseFiles[serverObject.uniqueObjectID] = file;
                        }
                    }
                    session[serverObject.uniqueObjectID] = objectFiles;
                }
                
                [arrayParseObjects addObject:parseObject];
                dictParseObjects[serverObject.uniqueObjectID] = parseObject;
            }

            if ([self.delegate respondsToSelector:@selector(parseSyncManager:willUploadParseObject:withServerObject:)]) {
                for (TKServerObject *serverObject in serverObjects) {
                    
                    PFObject *parseObj = dictParseObjects[serverObject.uniqueObjectID];
                    
                    [self.delegate parseSyncManager:self willUploadParseObject:parseObj withServerObject:serverObject];
                }
            }

            return [[PFObject tk_saveAllAsync:arrayParseObjects] continueWithBlock:^id(BFTask *task) {
                if (task.error) {
                    return [BFTask taskWithError:task.error];
                }
                else {
                    if ([arrayParseFiles count]) {
                        // upload files async
                        NSMutableArray *filesTasks = [NSMutableArray arrayWithCapacity:arrayParseFiles.count];
                        for (NSString *key in dictParseFiles) {
                            PFFile *file = dictParseFiles[key];
                            [filesTasks addObject:[file tk_saveAsync]];
                        }
                        
                        return [[BFTask taskForCompletionOfAllTasks:filesTasks] continueWithBlock:^id(BFTask *task) {
                            for (PFObject *parseObject in arrayParseObjects) {
                                NSString *uniqueID = [parseObject valueForKey:kTKDBUniqueIDField];
                                TKServerObject *serverObject = (TKServerObject *)dictServerObjects[uniqueID];
                                serverObject.serverObjectID = [parseObject objectId];
                                [[TKDBCacheManager sharedManager] mapServerObjectWithID:serverObject.serverObjectID toUniqueObjectWithID:serverObject.uniqueObjectID];
                            }
                            return [BFTask taskWithResult:[dictServerObjects allValues]];
                        }];
                    }
                    else {
                        for (PFObject *parseObject in arrayParseObjects) {
                            NSString *uniqueID = [parseObject valueForKey:kTKDBUniqueIDField];
                            TKServerObject *serverObject = (TKServerObject *)dictServerObjects[uniqueID];
                            serverObject.serverObjectID = [parseObject objectId];
                            [[TKDBCacheManager sharedManager] mapServerObjectWithID:serverObject.serverObjectID toUniqueObjectWithID:serverObject.uniqueObjectID];
                        }
                        return [BFTask taskWithResult:[dictServerObjects allValues]];
                    }
                }
            }];
        }];
    }
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
                // update parse with null values
                for (NSString *key in serverObject.attributeValues) {
                    if ([serverObject.attributeValues[key] isEqual:[NSNull null]]) {
                        [parseObject removeObjectForKey:key];
                    }
                }
                NSDictionary *serverObjectFiles = self.sessionFiles[serverObject.uniqueObjectID];
                if ([serverObject.binaryKeysFields count]) {
                    // get binary fields
                    
                    for (NSString *key in serverObject.binaryKeysFields) {
                        
                        NSString *relativePath = serverObject.binaryKeysFields[key];
                        if ([relativePath isKindOfClass:[NSNull class]]) {
                            // delete
                            // no file, clear parseObject
                            NSString *binaryField = [key stringByReplacingCharactersInRange:[key rangeOfString:kTKDBBinaryFieldKeySuffix options:NSBackwardsSearch] withString:@""];
                            [parseObject removeObjectForKey:binaryField];
                        }
                        else if (relativePath && [relativePath length] > 0) {
                            // there is a file
                            // get the file
                            PFFile *file = serverObjectFiles[key];
                            NSString *binaryField = [key stringByReplacingCharactersInRange:[key rangeOfString:kTKDBBinaryFieldKeySuffix options:NSBackwardsSearch] withString:@""];
                            if (!file) {
                                // check for current file
                                file = parseObject[binaryField];
                                NSString *filename = [relativePath lastPathComponent];
                                if ([file.name hasSuffix:filename]) {
                                    // same file no need to upload
                                }
                                else {
                                    // need to upload the new file.
                                    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:relativePath];
                                    if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO) {
                                        // file is not downloaded yet.
                                    }
                                    else {
                                        file = [PFFile fileWithName:filename.lastPathComponent contentsAtPath:path];
                                        [[file tk_saveAsync] continueWithBlock:^id(BFTask *task) {
                                            parseObject[binaryField] = file;
                                            [parseObject tk_saveAsync];
                                            return nil;
                                        }];
                                    }
                                }
                            }
                            else {
                                // new file assign to barse
                                parseObject[binaryField] = file;
                            }
                            
                        }
                        else {
                            // no file, clear parseObject
                            NSString *binaryField = [key stringByReplacingCharactersInRange:[key rangeOfString:kTKDBBinaryFieldKeySuffix options:NSBackwardsSearch] withString:@""];
                            [parseObject removeObjectForKey:binaryField];
                        }
                    }
                }
                
                
                if ([self.delegate respondsToSelector:@selector(parseSyncManager:willUploadParseObject:withServerObject:)]) {
                    [self.delegate parseSyncManager:self willUploadParseObject:parseObj withServerObject:serverObject];
                }

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


- (BFTask *)countOfObjectsForEntity:(NSString *)entityName {
    return [[BFTask taskWithResult:nil] continueWithBlock:^id(BFTask *task) {
        PFQuery *query = [PFQuery queryWithClassName:entityName];
        [query whereKey:@"updatedAt" greaterThan:[TKDB defaultDB].lastSyncDate];
        
        return [query tk_countOfObjectsAsync];
    }];
}
- (void) updateLastSyncCountAndDate
{
    PFUser *currentUser = [PFUser currentUser];
    [currentUser setObject:@([currentUser[@"NumOfSyncs"] integerValue] + 1) forKey:@"NumOfSyncs"];
    [currentUser setObject:[TKDB defaultDB].lastSyncDate forKey:@"LastSyncDate"];
    
    [currentUser saveInBackground];
}


@end
