//
//  TKDBCacheEntry.h
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-06.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMParseSync.h"

/**
 *  Type of cache entry. Whether insert, update or delete.
 */
typedef enum : NSUInteger {
    TKDBCacheInsert,
    TKDBCacheUpdate,
    TKDBCacheDelete,
} TKDBCacheEntryType;

typedef enum : NSUInteger {
    TKDBCacheSaved,
    TKDBCachePendingSave
} TKDBCacheEntryState;

@interface TKDBCacheEntry : NSObject <NSCoding>

/**
 *  The managed object ID in URI form in the local database.
 */
@property (nonatomic, strong) NSString *localObjectIDURL;

/**
 *  The original object before update.
 */
@property (nonatomic) TKServerObject *originalObject;

/**
 *  The object's unique identifier.
 */
@property (nonatomic, strong) NSString *uniqueObjectID;

/**
 *  The object's server based unique identifier.
 */
@property (nonatomic, strong) NSString *serverObjectID;

/**
 *  Indicates whether the entity is temporary or not. An entry is
 *  TKDBCacheCreatedPendingSave if it is created during contextWillSave.
 *  It is TKDBCacheUpdatedPendingSave if updated during contextWillSave.
 *  Otherwise it is TKDBCacheSaved.
 */
@property (nonatomic) TKDBCacheEntryState entryState;

/**
 *  The object's entity.
 */
@property (nonatomic, strong) NSString *entity;

/**
 *  Type of entry whether insert, update or delete.
 */
@property (nonatomic) TKDBCacheEntryType entryType;

/**
 *  The changed keys of this object in case its an update event.
 */
@property (nonatomic, strong) NSMutableSet *changedFields;

/**
 *  The temporary changed fields of this object after a willSave
 *  event. This is to support the case where the save fails, and
 *  thus the sync module will only look at the changedFields
 *  dictionary.
 */
@property (nonatomic, strong) NSMutableSet *tempChangedFields;

/**
 * The Object's last modification date.
 *
 *  @discussion To handle Update-Delete conflicts, we need to know the deletion date to compare it with the update date.
 */
@property (nonatomic, strong) NSDate *lastModificationDate;

- (id) initWithType:(TKDBCacheEntryType)type;

@end
