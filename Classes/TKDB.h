//
//  TKDB.h
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-19.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMParseSync.h"

#define kTKDBUniqueIDField          @"tkID"
#define kTKDBServerIDField          @"serverObjectID"
#define kTKDBIsDeletedField         @"isDeleted"
#define kTKDBCreatedDateField       @"createdDate"
#define kTKDBUpdatedDateField       @"lastModifiedDate"

#define kTKDBBinaryFieldKeySuffix   @"_BinaryPathKey" // this should be the path of the file

#define kLastSyncDate @"LastSync"
#define kEntities @[@"Classroom", @"Student", @"Behavior", @"Behaviortype"]

NSString * const TKDBSyncDidSucceedNotification;
NSString * const TKDBSyncFailedNotification;

typedef void (^TKSyncSuccessBlock)(NSArray *objects);
typedef void (^TKSyncFailureBlock)(NSArray *objects, NSError *error);

@class BFTask;
@protocol TKParseSyncDelegate;

// Set the flag for a block completion handler
#define StartBlock() __block BOOL waitingForBlock = YES

// Set the flag to stop the loop
#define EndBlock() waitingForBlock = NO

// Wait and loop until flag is set
#define WaitUntilBlockCompletes() WaitWhile(waitingForBlock)

// Macro - Wait for condition to be NO/false in blocks and asynchronous calls
#define WaitWhile(condition) \
do { \
while(condition) { \
[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]]; \
} \
} while(0)

@interface TKDB : NSObject

@property (nonatomic, weak) id <TKParseSyncDelegate> syncManagerDelegate;

/**
 *  Root saving context.
 */
@property (nonatomic, strong) NSManagedObjectContext *rootContext;

/**
 *  Reference context for getting the old values of changed objects.
 */
@property (nonatomic, strong, readonly) NSManagedObjectContext *referenceContext;

/**
 *  Context used for syncing. Is a child of the root context.
 */
@property (nonatomic, strong, readonly) NSManagedObjectContext *syncContext;

/**
 *  Context used for syncing. Is a child of the root context.
 */
@property (nonatomic, strong) NSArray *entities;

+ (TKDB*) defaultDB;


- (void) setRootContext:(NSManagedObjectContext*)rootContext;

- (NSDate*) lastSyncDate;
- (void) setLastSyncDate:(NSDate*)date;

- (BFTask *)sync;

- (BFTask *)checkServerForExistingObjectsForEntity:(NSString *)entityName;

@end
