//
//  TKServerObject.h
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-18.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMParseSync.h"

@interface TKServerObject : NSObject <NSCoding>

/**
 *  The name of the object's entity.
 */
@property (nonatomic, strong) NSString *entityName;

/**
 *  The object's server based unique identifier.
 */
@property (nonatomic, strong) NSString *serverObjectID;

/**
 *  The object's global unique identifier.
 */
@property (nonatomic, strong) NSString *uniqueObjectID;

/**
 *  The object's local URL.
 */
@property (nonatomic, strong) NSString *localObjectIDURL;

/**
 *  The values of this object's atributes.
 */
@property (nonatomic, strong) NSDictionary *attributeValues;

/**
 *  The object's last modification date.
 */
@property (nonatomic, strong) NSDate *creationDate;

/**
 *  The object's last modification date.
 */
@property (nonatomic, strong) NSDate *lastModificationDate;

/**
 *  An array of the attributes whose value has changed
 *  since the last sync.
 */
@property (nonatomic, strong) NSArray *changedAttributes;

/**
 *  Boolean indicating whether this is a deleted object.
 *  Used by the server to prevent loss of object in case
 *  a conflict happens later. If we delete an object from
 *  server on sync, it will be lost forever and cannot be
 *  retrieved again using the same server ID.
 */
@property (nonatomic) BOOL isDeleted;

/**
 *  Indicates this object is a shadow object -> backup
 *  of original version of updated object.
 */
@property (nonatomic) BOOL isOriginal;

/**
 *  The related objects. The key is the destination entity
 *  and the value is a single object (to-one) or an array
 *  of objects (to-many).
 */
@property (nonatomic, strong) NSDictionary *relatedObjects;

- (instancetype) initWithUniqueID:(NSString*)uniqueID;

@end

typedef enum : NSUInteger {
    TKDBMergeLocalWins,
    TKDBMergeServerWins,
    TKDBMergeBothUpdated,
} TKDBConflictResolutionType;

@interface TKServerObjectConflictPair: NSObject

@property (nonatomic, strong) TKServerObject *localObject;
@property (nonatomic, strong) TKServerObject *serverObject;
@property (nonatomic, strong) TKServerObject *shadowObject;
@property (nonatomic) TKDBConflictResolutionType resolutionType;
@property (nonatomic, strong) TKServerObject *outputObject;

- (id) initWithServerObject:(TKServerObject*)serverObject localObject:(TKServerObject*)localObject shadowObject:(TKServerObject*)shadowObject;

@end
