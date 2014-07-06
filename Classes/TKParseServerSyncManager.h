//
//  TKParseServerSyncManager.h
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-18.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "TKServerSyncManager.h"

@class TKParseServerSyncManager;

@protocol TKParseSyncDelegate <NSObject>

@optional
- (void)parseSyncManager:(TKParseServerSyncManager *)manager willUploadParseObject:(PFObject *)parseObject withServerObject:(TKServerObject *)serverObject;

@end

@interface TKParseServerSyncManager : TKServerSyncManager

@property (nonatomic, weak) id <TKParseSyncDelegate> delegate;

@end
