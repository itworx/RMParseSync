//
//  TKDBCacheEntry.m
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-06.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "TKDBCacheEntry.h"

#define kLocalObjectID          @"LocalID"
#define kServerObjectID         @"ServerID"
#define kUniqueObjectID         @"UniqueID"
#define kEntityName             @"Entity"
#define kEntryType              @"Type"
#define kChangedFields          @"ChangedFields"
#define kEntryState             @"State"
#define kOriginal               @"Original"


@implementation TKDBCacheEntry

- (id) init {
    self = [super init];
    if (self) {
        self.entryState = TKDBCacheSaved;
    }
    return self;
}


- (id) initWithType:(TKDBCacheEntryType)type {
    self = [self init];
    if (self) {
        self.entryType = type;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [self init];
    if (self) {
        self.localObjectIDURL = [decoder decodeObjectForKey:kLocalObjectID];
        self.serverObjectID = [decoder decodeObjectForKey:kServerObjectID];
        self.uniqueObjectID = [decoder decodeObjectForKey:kUniqueObjectID];
        self.entryType = [decoder decodeIntForKey:kEntryType];
        self.changedFields = [decoder decodeObjectForKey:kChangedFields];
        self.entity = [decoder decodeObjectForKey:kEntityName];
        self.entryState = [decoder decodeIntForKey:kEntryState];
        self.originalObject = [decoder decodeObjectForKey:kOriginal];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.localObjectIDURL forKey:kLocalObjectID];
    [encoder encodeObject:self.serverObjectID forKey:kServerObjectID];
    [encoder encodeObject:self.uniqueObjectID forKey:kUniqueObjectID];
    [encoder encodeInt:self.entryType forKey:kEntryType];
    [encoder encodeObject:self.changedFields forKey:kChangedFields];
    [encoder encodeObject:self.entity forKey:kEntityName];
    [encoder encodeInt:self.entryState forKey:kEntryState];
    [encoder encodeObject:self.originalObject forKey:kOriginal];
}

@end
