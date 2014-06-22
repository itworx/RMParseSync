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


@implementation TKParseServerSyncManager

- (TKServerObject*) serverObjectBasicInfoForParseObject:(PFObject*)parseObject {
    TKServerObject *serverObject = [[TKServerObject alloc] init];
    serverObject.entityName = parseObject.parseClassName;
    NSEntityDescription *entity = [[TKDB defaultDB].rootContext.persistentStoreCoordinator.managedObjectModel entitiesByName][serverObject.entityName];
    Class managedObjectClass = NSClassFromString(entity.managedObjectClassName);
    serverObject.primaryKeyFields = [managedObjectClass primaryKeyFields];
//    serverObject.entityClass = entity.managedObjectClassName;
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
    [dictAttributes setObject:serverObject.lastModificationDate forKey:kTKDBUpdatedDateField];// for deleted objects
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

- (BFTask *)uploadInsertedObjectsAsync:(NSArray *)serverObjects {
    BFTaskCompletionSource *task = [BFTaskCompletionSource taskCompletionSource];
    
    if ([serverObjects count] == 0) {
        [task setResult:@[]];
    }
    else {
        NSMutableDictionary __block *dictServerObjects = [NSMutableDictionary dictionary];
        NSMutableArray __block *arrayParseObjects = [NSMutableArray array];
        NSMutableDictionary __block *dictParseObjects = [NSMutableDictionary dictionary];
        
        for (TKServerObject *serverObject in serverObjects) {
            // Put the object in the dictionary to be later retrieved for setting relationships.
            [dictServerObjects setObject:serverObject forKey:serverObject.uniqueObjectID];
            
            // Create Parse object.
            PFObject *parseObject = [self newParseObjectBasicInfoForServerObject:serverObject];
            [arrayParseObjects addObject:parseObject];
            dictParseObjects[serverObject.uniqueObjectID] = parseObject;
            
            if ([serverObject.entityName isEqualToString:@"AccessCode"]) {
                // create a new PFRole for student and parent
                NSString *parentRoleName = serverObject.attributeValues[@"parentRoleName"];
                PFRole *parentRole = [PFRole roleWithName:parentRoleName];
                [parseObject setValue:parentRole forKey:@"parentRole"];
                
                NSString *studentRoleName = serverObject.attributeValues[@"studentRoleName"];
                PFRole *studentRole = [PFRole roleWithName:studentRoleName];
                [parseObject setValue:studentRole forKey:@"studentRole"];
            }
            else if ([serverObject.entityName isEqualToString:@"Student"]) {
                
                [self setACLForParseObject:parseObject withStudentServerObject:serverObject];
            }
            else {
                // check for student related data
                id studentVal = [serverObject.relatedObjects valueForKey:@"student"];
                if (!studentVal) {
                    studentVal = [serverObject.relatedObjects valueForKey:@"students"];
                }
                if (studentVal) {
                    // has a student relation
                    // get that student from db
                    // check the AccessCodes table
                    if ([studentVal isKindOfClass:[TKServerObject class]]) {
                        // to-one relation
                        [self setACLForParseObject:parseObject withStudentServerObject:studentVal];
                    }
                    else if ([studentVal isKindOfClass:[NSArray class]]) {
                        // to-many relation
                        NSArray *students = (NSArray *)studentVal;
                        for (TKServerObject *studentServerObject in students) {
                            [self setACLForParseObject:parseObject withStudentServerObject:studentServerObject];
                        }
                    }
                }
            }
        }
        
        for (TKServerObject *serverObject in serverObjects) {
            PFObject *parseObj = dictParseObjects[serverObject.uniqueObjectID];
            
            // check for attendancetype/ behaviorType/GradeType/GradableItem
            if ([serverObject.entityName isEqualToString:@"Attendancetype"]) {
                // check if it has attendances
                NSArray *attendances = serverObject.relatedObjects[@"attendances"];
                for (TKServerObject *attend in attendances) {
                    NSManagedObject *attendance = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:attend.localObjectIDURL]];
                    NSManagedObject *student = [attendance valueForKey:@"student"];
                    [self setACLForParseObject:parseObj withStudent:student];
                }
            }
            else if ([serverObject.entityName isEqualToString:@"Behaviortype"]) {
                // check if it has attendances
                NSArray *behaviors = serverObject.relatedObjects[@"behaviors"];
                for (TKServerObject *behavior in behaviors) {
                    NSManagedObject *behaviorObj = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:behavior.localObjectIDURL]];
                    NSManagedObject *student = [behaviorObj valueForKey:@"student"];
                    [self setACLForParseObject:parseObj withStudent:student];
                }
            }
            else if ([serverObject.entityName isEqualToString:@"Gradableitem"]) {
                // search across the grades, get student, add
                NSArray *grades = serverObject.relatedObjects[@"grades"];
                for (TKServerObject *grade in grades) {
                    NSManagedObject *gradeObject = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:grade.localObjectIDURL]];
                    NSManagedObject *student = [gradeObject valueForKey:@"student"];
                    [self setACLForParseObject:parseObj withStudent:student];
                }
            }
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

- (void)setACLForParseObject:(PFObject *)parseObject withStudentServerObject:(TKServerObject *)serverObject {
    
    NSManagedObject *studentManagedObject = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:serverObject.localObjectIDURL]];
    [self setACLForParseObject:parseObject withStudent:studentManagedObject];
}

- (void)setACLForParseObject:(PFObject *)parseObject withStudent:(NSManagedObject *)studentManagedObject {
    
    NSManagedObject *accessCode = [studentManagedObject valueForKey:@"accessCode"];
    
    NSString *parentRoleName = [accessCode valueForKey:@"parentRoleName"];
    if (parentRoleName) {
        [parseObject.ACL setReadAccess:YES forRoleWithName:parentRoleName];
    }
    
    NSString *studentRoleName = [accessCode valueForKey:@"studentRoleName"];
    if (studentRoleName) {
        [parseObject.ACL setReadAccess:YES forRoleWithName:studentRoleName];
    }
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
                
                
                // check for attendancetype/ behaviorType/GradeType/GradableItem
                if ([serverObject.entityName isEqualToString:@"Attendancetype"]) {
                    // check if it has attendances
                    NSArray *attendances = serverObject.relatedObjects[@"attendances"];
                    for (TKServerObject *attend in attendances) {
                        NSManagedObject *attendance = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:attend.localObjectIDURL]];
                        NSManagedObject *student = [attendance valueForKey:@"student"];
                        [self setACLForParseObject:parseObj withStudent:student];
                    }
                }
                else if ([serverObject.entityName isEqualToString:@"Behaviortype"]) {
                    // check if it has attendances
                    NSArray *behaviors = serverObject.relatedObjects[@"behaviors"];
                    for (TKServerObject *behavior in behaviors) {
                        NSManagedObject *behaviorObj = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:behavior.localObjectIDURL]];
                        NSManagedObject *student = [behaviorObj valueForKey:@"student"];
                        [self setACLForParseObject:parseObj withStudent:student];
                    }
                }
                else if ([serverObject.entityName isEqualToString:@"Gradableitem"]) {
                    // search across the grades, get student, add
                    NSArray *grades = serverObject.relatedObjects[@"grades"];
                    for (TKServerObject *grade in grades) {
                        NSManagedObject *gradeObject = [[TKDB defaultDB].syncContext objectWithURI:[NSURL URLWithString:grade.localObjectIDURL]];
                        NSManagedObject *student = [gradeObject valueForKey:@"student"];
                        [self setACLForParseObject:parseObj withStudent:student];
                    }
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
@end
