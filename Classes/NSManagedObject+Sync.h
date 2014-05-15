//
//  NSManagedObject+Sync.h
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-06.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "RMParseSync.h"

@interface NSManagedObject (Sync)

- (NSString *) tk_localURL;
/**
 *  The object's unique identifier. Assigned locally.
 *
 *  @return String containing the unique object ID.
 */
- (NSString *) tk_uniqueObjectID;

/**
 *  The server identifier of the object. Assigned on the server.
 *
 *  @return String of the Server object identifier.
 */
- (NSString *) tk_serverObjectID;

/**
 *  The object's creation date.
 *
 *  @return creation date.
 */
- (NSDate *) tk_creationDate;

/**
 *  Last modification date.
 *
 *  @return last modification date.
 */
- (NSDate *) tk_lastModificationDate;

/**
 *  Assign a unique ID for the object.
 */
- (NSString*) assignUniqueObjectID;

- (TKServerObject*) toServerObject;

- (TKServerObject*) toServerObjectInContext:(NSManagedObjectContext*)context;

@end