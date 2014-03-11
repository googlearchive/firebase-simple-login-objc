//
//  FAValidation.h
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/11/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FAValidation : NSObject

+ (BOOL) isValidEmail:(NSString *)email;
+ (BOOL) isValidPassword:(NSString *)password;

@end
