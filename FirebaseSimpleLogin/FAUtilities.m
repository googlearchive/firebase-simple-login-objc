//
// Created by Katherine Fang on 7/23/14.
// Copyright (c) 2014 Firebase. All rights reserved.
//

#import "FAUtilities.h"

#pragma mark -
#pragma mark C functions

static BOOL loggingEnabled = NO;

void FALog(NSString *format, ...)  {
    if (loggingEnabled) {
        __block va_list arg_list;
        va_start (arg_list, format);

        NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];

        va_end(arg_list);
        NSLog(@"[FirebaseSimpleLogin] %@", formattedString);
    }
}

#pragma mark -
#pragma mark Global methods

@implementation FAUtilities

+ (void) setLoggingEnabled:(BOOL)enabled {
    loggingEnabled = enabled;
}

+ (BOOL) getLoggingEnabled {
    return loggingEnabled;
}

@end