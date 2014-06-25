//
//  TKDBCacheManager.h
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-06.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TKDBCacheEntry.h"
#import "RMParseSync.h"

@interface TKDBCacheManager : NSObject

/**
 *  default is dbcache.plist;
 */
@property (nonatomic, strong) NSString *dictCacheFilename;

/**
 *  default is dblocalmapping.plist;
 */
@property (nonatomic, strong) NSString *dictLocalMappingFilename;

/**
 *  default is dbservermapping.plist;
 */
@property (nonatomic, strong) NSString *dictServerMappingFilename;

+ (TKDBCacheManager*) sharedManager;

- (void) addCacheEntry:(TKDBCacheEntry*)entry;
- (void) removeEntry:(TKDBCacheEntry*)entry;
- (TKDBCacheEntry*) entryForObjectID:(NSString*)objectID withType:(TKDBCacheEntryType)type;

- (NSDictionary*) dictInserts;
- (NSDictionary*) dictUpdates;
- (NSDictionary*) dictDeletes;
- (void) loadFromFileSystem;
- (void) saveToFileSystem;

- (void) mapLocalObjectWithURL:(NSString*)url toUniqueObjectWithID:(NSString*)uniqueID;
- (void) mapServerObjectWithID:(NSString*)serverID toUniqueObjectWithID:(NSString*)uniqueID;
- (NSString*) localObjectURLForUniqueObjectID:(NSString*)uniqueID;
- (NSString*) serverObjectIDForUniqueObjectID:(NSString*)uniqueID;
- (void) clearMappings;
- (void) clearMappingsForObjectWithUniqueID:(NSString*)uniqueID;

/**
 *  Used to begin syncing, creating a checkpoint in
 *  cache so that if a failure occurs, the cache can
 *  be restored.
 */
- (void) startCheckpoint;

/**
 *  Indicates that sync has been successful and so
 *  the cache can be saved and used.
 */
- (void) endCheckpointSuccessfully;

/**
 *  Clear cache.
 */
- (void) clearCache;

/**
 *  Indicates that sync failed, and the manager should
 *  rollback to the checkpoint.
 */
- (void) rollbackToCheckpoint;

@end
