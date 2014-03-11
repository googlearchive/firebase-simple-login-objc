//
//  FAUser_Private.h
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/18/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import <FirebaseSimpleLogin/FirebaseSimpleLogin.h>

@interface FAUser ()

+ (FAUser *) userWithId:(NSString *)userId uid:(NSString *)uid token:(NSString *)token andEmail:(NSString *)email;
+ (FAUser *) userWithId:(NSString *)userId uid:(NSString *)uid token:(NSString *)token provider:(FAProvider)provider userData:(NSDictionary *)data;

@end
