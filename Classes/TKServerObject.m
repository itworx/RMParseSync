//
//  TKServerObject.m
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-18.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "TKServerObject.h"

#define kEntityName         @"EntityName"
#define kServerID           @"ServerID"
#define kUniqueID           @"UniqueID"
#define kLocalURL           @"LocalURL"
#define kAttributes         @"Attributes"
#define kCreationDate       @"CreationDate"
#define kLastModDate        @"LastModDate"
#define kChangedAttributes  @"ChangedAttrib"
#define kIsDeleted          @"IsDeleted"
#define kIsOriginal         @"IsOriginal"
#define kRelatedObjects     @"RelatedObjects"
#define kBinaryFields       @"BinaryFields"

@implementation TKServerObject

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.attributeValues = [NSDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithUniqueID:(NSString*)uniqueID;
{
    self = [self init];
    if (self) {
        self.uniqueObjectID = uniqueID;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [self init];
    if (self) {
        self.localObjectIDURL = [decoder decodeObjectForKey:kLocalURL];
        self.serverObjectID = [decoder decodeObjectForKey:kServerID];
        self.uniqueObjectID = [decoder decodeObjectForKey:kUniqueID];
        self.entityName = [decoder decodeObjectForKey:kEntityName];
        self.changedAttributes = [decoder decodeObjectForKey:kChangedAttributes];
        self.relatedObjects = [decoder decodeObjectForKey:kRelatedObjects];
        self.attributeValues = [decoder decodeObjectForKey:kAttributes];
        self.creationDate = [decoder decodeObjectForKey:kCreationDate];
        self.lastModificationDate = [decoder decodeObjectForKey:kLastModDate];
        self.isDeleted = [decoder decodeBoolForKey:kIsDeleted];
        self.isOriginal = [decoder decodeBoolForKey:kIsOriginal];
        self.binaryKeysFields = [decoder decodeObjectForKey:kBinaryFields];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.localObjectIDURL forKey:kLocalURL];
    [encoder encodeObject:self.serverObjectID forKey:kServerID];
    [encoder encodeObject:self.uniqueObjectID forKey:kUniqueID];
    [encoder encodeObject:self.entityName forKey:kEntityName];
    [encoder encodeObject:self.changedAttributes forKey:kChangedAttributes];
    [encoder encodeObject:self.relatedObjects forKey:kRelatedObjects];
    [encoder encodeObject:self.attributeValues forKey:kAttributes];
    [encoder encodeObject:self.creationDate forKey:kCreationDate];
    [encoder encodeObject:self.lastModificationDate forKey:kLastModDate];
    [encoder encodeBool:self.isDeleted forKey:kIsDeleted];
    [encoder encodeBool:self.isOriginal forKey:kIsOriginal];
    [encoder encodeObject:self.binaryKeysFields forKey:kBinaryFields];
}

- (BOOL) isEqual:(id)object {
    TKServerObject *otherObject = (TKServerObject*)object;
    if ([self.uniqueObjectID isEqualToString:otherObject.uniqueObjectID]) {
        return YES;
    }
    return NO;
}

- (NSUInteger) hash {
    return [self.uniqueObjectID hash];
}

- (NSString*) description {
    return [NSString stringWithFormat:@"%@,%@,%@\n%@\n%@", self.entityName, self.uniqueObjectID, self.serverObjectID, self.attributeValues, self.binaryKeysFields];
}

@end

@implementation TKServerObjectConflictPair

- (id) initWithServerObject:(TKServerObject*)serverObject localObject:(TKServerObject*)localObject shadowObject:(TKServerObject*)shadowObject {
    self = [super init];
    if (self) {
        self.serverObject = serverObject;
        self.localObject = localObject;
        self.shadowObject = shadowObject;
    }
    return self;
}

@end