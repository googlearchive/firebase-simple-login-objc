//
//  SenTestCase+FWaiter.h
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/11/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

@interface SenTestCase (FWaiter)

- (NSTimeInterval) waitUntil:(BOOL (^)())predicate;
- (NSTimeInterval) waitUntil:(BOOL (^)())predicate timeout:(NSTimeInterval)seconds;

@end
