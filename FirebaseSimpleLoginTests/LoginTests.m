//
//  EmailTests.m
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/10/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "LoginTests.h"
#import "FTestHelpers.h"
#import "FTestConstants.h"
#import "FirebaseSimpleLogin.h"
#import "FirebaseSimpleLogin_Private.h"
#import "SenTestCase+FWaiter.h"

#define WAIT_FOR(x) [self waitUntil:^{ return (BOOL)(x); }]

@implementation LoginTests

- (void) setUp {
    Firebase* ref = [FTestHelpers getRandomNode];
    FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:ref andApiHost:@"http://fblocal.com:12000"];
    [authClient logout];
}

- (void) testVersionConstant {
    NSString* version = [FirebaseSimpleLogin sdkVersion];
    NSArray* parts = [version componentsSeparatedByString:@"_"];
    STAssertTrue(parts.count == 3, @"Version should have three components");
    NSArray* semverParts = [[parts objectAtIndex:0] componentsSeparatedByString:@"."];
    STAssertTrue(semverParts.count == 3, @"semver should have three parts");
}

- (void) testInvalidEmail {
    Firebase* ref = [FTestHelpers getRandomNode];
    FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:ref andApiHost:@"http://fblocal.com:12000"];
    __block BOOL done = NO;
    [authClient loginWithEmail:@"bad_email" andPassword:@"doesntmatter" withCompletionBlock:^(NSError *error, FAUser *user) {
        STAssertTrue(error != nil, @"We should get an error back?");
        STAssertTrue(user == nil, @"We absolutely should not get a user");
        done = YES;
    }];

    WAIT_FOR(done);
}

- (void) testCreateEmailAccountAndLogin {
    Firebase* ref = [FTestHelpers getRandomNode];
    STAssertTrue([FTestHelpers setDefaultAuthConfigForRef:ref], @"Should upload config");

    __block NSError* theError = nil;
    __block id theUser = nil;
    __block BOOL done = NO;
    FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:ref options:@{ @"debug": @YES } andApiHost:@"http://fblocal.com:12000"];

    // delete the users we're going to be creating, so we don't get duplicate email warnings
    [authClient removeUserWithEmail:@"person@firebase.com" password:@"newpw" andCompletionBlock:^(NSError *error, BOOL success) {
        //NSLog(@"error: %@", error);
        STAssertTrue(error == nil || error.code == FAErrorUserDoesNotExist, @"Should not be an error, or should have already been deleted");
        done = YES;
    }];

    WAIT_FOR(done);

    done = NO;
    [authClient removeUserWithEmail:@"person2@firebase.com" password:@"correcthorsebatterystaple" andCompletionBlock:^(NSError *error, BOOL success) {
        done = YES;
    }];

    WAIT_FOR(done);

    done = NO;
    [authClient removeUserWithEmail:@"person@firebase.com" password:@"pw" andCompletionBlock:^(NSError *error, BOOL success) {
        STAssertTrue(error == nil || error.code == FAErrorUserDoesNotExist, @"Should not be an error, or should have already been deleted");
        done = YES;
    }];

    WAIT_FOR(done);

    done = NO;
    [authClient checkAuthStatusWithBlock:^(NSError *error, FAUser* user) {
        theError = error;
        theUser = user;
        done = YES;
    }];
    STAssertFalse(done, @"Verify that this is actually async, even though it's all local");

    WAIT_FOR(done);

    [authClient logout];

    done = NO;
    [authClient createUserWithEmail:@"person@firebase.com" password:@"pw" andCompletionBlock:^(NSError *error, FAUser* user) {
        STAssertTrue(error == nil, @"Should not be an error");
        STAssertTrue([user.uid isEqualToString:[@"simplelogin:" stringByAppendingString:user.userId]], @"Should get the properly formatted uid");
        STAssertTrue([user.email isEqualToString:@"person@firebase.com"], @"Should get the email we set");
        done = YES;
    }];

    WAIT_FOR(done);

    // Should still be logged out
    done = NO;
    [authClient checkAuthStatusWithBlock:^(NSError *error, FAUser* user) {
        STAssertNil(error, @"Should not be an error, we're just logged out");
        STAssertNil(user, @"No user set, we're logged out");
        done = YES;
    }];
    STAssertFalse(done, @"Verify that this is actually async, even though it's all local");

    WAIT_FOR(done);

    // Ok, now time to login

    // first try a bogus password
    done = NO;
    [authClient loginWithEmail:@"person@firebase.com" andPassword:@"wrong" withCompletionBlock:^(NSError* error, FAUser* user){
        done = YES;
        STAssertTrue(error != nil, @"We should not have logged in");
        STAssertTrue(error.code == FAErrorInvalidPassword, @"Error should be incorrect password");
        STAssertTrue(user == nil, @"We should not get a user object");
    }];

    WAIT_FOR(done);

    // now try the correct password
    done = NO;
    [authClient loginWithEmail:@"person@firebase.com" andPassword:@"pw" withCompletionBlock:^(NSError* error, FAUser* user){
        done = YES;
        STAssertNil(error, @"Should not error out");
        STAssertTrue(user.authToken != nil, @"Got an auth token");
    }];

    WAIT_FOR(done);

    done = NO;
    [authClient checkAuthStatusWithBlock:^(NSError *error, FAUser* user) {
        STAssertTrue(error == nil, @"We should still be logged in");
        STAssertTrue(user != nil, @"Should have a user");
        STAssertTrue(user.authToken != nil, @"The user should have an auth token");
        done = YES;
    }];

    WAIT_FOR(done);

    [authClient logout];

    done = NO;
    [authClient checkAuthStatusWithBlock:^(NSError *error, FAUser* user) {
        STAssertNil(error, @"Should not be an error, we're just logged out");
        STAssertNil(user, @"No user set, we're logged out");
        done = YES;
    }];
    STAssertFalse(done, @"Verify that this is actually async, even though it's all local");

    WAIT_FOR(done);

    done = NO;
    [authClient changePasswordForEmail:@"person@firebase.com" oldPassword:@"wrongPw" newPassword:@"newpw" completionBlock:^(NSError *error, BOOL success) {
        STAssertTrue(!success, @"Changing password with incorrect password");
        STAssertTrue(error != nil, @"Changing password with incorrect password should be an error");
        done = YES;
    }];
  
    WAIT_FOR(done);

    done = NO;
    [authClient changePasswordForEmail:@"person@firebase.com" oldPassword:@"pw" newPassword:@"newpw" completionBlock:^(NSError *error, BOOL success) {
        STAssertTrue(success, @"Changing password with correct password");
        STAssertTrue(error == nil, @"Changing password with incorrect password should be an error");
        done = YES;
    }];

    WAIT_FOR(done);

    done = NO;
    [authClient loginWithEmail:@"person@firebase.com" andPassword:@"newpw" withCompletionBlock:^(NSError* error, FAUser* user){
        done = YES;
        STAssertNil(error, @"Should not error out");
        STAssertTrue(user.authToken != nil, @"Got an auth token");
    }];

    WAIT_FOR(done);

    // Login with a new user, make sure we get the new user and not the old one
    done = NO;
    // First, create the new user
    [authClient createUserWithEmail:@"person2@firebase.com" password:@"correcthorsebatterystaple" andCompletionBlock:^(NSError *error, FAUser* user) {
        STAssertTrue(error == nil, @"Should not be an error");
        STAssertTrue([user.email isEqualToString:@"person2@firebase.com"], @"Should get the email we set");
        done = YES;
    }];

    WAIT_FOR(done);

    // Make sure we're still logged in as the old user
    done = NO;
    [authClient checkAuthStatusWithBlock:^(NSError *error, FAUser* user) {
        STAssertNil(error, @"Should not be an error, we're just logged out");
        STAssertTrue([user.email isEqualToString:@"person@firebase.com"], @"No user set, we're logged out");
        done = YES;
    }];

    WAIT_FOR(done);

    done = NO;
    [authClient loginWithEmail:@"person2@firebase.com" andPassword:@"correcthorsebatterystaple" withCompletionBlock:^(NSError* error, FAUser* user){
        done = YES;
        STAssertNil(error, @"Should not error out");
        STAssertTrue(user.authToken != nil, @"Got an auth token");
        STAssertTrue([user.email isEqualToString:@"person2@firebase.com"], @"Got the new user");
    }];

    WAIT_FOR(done);

    // finally, make sure we have the correct user saved
    done = NO;
    [authClient checkAuthStatusWithBlock:^(NSError *error, FAUser* user) {
        STAssertNil(error, @"Should not be an error, we're just logged out");
        STAssertTrue([user.email isEqualToString:@"person2@firebase.com"], @"Got the new user");
        STAssertNil(user.thirdPartyUserAccount, @"No ACAccount associated with email users");
        done = YES;
    }];

    WAIT_FOR(done);
}

- (void) testFacebookAuth {
    Firebase* ref = [FTestHelpers getRandomNode];
    STAssertTrue([FTestHelpers setDefaultAuthConfigForRef:ref], @"Should upload config");

    FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:ref andApiHost:@"http://fblocal.com:12000"];
    [authClient logout];

    __block BOOL done = NO;
    [authClient loginToFacebookAppWithId:kFirebaseTestFacebookAppId permissions:nil audience:ACFacebookAudienceOnlyMe withCompletionBlock:^(NSError *error, FAUser *user) {
        STAssertTrue(error == nil, @"Should not error out");
        STAssertTrue(user != nil, @"Should get a valid user");
        //STAssertTrue(user.thirdPartyUserAccount != nil, @"Should have a third party account here");
        done = YES;
    }];

    WAIT_FOR(done);

    // Upgrade permissions
    done = NO;
    [authClient loginToFacebookAppWithId:kFirebaseTestFacebookAppId permissions:@[@"create_event"] audience:ACFacebookAudienceFriends withCompletionBlock:^(NSError *error, FAUser *user) {

        STAssertNil(error, @"Should not error out");
        STAssertNotNil(user, @"Should get a user");
        done = YES;
    }];

    WAIT_FOR(done);

    done = NO;
    [authClient checkAuthStatusWithBlock:^(NSError *error, FAUser* user) {
        STAssertNil(error, @"Should not be an error");
        STAssertTrue(user != nil, @"We should not be logged out");
        //STAssertTrue(user.thirdPartyUserAccount != nil, @"Should have a third party account here");
        done = YES;
    }];

    WAIT_FOR(done);


    // Check multiple simultaneous auth clients
    __block int count = 0;
    FirebaseSimpleLogin* authClient2 = [[FirebaseSimpleLogin alloc] initWithRef:ref andApiHost:@"http://fblocal.com:12000"];
    [authClient checkAuthStatusWithBlock:^(NSError *error, FAUser *user) {
        STAssertTrue(user != nil, @"should have a user");
        count++;
    }];

    [authClient2 checkAuthStatusWithBlock:^(NSError *error, FAUser *user) {
        STAssertTrue(user != nil, @"Should have a user");
        count++;
    }];

    WAIT_FOR(count == 2);


    [ref unauth];

    done = NO;
    [[ref.root childByAppendingPath:@".info/authenticated"] observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        NSNumber* val = [snapshot value];
        done = ![val boolValue];
    }];

    WAIT_FOR(done);

    done = NO;
    [authClient checkAuthStatusWithBlock:^(NSError *error, FAUser* user) {
        STAssertNil(error, @"Should not be an error, we're just logged out");
        STAssertNil(user, @"No user set, we're logged out");
        done = YES;
    }];

    WAIT_FOR(done);
}

- (void) testTwitterAuth {
    Firebase* ref = [FTestHelpers getRandomNode];
    STAssertTrue([FTestHelpers setDefaultAuthConfigForRef:ref], @"Should upload config");

    FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:ref andApiHost:@"http://fblocal.com:12000"];
    [authClient logout];

    __block BOOL done = NO;
    [authClient loginToTwitterAppWithId:kFirebaseTestTwitterAppId multipleAccountsHandler:^int(NSArray *usernames) {
        STFail(@"Not yet supported");
        return 0;
    } withCompletionBlock:^(NSError *error, FAUser *user) {
        STAssertTrue(error == nil, @"Error should be nil");
        STAssertTrue(user != nil, @"Should get a user");
        STAssertTrue([user.uid isEqualToString:[@"twitter:" stringByAppendingString:user.userId]], @"Should get the properly formatted uid");
        STAssertTrue(user.thirdPartyUserAccount != nil, @"Should have a third party account here");
        done = YES;
    }];

    WAIT_FOR(done);

    done = NO;
    [authClient checkAuthStatusWithBlock:^(NSError *error, FAUser* user) {
        STAssertNil(error, @"Should not be an error");
        STAssertTrue(user != nil, @"We should not be logged out");
        STAssertTrue(user.thirdPartyUserAccount != nil, @"Should have a third party account here");
        done = YES;
    }];

    WAIT_FOR(done);
}

- (void) testAnonymousAuth {
    Firebase* ref = [FTestHelpers getRandomNode];
    STAssertTrue([FTestHelpers setDefaultAuthConfigForRef:ref], @"Should upload config");

    FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:ref andApiHost:@"http://fblocal.com:12000"];
    [authClient logout];

    __block BOOL done = NO;
    [authClient loginAnonymouslywithCompletionBlock:^(NSError *error, FAUser *user) {
    NSLog(@"%@", error.debugDescription);
        NSLog(@"%@", user);
        STAssertNil(error, @"Should not be an error");
        STAssertTrue(user != nil, @"We should not be logged out");
        done = YES;
    }];

    WAIT_FOR(done);
}

@end
