//
//  TKDBCacheManager.m
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-06.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "TKDBCacheManager.h"

#define kInsertsDict @"inserts"
#define kUpdatesDict @"updates"
#define kDeletesDict @"deletes"
#define kShadowsDict @"shadows"

@implementation TKDBCacheManager {
    NSMutableDictionary *dictCacheInserts;
    NSMutableDictionary *dictCacheUpdates;
    NSMutableDictionary *dictCacheDeletes;
    
    NSMutableDictionary *dictUniqueIDtoLocal;
    NSMutableDictionary *dictUniqueIDtoServer;
    
    BOOL dirtyMode;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        dictCacheInserts = [NSMutableDictionary dictionary];
        dictCacheUpdates = [NSMutableDictionary dictionary];
        dictCacheDeletes = [NSMutableDictionary dictionary];
        dictUniqueIDtoLocal = [NSMutableDictionary dictionary];
        dictUniqueIDtoServer = [NSMutableDictionary dictionary];
        
        self.dictCacheFilename =  @"dbcache.plist";
        self.dictLocalMappingFilename =  @"dblocalmapping.plist";
        self.dictServerMappingFilename =  @"dbservermapping.plist";
    }
    return self;
}

+ (instancetype)sharedManager
{
    static dispatch_once_t pred = 0;
    __strong static TKDBCacheManager* _sharedManager = nil;
    dispatch_once(&pred, ^{
        _sharedManager = [[self alloc] init];
    });
    
    return _sharedManager;
}

- (void) loadFromFileSystem {
    NSMutableDictionary __weak *weakInserts = dictCacheInserts;
    NSMutableDictionary __weak *weakUpdates = dictCacheUpdates;
    NSMutableDictionary __weak *weakDeletes = dictCacheDeletes;
    
    TKDBCacheManager __weak *weakself = self;
    
    dispatch_async(dispatch_queue_create("dbcache", nil), ^{
        NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
        NSString *applicationStorageDirectory = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:applicationName];
        NSDictionary *dictCache = [NSKeyedUnarchiver unarchiveObjectWithFile:[applicationStorageDirectory stringByAppendingPathComponent:weakself.dictCacheFilename]];
        [weakInserts removeAllObjects];
        [weakUpdates removeAllObjects];
        [weakDeletes removeAllObjects];
        
        [weakInserts addEntriesFromDictionary:dictCache[kInsertsDict]];
        [weakUpdates addEntriesFromDictionary:dictCache[kUpdatesDict]];
        [weakDeletes addEntriesFromDictionary:dictCache[kDeletesDict]];
        
        NSDictionary *dictLocalMapping = [NSKeyedUnarchiver unarchiveObjectWithFile:[applicationStorageDirectory stringByAppendingPathComponent:weakself.dictLocalMappingFilename]];
        [dictUniqueIDtoLocal removeAllObjects];
        
        [dictUniqueIDtoLocal addEntriesFromDictionary:dictLocalMapping];
        
        NSDictionary *dictServerMapping = [NSKeyedUnarchiver unarchiveObjectWithFile:[applicationStorageDirectory stringByAppendingPathComponent:weakself.dictServerMappingFilename]];
        [dictUniqueIDtoServer removeAllObjects];
        
        [dictUniqueIDtoServer addEntriesFromDictionary:dictServerMapping];
    });
}

- (void) saveToFileSystem {
    if (dirtyMode) {
        return;
    }
    
    NSDictionary __block *dictCache = @{kInsertsDict: dictCacheInserts, kUpdatesDict: dictCacheUpdates, kDeletesDict: dictCacheDeletes};
    NSDictionary __block *dictLocalMapping = dictUniqueIDtoLocal;
    NSDictionary __block *dictServerMapping = dictUniqueIDtoServer;
    
    TKDBCacheManager __weak *weakself = self;
    
    dispatch_async(dispatch_queue_create("dbcache", nil), ^{
        NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
        NSString *applicationStorageDirectory = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:applicationName];
        
        if(![[NSFileManager defaultManager] fileExistsAtPath:applicationStorageDirectory]) {
            __autoreleasing NSError *error;
            BOOL ret = [[NSFileManager defaultManager] createDirectoryAtPath:applicationStorageDirectory withIntermediateDirectories:YES attributes:nil error:&error];
            if(!ret) {
                exit(0);
            }
        }
        
        [NSKeyedArchiver archiveRootObject:dictCache toFile:[applicationStorageDirectory stringByAppendingPathComponent:weakself.dictCacheFilename]];
        [NSKeyedArchiver archiveRootObject:dictLocalMapping toFile:[applicationStorageDirectory stringByAppendingPathComponent:weakself.dictLocalMappingFilename]];
        [NSKeyedArchiver archiveRootObject:dictServerMapping toFile:[applicationStorageDirectory stringByAppendingPathComponent:weakself.dictServerMappingFilename]];
    });
}

- (void) addCacheEntry:(TKDBCacheEntry *)entry {
    switch (entry.entryType) {
        case TKDBCacheInsert:
            dictCacheInserts[entry.uniqueObjectID] = entry;
            break;
        case TKDBCacheUpdate:
            dictCacheUpdates[entry.uniqueObjectID] = entry;
            break;
        case TKDBCacheDelete:
            dictCacheDeletes[entry.uniqueObjectID] = entry;
            break;
        default:
            break;
    }
}

- (void) removeEntry:(TKDBCacheEntry*)entry {
    switch (entry.entryType) {
        case TKDBCacheInsert:
            [dictCacheInserts removeObjectForKey:entry.uniqueObjectID];
            break;
        case TKDBCacheUpdate:
            [dictCacheUpdates removeObjectForKey:entry.uniqueObjectID];
            break;
        case TKDBCacheDelete:
            [dictCacheDeletes removeObjectForKey:entry.uniqueObjectID];
            break;
        default:
            break;
    }
}

- (void) clearCache {
    [dictCacheInserts removeAllObjects];
    [dictCacheUpdates removeAllObjects];
    [dictCacheDeletes removeAllObjects];
}

- (TKDBCacheEntry*) entryForObjectID:(NSString*)objectID withType:(TKDBCacheEntryType)type {
    switch (type) {
        case TKDBCacheInsert:
            return dictCacheInserts[objectID];
        case TKDBCacheUpdate:
            return dictCacheUpdates[objectID];
        case TKDBCacheDelete:
            return dictCacheDeletes[objectID];
        default:
            break;
    }
}

- (NSDictionary*) dictInserts {
    return dictCacheInserts;
}

- (NSDictionary*) dictUpdates {
    return dictCacheUpdates;
}

- (NSDictionary*) dictDeletes {
    return dictCacheDeletes;
}

- (void) mapLocalObjectWithURL:(NSString*)url toUniqueObjectWithID:(NSString*)uniqueID {
    dictUniqueIDtoLocal[uniqueID] = url;
}

- (void) mapServerObjectWithID:(NSString*)serverID toUniqueObjectWithID:(NSString*)uniqueID {
    dictUniqueIDtoServer[uniqueID] = serverID;
    
}

- (NSString*) localObjectURLForUniqueObjectID:(NSString*)uniqueID {
    return dictUniqueIDtoLocal[uniqueID];
}

- (NSString*) serverObjectIDForUniqueObjectID:(NSString*)uniqueID {
    return dictUniqueIDtoServer[uniqueID];
}

- (void) clearMappingsForObjectWithUniqueID:(NSString*)uniqueID {
    dictUniqueIDtoLocal[uniqueID] = nil;
    dictUniqueIDtoServer[uniqueID] = nil;
}

- (void) clearMappings {
    [dictUniqueIDtoLocal removeAllObjects];
    [dictUniqueIDtoServer removeAllObjects];
}

- (void) startCheckpoint {
    [self saveToFileSystem];
    dirtyMode = YES;
}

- (void) endCheckpointSuccessfully {
    dirtyMode = NO;
}

- (void) rollbackToCheckpoint {
    [self loadFromFileSystem];
    dirtyMode = NO;
}

@end