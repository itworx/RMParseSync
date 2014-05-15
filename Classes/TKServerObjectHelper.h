//
//  TKServerObjectHelper.h
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-18.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TKServerObject.h"
#import "RMParseSync.h"

@interface TKServerObjectHelper : NSObject

/**
 *  Gets the inserted objects from cache as TKServerObjects.
 *
 *  @return array of TKServerObjects.
 */
+ (NSArray*)getInsertedObjectsFromCache;

/**
 *  Gets the updated objects from cache as TKServerObjects.
 *  This includes both locally updated and deleted objects.
 *
 *  @return array of TKServerObjects.
 */
+ (NSArray*)getUpdatedObjectsFromCache;

/**
 *  Inserts an array of server objects into the local database.
 *
 *  @param serverObjects array of server objects.
 */
+ (void) insertServerObjectsInLocalDatabase:(NSArray*)serverObjects;

/**
 *  Updates the server Object ID in the local database.
 *
 *  @param serverObjects array of server objects.
 */
+ (void) updateServerIDInLocalDatabase:(NSArray*)serverObjects;

/**
 *  Updates an array of server objects into the local database.
 *
 *  @param serverObjects array of server objects.
 */
+ (void) updateServerObjectsInLocalDatabase:(NSArray*)serverObjects;

/**
 *  Resolves a conflict between local and server versions of an
 *  object. Sets the output object in the conflict pair and the
 *  resolution type.
 *
 *  @param conflictPair The conflict pair.
 */
+ (void) resolveConflict:(TKServerObjectConflictPair*)conflictPair localUpdates:(NSArray*)localUpdates serverUpdates:(NSArray*)serverUpdates;

@end
