//
//  SenTestCase+FWaiter.m
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/11/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "SenTestCase+FWaiter.h"
#import "FTestConstants.h"

@implementation SenTestCase (FWaiter)

- (NSTimeInterval) waitUntil:(BOOL (^)())predicate {
    return [self waitUntil:predicate timeout:kFirebaseTestWaitUntilTimeout];
}

- (NSTimeInterval) waitUntil:(BOOL (^)())predicate timeout:(NSTimeInterval)seconds {
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:seconds];
    NSTimeInterval timeoutTime = [timeoutDate timeIntervalSinceReferenceDate];
    NSTimeInterval currentTime;

    for (currentTime = [NSDate timeIntervalSinceReferenceDate];
         !predicate() && currentTime < timeoutTime;
         currentTime = [NSDate timeIntervalSinceReferenceDate]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
    }

    NSTimeInterval finish = [NSDate timeIntervalSinceReferenceDate];
    STAssertTrue(currentTime <= timeoutTime, @"Timed out");
    return (finish - start);
}

@end
