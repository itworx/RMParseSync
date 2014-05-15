//
//  NSManagedObjectContext+Sync.m
//  ParseSyncExample
//
//  Created by Ramy Medhat on 2014-04-21.
//  Copyright (c) 2014 Inovaton. All rights reserved.
//

#import "NSManagedObjectContext+Sync.h"

@implementation NSManagedObjectContext (Sync)

- (NSManagedObject *)objectWithURI:(NSURL *)uri
{
    NSManagedObject __block *returnedObject;
    NSManagedObjectContext __weak *weakContext = self;
    [self performBlockAndWait:^{
        NSManagedObjectID *objectID =
        [[weakContext persistentStoreCoordinator]
         managedObjectIDForURIRepresentation:uri];
        
        if (!objectID)
        {
            return;
        }
        
        NSManagedObject *objectForID = [weakContext objectWithID:objectID];
        if (![objectForID isFault])
        {
            returnedObject = objectForID;
        }
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        [request setEntity:[objectID entity]];
        
        // Equivalent to
        // predicate = [NSPredicate predicateWithFormat:@"SELF = %@", objectForID];
        NSPredicate *predicate =
        [NSComparisonPredicate
         predicateWithLeftExpression:
         [NSExpression expressionForEvaluatedObject]
         rightExpression:
         [NSExpression expressionForConstantValue:objectForID]
         modifier:NSDirectPredicateModifier
         type:NSEqualToPredicateOperatorType
         options:0];
        [request setPredicate:predicate];
        
        NSArray *results = [weakContext executeFetchRequest:request error:nil];
        if ([results count] > 0 )
        {
            returnedObject = [results objectAtIndex:0];
        }
        
        return;
    }];
    
    return returnedObject;
}

@end
