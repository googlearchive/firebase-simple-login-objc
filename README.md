# Firebase Simple Login - iOS Client

Firebase Simple Login is a simple, easy-to-use authentication service built on
top of [Firebase Custom Login](https://www.firebase.com/docs/security/custom-login.html),
allowing you to authenticate users without any server code.

Enable authentication via a number of third-party providers, anonymous login, or email / password authentication without having to manually store authentication credentials or run a server.

## Installation

To get started with the iOS SDK, see the [Firebase iOS Quickstart Guide](https://www.firebase.com/docs/ios-quickstart.html).

To install in your application, [download from the Firebase CDN](https://www.firebase.com/docs/downloads.html).

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

```objc
Firebase* ref = [[Firebase alloc] initWithUrl:@"https://SampleChat.firebaseIO-demo.com"];
FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:ref];
```

Once you have instantiated the client library, check the user's authentication
status:

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

In addition, you can monitor the user's authentication state with respect to your Firebase by observing events at a special location: .info/authenticated

```java
Firebase authRef = ref.getRoot().child(".info/authenticated");
authRef.addValueEventListener(new ValueEventListener() {
  public void onDataChange(DataSnapshot snap) {
    boolean isAuthenticated = snap.getValue(Boolean.class);
  }
  public void onCancelled() {}
});
```

If the user is logged out, try authenticating using the provider of your choice:

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
