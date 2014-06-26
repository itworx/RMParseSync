//
//  TKSyncLogger.m
//  ParseSync
//
//  Created by Ahmed AlMoraly on 6/25/14.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "TKSyncLogger.h"

@interface TKFileLoggerManager : DDLogFileManagerDefault

@end

@implementation TKFileLoggerManager

+ (NSDateFormatter *)formatter {
    static NSDateFormatter *_formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
         _formatter = [[NSDateFormatter alloc] init];
        _formatter.dateStyle = NSDateFormatterMediumStyle;
        _formatter.timeStyle = NSDateFormatterMediumStyle;
    });
    return _formatter;
}


- (NSString *)logsDirectory {
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *baseDir = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"Logs"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:logsDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return logsDirectory;
}

- (NSString *)newLogFileName {
    NSString *name = [super newLogFileName];
    
    NSString *appName = [[name componentsSeparatedByString:@" "] firstObject];
    
    NSDateFormatter *dateFormatter = [TKFileLoggerManager formatter];
    NSString *formattedDate = [dateFormatter stringFromDate:[NSDate date]];
    
    return [NSString stringWithFormat:@"%@ %@.log", appName, formattedDate];
}

@end

@interface TKSyncLogger ()

+ (TKSyncLogger *)defaultLogger;

@property (nonatomic, strong) DDFileLogger *fileLogger;

@end

@implementation TKSyncLogger

+ (TKSyncLogger *)defaultLogger {
    static TKSyncLogger *_logger;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _logger = [[TKSyncLogger alloc] init];
    });
    return _logger;
}

+ (void)initializeDefaults {
    [self defaultLogger];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        TKFileLoggerManager *manager = [[TKFileLoggerManager alloc] init];
        manager.maximumNumberOfLogFiles = 0;
        
        self.fileLogger = [[DDFileLogger alloc] initWithLogFileManager:manager];
        self.fileLogger.rollingFrequency = 0;

        [DDLog addLogger:self.fileLogger];
    }
    return self;
}

+ (void)startLogging {
    [[TKSyncLogger defaultLogger].fileLogger rollLogFileWithCompletionBlock:nil];
}

+ (void)endLogging {
    [[TKSyncLogger defaultLogger].fileLogger rollLogFileWithCompletionBlock:nil];
}

@end
