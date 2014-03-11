//
//  NSString+FAURLUtils.m
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/11/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "NSString+FAURLUtils.h"

@implementation NSString (FAURLUtils)

- (NSString *) urlDecoded {
    NSString* replaced = [self stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    NSString* decoded = [replaced stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    // This is kind of a hack, but is generally how the js client works. We could run into trouble if
    // some piece is a correctly escaped %-sequence, and another isn't. But, that's bad input anyways...
    if (decoded) {
        return decoded;
    } else {
        return replaced;
    }
}

- (NSString *) urlEncoded {
    CFStringRef urlString = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)self, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8);
    return (__bridge NSString *) urlString;
}

@end
