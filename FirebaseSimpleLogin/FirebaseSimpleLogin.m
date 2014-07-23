//
//  FirebaseSimpleLogin.m
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/10/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import <FacebookSDK/FacebookSDK.h>
#import "FirebaseSimpleLogin.h"
#import "FirebaseSimpleLogin_Private.h"
#import "FAValidation.h"
#import "NSString+FAURLUtils.h"
#import "FATypedefs.h"
#import "FATypes.h"
#import "FAUser_Private.h"
#import "FAGitHash.h"
#import "FAUtilities.h"

@interface FATupleCallbackData : NSObject

@property (nonatomic, copy) fabt_void_nserror_json callback;
@property (strong, nonatomic) NSMutableData* data;

@end

@implementation FATupleCallbackData

@synthesize callback;
@synthesize data;

@end

@interface FirebaseSimpleLogin () <NSURLConnectionDelegate>

@property (strong, nonatomic) Firebase* ref;
@property (strong, nonatomic) NSString* namespace;
@property (strong, nonatomic) NSString* apiHost;
@property (nonatomic) CFMutableDictionaryRef outstandingRequests;
@property (strong, nonatomic) ACAccountStore* store;
@property (strong, nonatomic) NSDictionary* options;
@property (nonatomic) BOOL hasFacebookSDK;

@end

@implementation FirebaseSimpleLogin

// Global Consts
static NSString *const FIREBASE_AUTH_ERROR_DOMAIN = @"FirebaseSimpleLogin";
static NSString *const FIREBASE_AUTH_DEFAULT_API_HOST = @"https://auth.firebase.com";
static NSString *const FIREBASE_AUTH_PATH_SEMVER = @"XXX_TAG_VERSION_XXX";

// Email / Password Provider
static NSString *const FIREBASE_AUTH_PATH_PASSWORD = @"/auth/firebase";
static NSString *const FIREBASE_AUTH_PATH_PASSWORD_CREATEUSER = @"/auth/firebase/create";
static NSString *const FIREBASE_AUTH_PATH_PASSWORD_REMOVEUSER = @"/auth/firebase/remove";
static NSString *const FIREBASE_AUTH_PATH_PASSWORD_CHANGEPASSWORD = @"/auth/firebase/update";
static NSString *const FIREBASE_AUTH_PATH_PASSWORD_RESETPASSWORD = @"/auth/firebase/reset_password";

// OAuth Token Providers
static NSString *const FIREBASE_AUTH_PATH_ANONYMOUS = @"/auth/anonymous";
static NSString *const FIREBASE_AUTH_PATH_FACEBOOKTOKEN = @"/auth/facebook/token";
static NSString *const FIREBASE_AUTH_PATH_GOOGLETOKEN = @"/auth/google/token";
static NSString *const FIREBASE_AUTH_PATH_TWITTERREVERSE = @"/auth/twitter/reverse";
static NSString *const FIREBASE_AUTH_PATH_TWITTERTOKEN = @"/auth/twitter/token";

@synthesize ref;
@synthesize namespace;
@synthesize apiHost;
@synthesize store;
@synthesize options;

+ (NSString *) sdkVersion {
    return [NSString stringWithFormat:@"%@_%@_%@", FIREBASE_AUTH_PATH_SEMVER, kFirebaseSimpleLoginBuildDate, kFirebaseSimpleLoginGitHash];
}

+ (void) setLoggingEnabled:(BOOL)enabled {
    [FAUtilities setLoggingEnabled:enabled];
}

+ (NSString *) namespaceWithUrl:(NSString *)url {
    NSRange colonIndex = [url rangeOfString:@"//"];
    if (colonIndex.length != NSNotFound) {
        url = [url substringFromIndex:colonIndex.location + 2];
    }

    NSRange dotIndex = [url rangeOfString:@"."];
    NSString* namespace = nil;
    if (dotIndex.location != NSNotFound) {
        namespace = [url substringToIndex:dotIndex.location];
    }

    if (namespace == nil || namespace.length == 0) {
        @throw [[NSException alloc] initWithName:@"InvalidFirebase" reason:@"\"ref\" argument must be a valid Firebase reference" userInfo:nil];
    }
    return namespace;
}

+ (NSError *) errorFromResponse:(NSDictionary *)response {
    FAError errorCode = 0;
    NSString* codeString = [[response objectForKey:@"code"] description];
    if (!codeString) {
        errorCode = FAErrorUnknown;
    } else if ([codeString isEqualToString:@"190"]) {
        errorCode = FAErrorBadSystemToken;
    } else if ([codeString isEqualToString:@"INVALID_USER"]) {
        errorCode = FAErrorUserDoesNotExist;
    } else if ([codeString isEqualToString:@"INVALID_PASSWORD"]) {
        errorCode = FAErrorInvalidPassword;
    } else if ([codeString isEqualToString:@"NO_ACCESS"]) {
        errorCode = FAErrorAccessNotGranted;
    } else if ([codeString isEqualToString:@"NO_ACCOUNT"]) {
        errorCode = FAErrorAccountNotFound;
    } else if ([codeString isEqualToString:@"AUTHENTICATION_DISABLED"]) {
        errorCode = FAErrorAuthenticationProviderNotEnabled;
    } else if ([codeString isEqualToString:@"INVALID_EMAIL"]) {
        errorCode = FAErrorInvalidEmail;
    } else {
        errorCode = FAErrorUnknown;
    }

    NSString* desc;
    NSString* errorMessage = [response objectForKey:@"message"];
    if (errorMessage) {
        desc = errorMessage;
    } else {
        desc = @"Unknown error";
    }
    return [[NSError alloc] initWithDomain:FIREBASE_AUTH_ERROR_DOMAIN code:errorCode userInfo:@{NSLocalizedDescriptionKey: desc}];
}

+ (FAProvider) providerForString:(NSString *)str {
    if ([str isEqualToString:@"password"]) {
        return FAProviderPassword;
    } else if ([str isEqualToString:@"facebook"]) {
        return FAProviderFacebook;
    } else if ([str isEqualToString:@"twitter"]) {
        return FAProviderTwitter;
    }
    return FAProviderInvalid;
}

+ (NSSet *) facebookPublishPermissions {
    return [NSSet setWithArray:@[@"ads_management", @"create_event", @"rsvp_event", @"manage_friendlists", @"manage_notifications", @"manage_pages", @"publish_actions"]];
}

+ (BOOL) containsPublishActions:(NSArray *)permissions {
    NSSet* requested = [NSSet setWithArray:permissions];
    return [requested intersectsSet:[self facebookPublishPermissions]];
}

+ (int) translateFacebookAudience:(NSString *)audience {
    if ([audience isEqualToString:ACFacebookAudienceOnlyMe]) {
        return FBSessionDefaultAudienceOnlyMe;
    } else if ([audience isEqualToString:ACFacebookAudienceFriends]) {
        return FBSessionDefaultAudienceFriends;
    } else if ([audience isEqualToString:ACFacebookAudienceEveryone]) {
        return FBSessionDefaultAudienceEveryone;
    } else {
        return FBSessionDefaultAudienceNone;
    }
}

- (id) initWithRef:(Firebase *)aRef {
    return [self initWithRef:aRef andApiHost:FIREBASE_AUTH_DEFAULT_API_HOST];
}

- (id) initWithRef:(Firebase *)aRef andApiHost:(NSString *)host {
    NSDictionary* opts = @{};
    return [self initWithRef:aRef options:opts andApiHost:host];
}

- (id) initWithRef:(Firebase *)aRef andOptions:(NSDictionary *)opts {
    return [self initWithRef:aRef options:opts andApiHost:FIREBASE_AUTH_DEFAULT_API_HOST];
}

- (id) initWithRef:(Firebase *)aRef options:(NSDictionary *)opts andApiHost:(NSString *)host {
    self = [super init];
    if (self) {
        self.hasFacebookSDK = NSClassFromString(@"FBSession") != nil;

        self.ref = aRef;
        self.namespace = [FirebaseSimpleLogin namespaceWithUrl:[ref description]];
        self.apiHost = host;
        self.store = [[ACAccountStore alloc] init];
        self.options = opts;
        self.outstandingRequests = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    }
    return self;
}

#pragma mark -
#pragma mark Generic Auth methods

- (void) logout {
    [self.ref unauth];
    [self clearCredentials];
}

- (void) checkAuthStatusWithBlock:(fabt_void_nserror_user)block {

    fabt_void_nserror_user userCallback = [block copy];
    // Check keychain for existing identity
    NSMutableDictionary* query = [self keyQueryDict];

    // match policy

    // return policy
    [query setObject:(id)kCFBooleanTrue forKey:(__bridge NSString *)kSecReturnData];
    [query setObject:(id)kCFBooleanTrue forKey:(__bridge NSString *)kSecReturnAttributes];

    CFDictionaryRef resultsRef = NULL;
    CFDictionaryRef queryRef = (__bridge_retained CFDictionaryRef)query;
    OSStatus status = SecItemCopyMatching(queryRef, (CFTypeRef *)&resultsRef);
    CFRelease(queryRef);
    NSDictionary* results = (__bridge_transfer NSDictionary *)resultsRef;
    NSError* theError = nil;
    if (status != noErr) {
        if (status != errSecItemNotFound) {
            FALog(@"(checkAuthStatusWithBlock:) Error checking authentication status with keychain %d", status);
            theError = [FirebaseSimpleLogin errorFromResponse:@{}];
        }
    }

    if (results != nil) {
        [self attemptAuthWithData:results andCallback:userCallback];
    } else {
        // force async to be consistent
        [self performAsync:^{
            userCallback(theError, nil);
        }];
    }
}

- (void) performAsync:(fabt_void_void)cb {
    [self performSelector:@selector(executeCallback:) withObject:[cb copy] afterDelay:0];
}

- (void) attemptAuthWithData:(NSDictionary *)data andCallback:(fabt_void_nserror_user)callback {
    NSData* keyData = [data objectForKey:(__bridge NSString *)kSecValueData];
    NSDictionary* keyDict = [NSJSONSerialization JSONObjectWithData:keyData options:kNilOptions error:nil];
    NSString* token = [keyDict objectForKey:@"token"];
    NSDictionary* userData = [keyDict objectForKey:@"userData"];
    FAProvider provider = [FirebaseSimpleLogin providerForString:[userData objectForKey:@"provider"]];
    if (provider == FAProviderInvalid) {
        // Whatever user data we have is not valid. Clear it out and report no logged in user
        [self clearCredentials];
        callback(nil, nil);
    }
    [self sendAccountForProvider:provider andUserData:userData toBlock:^(ACAccount *account) {
        [self attemptAuthWithToken:token provider:provider userData:userData account:account andCallback:callback];
    } multipleAccountHandler:^int(NSArray *usernames) {
        NSString* username = [userData objectForKey:@"username"];
        for (int i = 0; i < usernames.count; ++i) {
            NSString* current = [usernames objectAtIndex:i];
            if ([username isEqualToString:current]) {
                return i;
            }
        }
        return NSNotFound;
    }];
}

#pragma mark -
#pragma mark External Facebook methods

- (void) facebookSessionStateChanged:(id)session state:(FBSessionState)state error:(NSError *)error userCallback:(fabt_void_nserror_user)userCallback {
    switch (state) {
        case FBSessionStateOpen: {
            NSString* accessToken = [[session accessTokenData] accessToken];
            NSString* appId = [session appID];
            [self createFacebookUserWithToken:accessToken appId:appId withCompletionBlock:^(NSError *error, FAUser *user) {
                [self performAsync:^{
                    userCallback(error, user);
                }];
            }];
            break;
        }
        case FBSessionStateClosedLoginFailed: {
            // TODO: need to report an error here, they never logged in
            NSError* userError = [FirebaseSimpleLogin errorFromResponse:@{@"error": @"NO_ACCESS", @"message": @"User did not authorize the app"}];
            userCallback(userError, nil);
            break;
        }
        case FBSessionStateClosed:
            // Nothing to do here, they must have previously been logged in. Still logged in to Firebase
        default: {
            [session closeAndClearTokenInformation];
            break;
        }
    }
}

- (void) loginToFacebookAppWithId:(NSString *)appId permissions:(NSArray *)permissions audience:(NSString *)audience withCompletionBlock:(fabt_void_nserror_user)block {
    if (permissions == nil || permissions.count == 0) {
        permissions = @[@"email"];
    }
    if (audience == nil || [audience isEqualToString:@""]) {
        audience = ACFacebookAudienceOnlyMe;
    }

    fabt_void_nserror_user userCallback = [block copy];

    if (self.hasFacebookSDK) {
        NSBundle* bundle = [NSBundle bundleForClass:[self class]];
        NSDictionary* infoDict = [bundle infoDictionary];
        id facebookAppId = [infoDict objectForKey:@"FacebookAppID"];
        id facebookAppName = [infoDict objectForKey:@"FacebookDisplayName"];
        if (![facebookAppId isKindOfClass:[NSString class]]) {
            NSLog(@"FirebaseSimpleLogin: Could not find FacebookAppID in default .plist file (%@). Is it set up properly? Using bundle at path: %@", facebookAppId, [bundle bundlePath]);
            return;
        }
        if (![facebookAppName isKindOfClass:[NSString class]]) {
            NSLog(@"FirebaseSimpleLogin: Could not find FacebookDisplayName in default .plist file (%@). This value must be an exact match to the value of the 'Display Name' field under the Facebook app Settings. Is it set up properly? Using bundle at path: %@", facebookAppName, [bundle bundlePath]);
            return;
        }

        if (![facebookAppId isEqualToString:appId]) {
            NSLog(@"FirebaseSimpleLogin: Found incorrect FacebookAppID in .plist file: %@. Was expecting %@", facebookAppId, appId);
            return;
        }

        [NSClassFromString(@"FBSettings") setDefaultAppID:appId];
        if ([FirebaseSimpleLogin containsPublishActions:permissions]) {
            FBSessionDefaultAudience fbAudience = [FirebaseSimpleLogin translateFacebookAudience:audience];
            [NSClassFromString(@"FBSession") openActiveSessionWithPublishPermissions:permissions defaultAudience:fbAudience allowLoginUI:YES completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                [self facebookSessionStateChanged:session state:status error:error userCallback:userCallback];
            }];
        } else {
            [NSClassFromString(@"FBSession") openActiveSessionWithReadPermissions:permissions allowLoginUI:YES completionHandler:^(FBSession *session, FBSessionState state, NSError *error) {
                [self facebookSessionStateChanged:session state:state error:error userCallback:userCallback];
            }];
        }
    } else {
        [self requestFacebookAccountWithPermissions:permissions audience:audience appId:appId withBlock:^(NSError *error, ACAccount *account) {
            if (error) {
                userCallback(error, nil);
            } else {
                ACAccountCredential* credential = [account credential];
                NSString* token = [credential oauthToken];
                NSDictionary* providerData = @{@"permissions": permissions, @"audience": audience, @"appId": appId};
                [self createFacebookUserWithToken:token providerData:providerData account:account andUserCallback:userCallback];
            }
        }];
    }
}

- (void) createFacebookUserWithToken:(NSString *)token appId:(NSString *)appId withCompletionBlock:(fabt_void_nserror_user)block {
    fabt_void_nserror_user userCallback = [block copy];
    NSDictionary* providerData = @{@"appId": appId};
    [self createFacebookUserWithToken:token providerData:providerData account:nil andUserCallback:userCallback];
}

// Internal. Shared by auth via OS and auth via token
- (void) createFacebookUserWithToken:(NSString *)token providerData:(NSDictionary *)providerData account:(ACAccount *)account andUserCallback:(fabt_void_nserror_user)userCallback {
    [self makeRequestTo:FIREBASE_AUTH_PATH_FACEBOOKTOKEN withData:@{@"access_token": token} andCallback:^(NSError *error, NSDictionary *json) {
        if (error) {
            userCallback(error, nil);
        } else {
            NSString* token = [json objectForKey:@"token"];
            if (token == nil) {
                NSDictionary* errorDetails = [json objectForKey:@"error"];
                NSError* userError = [FirebaseSimpleLogin errorFromResponse:errorDetails];
                if (self.hasFacebookSDK && userError.code == FAErrorBadSystemToken) {
                    [NSClassFromString(@"FBSession") renewSystemCredentials:^(ACAccountCredentialRenewResult result, NSError *error) {
                        NSLog(@"Renewed. May need to start process over?");
                    }];
                }
                userCallback(userError, nil);
            } else {
                NSMutableDictionary* userData = [[json objectForKey:@"user"] mutableCopy];
                [userData setObject:providerData forKey:@"provider_data"];
                [self attemptAuthWithToken:token provider:FAProviderFacebook userData:userData account:account andCallback:userCallback];
            }
        }
    }];
}

// Internal.
- (void) loginToProvider:(FAProvider)provider path:(NSString *)path params:(NSDictionary *)params andUserCallback:(fabt_void_nserror_user)userCallback {
    [self makeRequestTo:path withData:params andCallback:^(NSError *error, NSDictionary *json) {
        if (error) {
            userCallback(error, nil);
        } else {
            NSString* token = [json objectForKey:@"token"];
            if (token == nil) {
                NSDictionary* errorDetails = [json objectForKey:@"error"];
                NSError* userError = [FirebaseSimpleLogin errorFromResponse:errorDetails];
                userCallback(userError, nil);
            } else {
                NSMutableDictionary* userData = [[json objectForKey:@"user"] mutableCopy];
                [self attemptAuthWithToken:token provider:provider userData:userData account:nil andCallback:userCallback];
            }
        }
    }];
}

- (void) loginToGoogleWithAccessToken:(NSString *)accessToken withCompletionBlock:(fabt_void_nserror_user)block {
  [self loginWithGoogleWithAccessToken:accessToken withCompletionBlock:block];
}


- (void) loginWithGoogleWithAccessToken:(NSString *)accessToken withCompletionBlock:(fabt_void_nserror_user)block {
    fabt_void_nserror_user userCallback = [block copy];
    NSDictionary* providerData = @{
      @"access_token": accessToken
    };
    [self loginToProvider:FAProviderGoogle path:FIREBASE_AUTH_PATH_GOOGLETOKEN params:providerData andUserCallback:userCallback];
}

- (void) loginWithFacebookWithAccessToken:(NSString *)accessToken withCompletionBlock:(fabt_void_nserror_user)block {
    fabt_void_nserror_user userCallback = [block copy];
    NSDictionary* providerData = @{
      @"access_token": accessToken
    };
    [self loginToProvider:FAProviderFacebook path:FIREBASE_AUTH_PATH_FACEBOOKTOKEN params:providerData andUserCallback:userCallback];
}

- (void) loginWithTwitterWithAccessToken:(NSString *)accessToken andAccessTokenSecret:(NSString *)accessTokenSecret
         andTwitterUserId:(NSString *)twitterUserId withCompletionBlock:(fabt_void_nserror_user)block {
    fabt_void_nserror_user userCallback = [block copy];
    NSDictionary* providerData = @{
      @"oauth_token": accessToken,
      @"oauth_token_secret": accessTokenSecret,
      @"user_id": twitterUserId
    };
    [self loginToProvider:FAProviderTwitter path:FIREBASE_AUTH_PATH_TWITTERTOKEN params:providerData andUserCallback:userCallback];
}

- (void) requestFacebookAccountWithPermissions:(NSArray *)permissions audience:(NSString *)audience appId:(NSString *)appId withBlock:(fabt_void_nserror_acaccount)block {
    ACAccountType* accountType = [self.store accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
    NSDictionary* fbOptions = @{ACFacebookAppIdKey: appId, ACFacebookPermissionsKey: permissions, ACFacebookAudienceKey: audience};
    [self.store requestAccessToAccountsWithType:accountType options:fbOptions completion:^(BOOL granted, NSError *error) {
        if (error) {
            if (error.code == ACErrorAccountNotFound) {
                NSError* theError = [FirebaseSimpleLogin errorFromResponse:@{@"code": @"NO_ACCOUNT", @"message": @"No Facebook account was found"}];
                block(theError, nil);
            } else {
                block(error, nil);
            }
        } else if (!granted) {
            NSError* theError = [FirebaseSimpleLogin errorFromResponse:@{@"code": @"NO_ACCESS", @"message": @"Access to Facebook account was not granted"}];
            block(theError, nil);
        } else {
            NSArray* accounts = [self.store accountsWithAccountType:accountType];
            ACAccount* fbAccount = [accounts lastObject];
            if (!fbAccount) {
                NSError* theError = [FirebaseSimpleLogin errorFromResponse:@{@"code": @"NO_ACCOUNT", @"message": @"No Facebook account was found"}];
                block(theError, nil);
            } else {
                block(nil, fbAccount);
            }
        }
    }];
}

#pragma mark -
#pragma mark External Twitter methods

- (void) loginToTwitterAppWithId:(NSString *)appId multipleAccountsHandler:(fabt_int_nsarray)accountSelection withCompletionBlock:(void (^)(NSError* error, FAUser* user))block {

    fabt_void_nserror_user userCallback = [block copy];
    fabt_int_nsarray userAccountSelection  = [accountSelection copy];

    // Step1:
    NSDictionary* data = @{};
    [self makeRequestTo:FIREBASE_AUTH_PATH_TWITTERREVERSE withData:data andCallback:^(NSError *error, NSDictionary *json) {
        if (error != nil) {
            userCallback(error, nil);
        } else {
            NSString* oauth = [json objectForKey:@"oauth"];
            if (oauth == nil) {
                NSDictionary* errorDetails = [json objectForKey:@"error"];
                NSError* userError = [FirebaseSimpleLogin errorFromResponse:errorDetails];
                userCallback(userError, nil);
            } else {
                [self twitterStep2AuthWithAppId:appId oauth:oauth accountSelection:userAccountSelection andCallback:userCallback];
            }
        }
    }];
}

- (void) twitterStep2AuthWithAppId:(NSString *)appId oauth:(NSString *)oauth accountSelection:(fabt_int_nsarray)accountSelection andCallback:(fabt_void_nserror_user)userCallback {

    NSMutableDictionary* params = [[NSMutableDictionary alloc] init];
    [params setValue:appId forKey:@"x_reverse_auth_target"];
    [params setValue:oauth forKey:@"x_reverse_auth_parameters"];

    NSURL* url = [NSURL URLWithString:@"https://api.twitter.com/oauth/access_token"];
    SLRequest* req = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:url parameters:params];

    [self requestTwitterAccountWithBlock:^(NSError *error, ACAccount *account) {
        if (error) {
            userCallback(error, nil);
        } else {
            [req setAccount:account];
            [req performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                if (error) {
                    userCallback(error, nil);
                } else {
                    NSString* data = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                    [self twitterStep3AuthWithAccountData:data account:account andUserCallback:userCallback];
                }
            }];
        }
    } multipleAccountsHandler:accountSelection];
}

- (void) requestTwitterAccountWithBlock:(fabt_void_nserror_acaccount)block multipleAccountsHandler:(fabt_int_nsarray)onMultipleAccounts {
    ACAccountType* accountType = [self.store accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [self.store requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
        if (error) {
            block(error, nil);
        } else if (!granted) {
            NSError* theError = [FirebaseSimpleLogin errorFromResponse:@{@"code": @"NO_ACCESS", @"message": @"Access to Facebook account was not granted"}];
            block(theError, nil);
        } else {
            NSArray* accounts = [self.store accountsWithAccountType:accountType];
            ACAccount* twAccount = nil;
            if (accounts.count == 1) {
                twAccount = [accounts lastObject];
            } else if (accounts.count > 1) {

                NSMutableArray* usernames = [[NSMutableArray alloc] init];
                for (ACAccount* account in accounts) {
                    [usernames addObject:account.username];
                }
                int accountIndex = onMultipleAccounts(usernames);
                if (accountIndex != NSNotFound) {
                    twAccount = [accounts objectAtIndex:accountIndex];
                }
            }

            if (twAccount == nil) {
                NSError* theError = [FirebaseSimpleLogin errorFromResponse:@{@"code": @"NO_ACCOUNT", @"message": @"No twitter account found"}];
                block(theError, nil);
            } else {
                block(nil, twAccount);
            }
        }
    }];
}

- (void) twitterStep3AuthWithAccountData:(NSString *)accountData account:(ACAccount *)account andUserCallback:(fabt_void_nserror_user)userCallback {
    NSMutableDictionary* params = [[NSMutableDictionary alloc] init];

    NSArray* creds = [accountData componentsSeparatedByString:@"&"];
    for (NSString* param in creds) {
        NSArray* parts = [param componentsSeparatedByString:@"="];
        [params setObject:[parts objectAtIndex:1] forKey:[parts objectAtIndex:0]];
    }

    [self makeRequestTo:FIREBASE_AUTH_PATH_TWITTERTOKEN withData:params andCallback:^(NSError *error, NSDictionary *json) {
        if (error) {
            userCallback(error, nil);
        } else {
            NSString* token = [json objectForKey:@"token"];
            if (token == nil) {
                NSDictionary* errorDetails = [json objectForKey:@"error"];
                NSError* userError = [FirebaseSimpleLogin errorFromResponse:errorDetails];
                userCallback(userError, nil);
            } else {
                NSDictionary* userData = [json objectForKey:@"user"];
                [self attemptAuthWithToken:token provider:FAProviderTwitter userData:userData account:account andCallback:userCallback];
            }
        }
    }];
}

#pragma mark -
#pragma mark External Anonymous login methods

- (void) loginAnonymouslywithCompletionBlock:(void (^)(NSError* error, FAUser* user))block {
    fabt_void_nserror_user userCallback = [block copy];

    [self makeRequestTo:FIREBASE_AUTH_PATH_ANONYMOUS withData:@{} andCallback:^(NSError *error, NSDictionary *json) {
        if (error) {
            userCallback(error, nil);
        } else {
            NSString* token = [json objectForKey:@"token"];
            if (token == nil) {
                NSDictionary* errorDetails = [json objectForKey:@"error"];
                NSError* userError = [FirebaseSimpleLogin errorFromResponse:errorDetails];
                block(userError, nil);
            } else {
                NSDictionary* userData = [json objectForKey:@"user"];
                [self attemptAuthWithToken:token provider:FAProviderAnonymous userData:userData account:nil andCallback:userCallback];
            }
        }
    }];
}

#pragma mark -
#pragma mark External Email/Password methods

- (void) loginWithEmail:(NSString *)email andPassword:(NSString *)password withCompletionBlock:(void (^)(NSError* error, FAUser* user))block {
    fabt_void_nserror_user userCallback = [block copy];
    if (![FAValidation isValidEmail:email]) {
        [self onInvalidArgWithError:[self errorForInvalidEmail] AndUserCallback:userCallback];
    } else if (![FAValidation isValidPassword:password]) {
        [self onInvalidArgWithError:[self errorForInvalidPassword] AndUserCallback:userCallback];
    } else {
        NSDictionary* data = @{@"email": email, @"password": password};
        [self makeRequestTo:FIREBASE_AUTH_PATH_PASSWORD withData:data andCallback:^(NSError *error, NSDictionary *json) {
            if (error) {
                userCallback(error, nil);
            } else {
                NSString* token = [json objectForKey:@"token"];
                if (token == nil) {
                    NSDictionary* errorDetails = [json objectForKey:@"error"];
                    NSError* userError = [FirebaseSimpleLogin errorFromResponse:errorDetails];
                    block(userError, nil);
                } else {
                    NSDictionary* userData = [json objectForKey:@"user"];
                    [self attemptAuthWithToken:token provider:FAProviderPassword userData:userData account:nil andCallback:userCallback];
                }
            }
        }];
    }
}

- (void) createUserWithEmail:(NSString *)email password:(NSString *)password andCompletionBlock:(fabt_void_nserror_user)block {
    fabt_void_nserror_user userCallback = [block copy];
    if (![FAValidation isValidEmail:email]) {
        [self onInvalidArgWithError:[self errorForInvalidEmail] AndUserCallback:userCallback];
    } else if (![FAValidation isValidPassword:password]) {
        [self onInvalidArgWithError:[self errorForInvalidPassword] AndUserCallback:userCallback];
    } else {
        NSDictionary* data = @{@"email": email, @"password": password};

        [self makeRequestTo:FIREBASE_AUTH_PATH_PASSWORD_CREATEUSER withData:data andCallback:^(NSError* error, NSDictionary* json) {
            if (error) {
                userCallback(error, nil);
            } else {
                NSDictionary* errorDetails = [json objectForKey:@"error"];
                NSDictionary* userData = [json objectForKey:@"user"];
                if (errorDetails) {
                    NSError* theError = [FirebaseSimpleLogin errorFromResponse:errorDetails];
                    userCallback(theError, nil);
                } else if (userData == nil) {
                    NSError* theError = [FirebaseSimpleLogin errorFromResponse:@{}];
                    userCallback(theError, nil);
                } else {
                    NSString* userId = [userData objectForKey:@"id"];
                    NSString* uid = [userData objectForKey:@"uid"];
                    NSString* email = [userData objectForKey:@"email"];
                    BOOL isTemporaryPassword = [[userData objectForKey:@"isTemporaryPassword"] boolValue];
                    FAUser* user = [FAUser userWithId:userId uid:uid token:nil isTemporaryPassword:isTemporaryPassword andEmail:email];
                    if (user) {
                        userCallback(nil, user);
                    } else {
                        NSError* theError = [FirebaseSimpleLogin errorFromResponse:@{}];
                        userCallback(theError, nil);
                    }
                }
            }
        }];
    }
}

- (void) removeUserWithEmail:(NSString *)email password:(NSString *)password andCompletionBlock:(fabt_void_nserror_bool)block {
    fabt_void_nserror_bool userCallback = [block copy];
    if (![FAValidation isValidEmail:email]) {
        [self onInvalidArgWithError:[self errorForInvalidEmail] AndBoolCallback:userCallback];
    } else if (![FAValidation isValidPassword:password]) {
        [self onInvalidArgWithError:[self errorForInvalidPassword] AndBoolCallback:userCallback];
    } else {
        NSDictionary* data = @{@"email": email, @"password": password};

        [self makeRequestTo:FIREBASE_AUTH_PATH_PASSWORD_REMOVEUSER withData:data andCallback:^(NSError* error, NSDictionary* json) {
            if (error) {
                userCallback(error, NO);
            } else {
                NSDictionary* errorDetails = [json objectForKey:@"error"];
                if (errorDetails) {
                    NSError* error = [FirebaseSimpleLogin errorFromResponse:errorDetails];
                    userCallback(error, NO);
                } else {
                    userCallback(nil, YES);
                }
            }
        }];
    }
}

- (void) changePasswordForEmail:(NSString *)email oldPassword:(NSString *)oldPassword newPassword:(NSString *)newPassword completionBlock:(void (^)(NSError* error, BOOL success))block {
    fabt_void_nserror_bool userCallback = [block copy];
    if (![FAValidation isValidEmail:email]) {
        [self onInvalidArgWithError:[self errorForInvalidEmail] AndBoolCallback:userCallback];
    } else if (![FAValidation isValidPassword:newPassword]) {
        [self onInvalidArgWithError:[self errorForInvalidPassword] AndBoolCallback:userCallback];
    } else {
        NSDictionary* data = @{
            @"email": email,
            @"oldPassword": oldPassword,
            @"newPassword": newPassword
        };

        [self makeRequestTo:FIREBASE_AUTH_PATH_PASSWORD_CHANGEPASSWORD withData:data andCallback:^(NSError *error, NSDictionary *json) {
            if (error) {
                userCallback(error, NO);
            } else {
                NSDictionary* errorDetails = [json objectForKey:@"error"];
                if (errorDetails) {
                    NSError* error = [FirebaseSimpleLogin errorFromResponse:errorDetails];
                    userCallback(error, NO);
                } else {
                    userCallback(nil, YES);
                }
            }
        }];
    }
}

- (void) sendPasswordResetForEmail:(NSString *)email andCompletionBlock:(fabt_void_nserror_bool)block {
    fabt_void_nserror_bool userCallback = [block copy];
    if (![FAValidation isValidEmail:email]) {
        [self onInvalidArgWithError:[self errorForInvalidEmail] AndBoolCallback:userCallback];
    } else {
        NSDictionary* data = @{@"email": email};

        [self makeRequestTo:FIREBASE_AUTH_PATH_PASSWORD_RESETPASSWORD withData:data andCallback:^(NSError* error, NSDictionary* json) {
            if (error) {
                userCallback(error, NO);
            } else {
                NSDictionary* errorDetails = [json objectForKey:@"error"];
                if (errorDetails) {
                    NSError* error = [FirebaseSimpleLogin errorFromResponse:errorDetails];
                    userCallback(error, NO);
                } else {
                    userCallback(nil, YES);
                }
            }
        }];
    }
}

#pragma mark -
#pragma mark Internal methods

- (NSError *) errorForInvalidEmail {
    NSError* theError = [FirebaseSimpleLogin errorFromResponse:@{@"code": @"INVALID_EMAIL", @"message": @"The supplied email is invalid"}];
    return theError;
}

- (NSError *) errorForInvalidPassword {
    NSError* theError = [FirebaseSimpleLogin errorFromResponse:@{@"code": @"INVALID_PASSWORD", @"message": @"The password must be a non-empty string"}];
    return theError;
}

- (void) onInvalidArgWithError:(NSError*)error AndUserCallback:(fabt_void_nserror_user)callback {
    fabt_void_void cb = ^{
        callback(error, nil);
    };
    [self performSelector:@selector(executeCallback:) withObject:[cb copy] afterDelay:0];
}

- (void) onInvalidArgWithError:(NSError*)error AndBoolCallback:(fabt_void_nserror_bool)callback {
    fabt_void_void cb = ^{
        callback(error, nil);
    };
    [self performSelector:@selector(executeCallback:) withObject:[cb copy] afterDelay:0];
}

- (void) sendAccountForProvider:(FAProvider)provider andUserData:(NSDictionary *)userData toBlock:(fabt_void_acaccount)block multipleAccountHandler:(fabt_int_nsarray)chooseAccount {
    if (provider == FAProviderPassword) {
        block(nil);
    } else if (provider == FAProviderFacebook) {
        NSDictionary* providerData = [userData objectForKey:@"provider_data"];
        if (!providerData) {
            block(nil);
        } else {
            NSString* audience = [providerData objectForKey:@"audience"];
            NSArray* permissions = [providerData objectForKey:@"permissions"];
            NSString* appId = [providerData objectForKey:@"appId"];
            if (!audience || !permissions || !appId) {
                block(nil);
            } else {
                [self requestFacebookAccountWithPermissions:permissions audience:audience appId:appId withBlock:^(NSError *error, ACAccount *account) {
                    block(account);
                }];
            }
        }
    } else if (provider == FAProviderTwitter) {
        [self requestTwitterAccountWithBlock:^(NSError *error, ACAccount *account) {
            block(account);
        } multipleAccountsHandler:chooseAccount];
    }
}


- (void) clearCredentials {
    FALog(@"Clearing credentials");
    NSDictionary* query = [self keyQueryDict];
    CFDictionaryRef queryRef = (__bridge CFDictionaryRef)query;
    OSStatus status = SecItemDelete(queryRef);
    if (status != noErr && status != errSecItemNotFound) {
        FALog(@"(clearCredentials:) Error clearing credentials from from keychain %d", status);
    }
}

// Note: this method exists as a target for -performSelector:withObject:afterDelay: so that we can force a block to be async, even if
// it was the result of a local operation.
- (void) executeCallback:(fabt_void_void)callback {
    callback();
}

- (NSMutableDictionary *) keyQueryDict {
    NSMutableDictionary* attrs = [[NSMutableDictionary alloc] init];
    [attrs setObject:(__bridge NSString *)kSecClassInternetPassword forKey:(__bridge NSString *)kSecClass];
    [attrs setObject:[NSString stringWithFormat:@"Firebase_%@", self.namespace] forKey:(__bridge NSString *)kSecAttrAccount];
    [attrs setObject:self.apiHost forKey:(__bridge NSString *)kSecAttrServer];
    return attrs;
}

// Note that the callback should be copied to the heap before being sent to this method
- (void) attemptAuthWithToken:(NSString *)token provider:(FAProvider)provider userData:(NSDictionary *)userData account:(ACAccount *)account andCallback:(fabt_void_nserror_user)callback {
    [self.ref authWithCredential:token withCompletionBlock:^(NSError *error, id data) {
        if (error) {
            callback(error, nil);
        } else {
            FAUser* user = [self saveSessionWithToken:token provider:provider andUserData:userData];
            if (user != nil) {
                user.thirdPartyUserAccount = account;
                Firebase* authRef = [ref.root childByAppendingPath:@".info/authenticated"];
                __block FirebaseHandle handle = [authRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
                    NSNumber* val = snapshot.value;
                    BOOL authed = [val boolValue];
                    if (!authed) {
                        [self clearCredentials];
                        [authRef removeObserverWithHandle:handle];
                    }
                }];
            }
            callback(nil, user);
        }
    } withCancelBlock:^(NSError *error) {
        [self clearCredentials];
        callback(nil, nil);
    }];
}

- (FAUser *) saveSessionWithToken:(NSString *)token provider:(FAProvider)provider andUserData:(NSDictionary *)userData {
    [self clearCredentials];
    NSString* userId = [userData objectForKey:@"id"];
    NSString* uid = [userData objectForKey:@"uid"];
    FAUser* user = nil;
    if (provider == FAProviderPassword) {
        NSString* email = [userData objectForKey:@"email"];
        BOOL isTemporaryPassword = [[userData objectForKey:@"isTemporaryPassword"] boolValue];
        user = [FAUser userWithId:userId uid:uid token:token isTemporaryPassword:isTemporaryPassword andEmail:email];
    } else if (provider == FAProviderFacebook || provider == FAProviderTwitter || provider == FAProviderAnonymous || provider == FAProviderGoogle) {
        NSMutableDictionary* thirdPartyData = [userData mutableCopy];
        [thirdPartyData removeObjectForKey:@"sessionKey"];
        [thirdPartyData removeObjectForKey:@"provider"];
        [thirdPartyData removeObjectForKey:@"provider_data"];
        user = [FAUser userWithId:userId uid:uid token:token provider:provider userData:thirdPartyData];
    }

    NSMutableDictionary* attrs = [self keyQueryDict];

    // Set the actual data
    NSDictionary* keyDict = @{@"token": token, @"userData": userData};

    NSData* keyData = [NSJSONSerialization dataWithJSONObject:keyDict options:kNilOptions error:nil];
    [attrs setObject:keyData forKey:(__bridge NSString *)kSecValueData];
    CFDictionaryRef attrRef = (__bridge CFDictionaryRef)attrs;
    OSStatus status = SecItemAdd(attrRef, NULL);
    if (status != noErr) {
        FALog(@"(saveSessionWithToken:) Error saving to keychain: %d", status);
        user = nil;
    }

    return user;
}

- (void) makeRequestTo:(NSString *)urlPath withData:(NSDictionary *)data andCallback:(fabt_void_nserror_json)callback {
    NSMutableArray* params = [[NSMutableArray alloc] initWithCapacity:data.count + 1];
    [params addObject:[NSString stringWithFormat:@"firebase=%@", self.namespace]];
    [params addObject:@"mobile=ios"];
    [params addObject:@"transport=json"];

    [data enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSString* obj, BOOL *stop) {
        NSString* pair = [NSString stringWithFormat:@"%@=%@", [key urlEncoded], [obj urlEncoded]];
        [params addObject:pair];
    }];
    NSString* paramsString = [params componentsJoinedByString:@"&"];

    NSString* urlString = [NSString stringWithFormat:@"%@%@?%@", self.apiHost, urlPath, paramsString];
    NSURL* url = [NSURL URLWithString:urlString];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    NSURLConnection* conn = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    FATupleCallbackData* tuple = [[FATupleCallbackData alloc] init];
    tuple.callback = callback;
    tuple.data = [[NSMutableData alloc] init];
    CFDictionaryAddValue(self.outstandingRequests, (__bridge CFTypeRef)conn, (__bridge const void *)tuple);
    [conn scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [conn start];
}

#pragma mark -
#pragma mark NSURLConnectionDelegate methods

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    FATupleCallbackData* tuple = CFDictionaryGetValue(self.outstandingRequests, (const void *)connection);
    if (tuple == nil) {
        @throw [[NSException alloc] initWithName:@"FirebaseInternalError" reason:@"No record of request" userInfo:nil];
    }
    // Reset our data length
    [tuple.data setLength:0];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    FATupleCallbackData* tuple = CFDictionaryGetValue(self.outstandingRequests, (const void *)connection);
    if (tuple == nil) {
        @throw [[NSException alloc] initWithName:@"FirebaseInternalError" reason:@"No record of request" userInfo:nil];
    }
    [tuple.data appendData:data];
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    FATupleCallbackData* tuple = CFDictionaryGetValue(self.outstandingRequests, (const void *)connection);
    if (tuple == nil) {
        @throw [[NSException alloc] initWithName:@"FirebaseInternalError" reason:@"No record of request" userInfo:nil];
    }
    tuple.callback(error, nil);
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection {
    FATupleCallbackData* tuple = CFDictionaryGetValue(self.outstandingRequests, (const void *)connection);
    if (tuple == nil) {
        @throw [[NSException alloc] initWithName:@"FirebaseInternalError" reason:@"No record of request" userInfo:nil];
    }
    CFDictionaryRemoveValue(self.outstandingRequests, (const void *)connection);
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:tuple.data options:kNilOptions error:nil];
    tuple.callback(nil, json);
}

@end
