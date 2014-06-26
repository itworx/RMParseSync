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

@interface TKSyncLogger : NSObject

+ (void)initializeDefaults;

+ (void)startLogging;

+ (void)endLogging;

@end
