//
//  TKServerSyncManager.h
//  This class provides base functionality for sync services
//  provided by a server.
//
//  Created by Ramy Medhat on 2014-04-18.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMParseSync.h"

@class BFTask;

@interface TKServerSyncManager : NSObject


/**
 *  Uploads an array of inserted TKServerObjects to the server. Is responsible for converting
 *  these objects to the server type of objects whatever the server is.
 *
 *  @param serverObjects array of TKServerObjects.
 *  @param successBlock  the block to call on successful upload. On success, should return array of updated server objects.
 *  @param failureBlock  the block to call on failed upload.
 */
- (void) uploadInsertedObjects:(NSArray*)serverObjects withSuccessBlock:(TKSyncSuccessBlock)successBlock andFailureBlock:(TKSyncFailureBlock)failureBlock;
- (BFTask *)uploadInsertedObjectsAsync:(NSArray *)serverObjects;
/**
 *  Downloads the updated objects on the server. Includes newly inserted,
 *  updated, or deleted objects. Is responsible for converting these objects
 *  to TKServerObjects and passing them to the block.
 *
 *  @param entityName   The name of the entity to check for updated objects.
 *  @param successBlock  the block to call on successful upload.
 *  @param failureBlock  the block to call on failed upload.
 */
- (void) downloadUpdatedObjectsForEntity:(NSString*)entityName withSuccessBlock:(TKSyncSuccessBlock)successBlock andFailureBlock:(TKSyncFailureBlock)failureBlock;
- (BFTask *)downloadUpdatedObjectsAsyncForEntity:(NSString *)entityName;

/**
 *  Upload an array of TKServerObjects to the server. It is different from the insertedObjects
 *  methods above because these objects already have server IDs, which will differ in handling.
 *  The aray can includes both updated and deleted objects. This function is responsible for
 *  converting these objects to the server type of objects whatever the server is.
 *
 *  @param serverObjects array of TKServerObjects.
 *  @param successBlock  the block to call on successful upload.
 *  @param failureBlock  the block to call on failed upload.
 */
- (void) uploadUpdatedObjects:(NSArray*)serverObjects WithSuccessBlock:(TKSyncSuccessBlock)successBlock andFailureBlock:(TKSyncFailureBlock)failureBlock;
- (BFTask *)uploadUpdatedObjectsAsync:(NSArray *)serverObjects;

- (NSArray*) toManyRelationshipKeysForEntity:(NSString*)name;
@end
