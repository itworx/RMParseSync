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
        NSMutableDictionary *dictBinaryAttributes = [NSMutableDictionary dictionary];
        NSMutableDictionary *dictBinaryKeysAttributes = [NSMutableDictionary dictionary];
        NSMutableDictionary *relatedObjects = [NSMutableDictionary dictionary];
        
        NSMutableArray *tasks = @[].mutableCopy;
        
        for (NSString *key in [parseObject allKeys]) {
            if ([key isEqualToString:kTKDBIsDeletedField]) {
                continue;
            }
            
            BFTaskCompletionSource *subTask = [BFTaskCompletionSource taskCompletionSource];
            id value = [parseObject valueForKey:key];
            if ([value isKindOfClass:[PFObject class]]) {

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
                            [data writeToFile:path atomically:YES];
                        }
                        
                        [subTask setResult:value];
                    }
                    else {
                        [subTask setError:task.error];
                    }

                    return nil;
                }];
                
                dictBinaryAttributes[key] = value;
            }
            else {
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
                        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:relativePath];
                        PFFile *file = [PFFile fileWithName:[relativePath lastPathComponent] contentsAtPath:path];
                        objectFiles[key] = file;
//                        [serverObject.binaryValues setObject:file forKey:key];
                        [arrayParseFiles addObject:file];
                        dictParseFiles[serverObject.uniqueObjectID] = file;
                    }
                    session[serverObject.uniqueObjectID] = objectFiles;
                }
                
                [arrayParseObjects addObject:parseObject];
                dictParseObjects[serverObject.uniqueObjectID] = parseObject;
                
                /*
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
                */
            }
            /*
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
            */
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
                NSDictionary *serverObjectFiles = self.sessionFiles[serverObject.uniqueObjectID];
                if ([serverObject.binaryKeysFields count]) {
                    // get binary fields
                    for (NSString *key in serverObject.binaryKeysFields) {
                        // get the file
                        PFFile *file = serverObjectFiles[key];
                        NSString *binaryField = [key stringByReplacingCharactersInRange:[key rangeOfString:kTKDBBinaryFieldKeySuffix options:NSBackwardsSearch] withString:@""];
                        if (!file) {
                            // check for current file
                            file = parseObject[binaryField];
                            NSString *filename = [serverObject.binaryKeysFields[key] lastPathComponent];
                            if ([file.name hasSuffix:filename]) {
                                // same file no need to upload
                            }
                            else {
                                // need to upload the new file.
                                NSString *relativePath = serverObject.binaryKeysFields[key];
                                NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:relativePath];
                                file = [PFFile fileWithName:filename.lastPathComponent contentsAtPath:path];
                                [[file tk_saveAsync] continueWithBlock:^id(BFTask *task) {
                                    parseObject[binaryField] = file;
                                    [parseObject tk_saveAsync];
                                    return nil;
                                }];
                            }
                        }
                        else {
                            // new file assign to barse
                            parseObject[binaryField] = file;
                        }
                    }
                }
                
                /*
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
                */
                
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
