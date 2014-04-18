//
//  FAUser.m
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/11/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "FAUser.h"

@implementation FAUser

@synthesize userId;
@synthesize uid;
@synthesize provider;
@synthesize email;
@synthesize isTemporaryPassword;
@synthesize thirdPartyUserAccount;
@synthesize thirdPartyUserData;

+ (FAUser *) userWithId:(NSString *)userId uid:(NSString *)uid token:(NSString *)token isTemporaryPassword:(BOOL)isTemporaryPassword andEmail:(NSString *)email {
    FAUser* user = [[FAUser alloc] init];
    user.provider = FAProviderPassword;
    user.userId = userId;
    user.uid = uid;
    user.authToken = token;
    user.email = email;
    user.isTemporaryPassword = isTemporaryPassword;
    return user;
}

+ (FAUser *) userWithId:(NSString *)userId uid:(NSString *)uid token:(NSString *)token provider:(FAProvider)provider userData:(NSDictionary *)data {
    FAUser* user = [[FAUser alloc] init];
    user.provider = provider;
    user.userId = userId;
    user.uid = uid;
    user.authToken = token;
    user.thirdPartyUserData = data;
    return user;
}

- (NSString *) description {
    return [NSString stringWithFormat:@"User %@ (%i)", self.userId, self.provider];
}

@end
