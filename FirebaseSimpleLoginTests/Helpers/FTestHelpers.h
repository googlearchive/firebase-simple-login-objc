//
//  FTestHelpers.h
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/10/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Firebase/Firebase.h>

@interface FTestHelpers : NSObject

+ (Firebase *) getRandomNode;
+ (BOOL) setDefaultAuthConfigForRef:(Firebase *)ref;
+ (BOOL) setAuthConfig:(NSDictionary *)config forRef:(Firebase *)ref;

@end
