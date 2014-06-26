//
//  TKSyncLogger.h
//  ParseSync
//
//  Created by Ahmed AlMoraly on 6/25/14.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import <Foundation/Foundation.h>
#ifdef COCOAPODS
#import <DDFileLogger.h>
#else
#import "DDFileLogger.h"
#endif

#define SYNC_LOG_CONTEXT 80

#define SYNCLogError(frmt, ...)     SYNC_LOG_OBJC_MAYBE(syncLogLevel, LOG_FLAG_ERROR,   SYNC_LOG_CONTEXT, frmt, ##__VA_ARGS__)
#define SYNCLogWarn(frmt, ...)     ASYNC_LOG_OBJC_MAYBE(syncLogLevel, LOG_FLAG_WARN,    SYNC_LOG_CONTEXT, frmt, ##__VA_ARGS__)
#define SYNCLogInfo(frmt, ...)     ASYNC_LOG_OBJC_MAYBE(syncLogLevel, LOG_FLAG_INFO,    SYNC_LOG_CONTEXT, frmt, ##__VA_ARGS__)
#define SYNCLogDebug(frmt, ...)     ASYNC_LOG_OBJC_MAYBE(syncLogLevel, LOG_FLAG_DEBUG,  SYNC_LOG_CONTEXT, frmt, ##__VA_ARGS__)
#define SYNCLogVerbose(frmt, ...)  ASYNC_LOG_OBJC_MAYBE(syncLogLevel, LOG_FLAG_VERBOSE, SYNC_LOG_CONTEXT, frmt, ##__VA_ARGS__)

@interface TKSyncLogger : NSObject

+ (void)initializeDefaults;

+ (void)startLogging;

+ (void)endLogging;

@end
