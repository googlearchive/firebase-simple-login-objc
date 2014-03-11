//
//  FAValidation.m
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/11/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "FAValidation.h"

@implementation FAValidation

static NSString *const kValidEmailRegex = @"^([a-zA-Z0-9_\\.\\-\\+])+\\@(([a-zA-Z0-9\\-])+\\.)+([a-zA-Z0-9]{2,4})+$";

+ (BOOL) isValidEmail:(NSString *)email {
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", kValidEmailRegex];
    return email != nil && email.length > 0 && [predicate evaluateWithObject:email];
}

+ (BOOL) isValidPassword:(NSString *)password {
    return (password != nil && password.length > 0);
}

@end
