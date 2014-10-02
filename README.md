# Firebase Simple Login - iOS Client

Firebase Simple Login is a simple, easy-to-use authentication service built on
top of [Firebase Custom Login](https://www.firebase.com/docs/security/custom-login.html),
allowing you to authenticate users without any server code.

Enable authentication via a number of third-party providers, anonymous login, or email / password authentication without having to manually store authentication credentials or run a server.

## Deprecation Warning!

Firebase Simple Login for iOS is now a part of the core Firebase iOS library. As a result,
this standalone Simple Login client is being deprecated. We encourage everyone to upgrade to the
latest version of the [Firebase iOS Client](https://www.firebase.com/docs/ios/) to get the
latest and greatest features. If you are still using this deprecated Simple Login client,
[you can find documentation for it here](./docs/v1).

You can read more about this change [on our blog](TODO) and see the [updated login documentation](TODO)
on our website. The updated documentation includes migration plans, but if you have any other
questions, please reach out to us at support@firebase.com.

## Installation

To get started with the iOS SDK, see the [Firebase iOS Quickstart Guide](https://www.firebase.com/docs/ios-quickstart.html).

To install in your application, [download from the Firebase CDN](https://www.firebase.com/docs/downloads.html).

### Using Simple Login with Swift

In order to use Simple Login in a Swift project, you'll also need to setup a bridging
header in addition to adding required frameworks to your project. To do that,
[follow these instructions](https://www.firebase.com/docs/ios/guide/setup.html#section-swift),
and then add the following line to your bridging header:

````objective-c
#import <FirebaseSimpleLogin/FirebaseSimpleLogin.h>
````

## Configuration

The Firebase Simple Login iOS Client supports email & password, Facebook, Google,
Twitter, and anonymous authentication methods. Before adding to
your application, you'll need to first enable these auth. providers in your app.

To get started, visit the Simple Login tab in Firebase Forge, at
`https://<YOUR-FIREBASE>.firebaseio.com`. There you may enable / disable auth.
providers, setup OAuth credentials, and configure valid OAuth request origins.

## Usage

Start monitoring user authentication state in your application by instantiating
the Firebase Simple Login client with a Firebase reference, and callback.

##### Objective-C
```objc
Firebase* ref = [[Firebase alloc] initWithUrl:@"https://SampleChat.firebaseIO-demo.com"];
FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:ref];
```

##### Swift
```swift
let ref = Firebase(url:"https://SampleChat.firebaseIO-demo.com")
var authClient = FirebaseSimpleLogin(ref:ref)
```

Once you have instantiated the client library, check the user's authentication
status:

##### Objective-C
```objc
[authClient checkAuthStatusWithBlock:^(NSError* error, FAUser* user) {
    if (error != nil) {
      // Oh no! There was an error performing the check
    } else if (user == nil) {
      // No user is logged in
    } else {
      // There is a logged in user
    }
}];
```

##### Swift
```swift
authRef.checkAuthStatusWithBlock({ error, user in
    if (error != nil) {
        // Oh no! There was an error performing the check
    } else if (user == nil) {
        // No user is logged in
    } else {
        // There is a logged in user
    }
})
```

In addition, you can monitor the user's authentication state with respect to your Firebase by observing events at a special location: .info/authenticated

##### Objective-C
```objc
Firebase* authRef = [ref.root childByAppendingPath:@".info/authenticated"];
[authRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot* snapshot) {
    BOOL isAuthenticated = [snapshot.value boolValue];
}];
```

##### Swift
```swift
var authRef = ref.root.childByAppendingPath(".info/authenticated")
authRef.observeEventType(.Value, withBlock: { snapshot in
    var isAuthenticated = snapshot.value as? Bool
})
```

If the user is logged out, try authenticating using the provider of your choice:

##### Objective-C
```objc
[authClient loginWithEmail:@"email@example.com" andPassword:@"very secret"
    withCompletionBlock:^(NSError* error, FAUser* user) {

    if (error != nil) {
        // There was an error logging in to this account
    } else {
        // We are now logged in
    }
}];
```

##### Swift
```swift
authRef.loginWithEmail("email@example.com", andPassword: "very secret") { (error, user) in
    if (error != nil) {
        // There was an error logging in to this account
    } else {
        // We are now logged in
    }
}
```

## Testing / Compiling From Source

Interested in manually debugging from source, or submitting a pull request?
Don't forget to read the [Contribution Guidelines](../CONTRIBUTING.md) .

To deploy:

```bash
$ ./build.sh
$ cp FirebaseSimpleLogin.framework-$SEMVER.zip ../firebase-clients/ios/.
$ cp CHANGELOG.md ../firebase-clients/ios/.
$ pushd ../firebase-clients/ios/
$ cp FirebaseSimpleLogin.framework-$SEMVER.zip FirebaseSimpleLogin.framework-LATEST.zip
$ ...
```

License
-------
[The MIT License](http://firebase.mit-license.org)

Copyright © 2014 Firebase <opensource@firebase.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
