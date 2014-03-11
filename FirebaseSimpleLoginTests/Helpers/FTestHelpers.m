//
//  FTestHelpers.m
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/10/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "FTestHelpers.h"
#import "FTestConstants.h"
#import <Firebase/Firebase.h>
#import <SenTestingKit/SenTestingKit.h>

@implementation FTestHelpers

+ (Firebase *) getRandomNode {
    Firebase* parent = [[Firebase alloc] initWithUrl:kFirebaseTestNamespace];
    return [parent childByAutoId];
}

+ (BOOL) setDefaultAuthConfigForRef:(Firebase *)ref {
    NSDictionary* config = @{
        @"domains": @"fblocal.com",
        @"sessionLengthSeconds": @604800, // 7 Days
        @"anonymous": @{
            @"enabled": @YES
        },
        @"facebook": @{
            @"enabled": @YES,
            @"key": @"400653440016272",
            @"secret": @""
        },
        @"google": @{
            @"enabled": @YES,
            @"key": @"266982631567-udr4vfg2tjptjotnjk6mv1maoj99daur.apps.googleusercontent.com",
            @"secret": @""
        },
        @"password": @{
            @"enabled": @YES
        },
        @"twitter": @{
            @"enabled": @YES,
            @"key": @"YfnLkH4tHrkYNIPZCdbeQ",
            @"secret": @""
        }
    };
    return [self setAuthConfig:config forRef:ref];
}

+ (BOOL) setAuthConfig:(NSDictionary *)config forRef:(Firebase *)ref {
    NSData* jsonConfig = [NSJSONSerialization dataWithJSONObject:config
                                                        options:kNilOptions error:nil];

    NSString* configString = [[NSString alloc] initWithData:jsonConfig
                                                  encoding:NSUTF8StringEncoding];


    Firebase* root = ref;
    while (root.parent) {
        root = ref.parent;
    }
    NSString* urlString = [NSString stringWithFormat:@"%@/.settings/authConfig.json?auth=%@", [root description], kFirebaseTestSecret];
    //NSLog(@"Uploading auth config to %@", urlString);
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setHTTPMethod:@"PUT"];
    NSData* putBody = [configString dataUsingEncoding:NSUTF8StringEncoding];
    [req setHTTPBody:putBody];

    NSHTTPURLResponse* response = nil;
    NSError* requestError = nil;
    [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&requestError];
    return response.statusCode == 200;
}

@end
