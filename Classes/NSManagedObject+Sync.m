//
//  NSManagedObject+Sync.m
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-06.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//


#import "NSManagedObject+Sync.h"
#import "NSEntityDescription+ObjectID.h"

@implementation NSManagedObject (Sync)

#define DATE_ATTR_PREFIX @"dAtEaTtr:"
#define CLASS_PREFIX @"TK"

#pragma mark -

#pragma mark Date methods

- (NSDate *) tk_creationDate {
    return [self valueForKey:kTKDBCreatedDateField];
}

- (NSDate *) tk_lastModificationDate {
    return [self valueForKey:kTKDBUpdatedDateField];
}

#pragma mark ID methods

- (NSString *) tk_localURL {
    return [[[self objectID] URIRepresentation] absoluteString];
}

- (NSString *) tk_uniqueObjectID {
    return [self valueForKey:kTKDBUniqueIDField];
}

- (NSString *) tk_serverObjectID {
    return [self valueForKey:kTKDBServerIDField];
}

- (id) assignUniqueObjectID {
    if ([self valueForKey:kTKDBUniqueIDField] == nil) {
        // generate a uniqueID
        id objectId = nil;
        CFUUIDRef uuid = CFUUIDCreate(CFAllocatorGetDefault());
        objectId = (__bridge_transfer NSString *)CFUUIDCreateString(CFAllocatorGetDefault(), uuid);
        [self setValue:objectId forKey:kTKDBUniqueIDField];
        CFRelease(uuid);
    }
    return [self tk_uniqueObjectID];
}

#pragma mark Dictionary conversion methods

- (NSDictionary*) attributeDictionary {
    NSArray* attributes = [[[self entity] attributesByName] allKeys];
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:
                                 [attributes count] + 1];
    
    for (NSString* attr in attributes) {
        if ([attr isEqualToString:kTKDBServerIDField] || [attr isEqualToString:kTKDBUniqueIDField] || [attr isEqualToString:kTKDBCreatedDateField] ||
            [attr isEqualToString:kTKDBIsDeletedField]) {
            continue;
        }
        
        NSObject* value = [self valueForKey:attr];
        
        if (value != nil) {
            [dict setObject:value forKey:attr];
//            if ([value isKindOfClass:[NSDate class]]) {
//                NSTimeInterval date = [(NSDate*)value timeIntervalSinceReferenceDate];
//                NSString *dateAttr = [NSString stringWithFormat:@"%@%@", DATE_ATTR_PREFIX, attr];
//                [dict setObject:[NSNumber numberWithDouble:date] forKey:dateAttr];
//            } else {
//                [dict setObject:value forKey:attr];
//            }
        }
    }
    
    return dict;
}

- (NSDictionary*) toOneRelationshipDictionary {
    NSArray* relationships = [[[self entity] relationshipsByName] allKeys];
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:
                                 [relationships count] + 1];
    
    for (NSString* relationship in relationships) {
        NSObject* value = [self valueForKey:relationship];
        
        if ([value isKindOfClass:[NSManagedObject class]]) {
            // To-one relationship
            
            NSManagedObject* relatedObject = (NSManagedObject*) value;
            TKServerObject *serverObject = [[TKServerObject alloc] initWithUniqueID:relatedObject.tk_uniqueObjectID];
            serverObject.serverObjectID = relatedObject.tk_serverObjectID;
            serverObject.localObjectIDURL = relatedObject.tk_localURL;
            serverObject.entityName = relatedObject.entity.name;
            [dict setObject:serverObject forKey:relationship];
        }
        else {
            NSRelationshipDescription *relationshipDesc = [[self entity] relationshipsByName][relationship];
            if (!relationshipDesc.isToMany) {
                [dict setObject:[NSNull null] forKey:relationship];
            }
        }
    }
    
    return dict;
}

- (NSDictionary*) toManyRelationshipDictionary {
    NSArray* relationships = [[[self entity] relationshipsByName] allKeys];
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:
                                 [relationships count] + 1];
    
    for (NSString* relationship in relationships) {
        NSObject* value = [self valueForKey:relationship];
        
        if ([value isKindOfClass:[NSSet class]]) {
            // To-many relationship
            
            // The core data set holds a collection of managed objects
            NSSet* relatedObjects = (NSSet*) value;
            
            // Our set holds a collection of dictionaries
            NSMutableArray* dictSet = [NSMutableArray arrayWithCapacity:[relatedObjects count]];
            
            for (NSManagedObject* relatedObject in relatedObjects) {
                TKServerObject *serverObject = [[TKServerObject alloc] initWithUniqueID:relatedObject.tk_uniqueObjectID];
                serverObject.serverObjectID = relatedObject.tk_serverObjectID;
                serverObject.localObjectIDURL = relatedObject.tk_localURL;
                serverObject.entityName = relatedObject.entity.name;
                [dictSet addObject:serverObject];
            }
            
            [dict setObject:[NSArray arrayWithArray:dictSet] forKey:relationship];
        }
        else if ([value isKindOfClass:[NSOrderedSet class]]) {
            // To-many relationship
            
            // The core data set holds an ordered collection of managed objects
            NSOrderedSet* relatedObjects = (NSOrderedSet*) value;
            
            // Our ordered set holds a collection of dictionaries
            NSMutableArray* dictSet = [NSMutableArray arrayWithCapacity:[relatedObjects count]];
            
            for (NSManagedObject* relatedObject in relatedObjects) {
                TKServerObject *serverObject = [[TKServerObject alloc] initWithUniqueID:relatedObject.tk_uniqueObjectID];
                serverObject.serverObjectID = relatedObject.tk_serverObjectID;
                serverObject.localObjectIDURL = relatedObject.tk_localURL;
                serverObject.entityName = relatedObject.entity.name;
                [dictSet addObject:serverObject];
            }
            
            [dict setObject:[NSSet setWithArray:dictSet] forKey:relationship];
        }
        else if (value == nil) {
            NSRelationshipDescription *relationshipDesc = [[self entity] relationshipsByName][relationship];
            if (relationshipDesc.isToMany) {
                [dict setObject:[NSSet set] forKey:relationship];
            }
        }
    }
    return dict;
}

- (TKServerObject*) toServerObject {
    TKServerObject *serverObject = [[TKServerObject alloc] init];
    serverObject.entityName = [self.entity name];
    serverObject.uniqueObjectID = self.tk_uniqueObjectID;
    serverObject.serverObjectID = self.tk_serverObjectID;
    serverObject.localObjectIDURL = [[[self objectID] URIRepresentation] absoluteString];
    serverObject.isDeleted = NO;
    serverObject.attributeValues = [self attributeDictionary];
    serverObject.creationDate = [self tk_creationDate];
    serverObject.lastModificationDate = [self tk_lastModificationDate];
    NSMutableDictionary *dictRelationships = [NSMutableDictionary dictionary];
    [dictRelationships addEntriesFromDictionary:[self toOneRelationshipDictionary]];
    [dictRelationships addEntriesFromDictionary:[self toManyRelationshipDictionary]];
    serverObject.relatedObjects = dictRelationships;
    
    return serverObject;
}

#pragma mark Other Helpers

- (TKServerObject*) toServerObjectInContext:(NSManagedObjectContext*)context {
    NSManagedObject *original = [context objectWithID:[self objectID]];
    return [original toServerObject];
}

@end
