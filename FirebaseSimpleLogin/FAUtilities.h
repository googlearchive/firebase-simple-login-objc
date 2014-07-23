//
// Created by Katherine Fang on 7/23/14.
// Copyright (c) 2014 Firebase. All rights reserved.
//


@interface FAUtilities : NSObject
+ (void) setLoggingEnabled:(BOOL)enabled;
+ (BOOL) getLoggingEnabled;
@end

void FALog(NSString *format, ...);