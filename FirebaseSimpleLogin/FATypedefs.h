//
//  FATypedefs.h
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/11/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#ifndef FirebaseSimpleLogin_FATypedefs_h
#define FirebaseSimpleLogin_FATypedefs_h

#import "FAUser.h"

typedef void (^fabt_void_nserror_user)(NSError* error, FAUser* user);
typedef void (^fabt_void_nserror_json)(NSError* error, NSDictionary* json);
typedef void (^fabt_void_void)(void);
typedef void (^fabt_void_nserror_bool)(NSError* error, BOOL success);
typedef int (^fabt_int_nsarray)(NSArray* usernames);
typedef void (^fabt_void_acaccount)(ACAccount* account);
typedef void (^fabt_void_nserror_acaccount)(NSError* error, ACAccount* account);

#endif
