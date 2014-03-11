//
//  FirebaseSimpleLogin_Private.h
//  FirebaseSimpleLogin
//
//  Created by Greg Soltis on 3/11/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "FirebaseSimpleLogin.h"

@interface FirebaseSimpleLogin ()

- (id) initWithRef:(Firebase *)ref andApiHost:(NSString *)host;

- (id) initWithRef:(Firebase *)ref options:(NSDictionary *)options andApiHost:(NSString *)host;

@end
