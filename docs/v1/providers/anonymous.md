# Anonymous Authentication - iOS

Firebase Simple Login provides an easy way to create anonymous guest accounts in your application, which lets you write and enable security rules without requiring credentials from your users.

Each time you log-in a user anonymously, a new, unique user id will be generated, and your Firebase reference will be authenticated using these new credentials. The session will live until its configured expiration time in the __Simple Login__ tab of your Firebase Dashboard, or when you explicitly end the session by calling `logout`.

This is particularly useful in applications where you don't want to require account creation or login, but security rules are required to ensure that users only have access to a specific set of data.


## Logging Users In Anonymously

Once an account has been created, you can log a user in to that account like so:

__Objective-C:__
```objc
FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:myRef];
[authClient loginAnonymouslywithCompletionBlock:^(NSError* error, FAUser* user) {
  if (error != nil) {
      // There was an error logging in to this account
  } else {
      // We are now logged in
  }
}];
```

__Swift:__
```swift
var authClient = FirebaseSimpleLogin(ref:myRef)
authClient.loginAnonymouslywithCompletionBlock({ error, user in
    if error {
        // There was an error logging in to this account
    } else {
        // We are now logged in
    }
})
```


## After Authenticating

Now that the client is logged in, your [Security Rules](https://www.firebase.com/docs/ios/guide/securing-data.html) will have access to their unique user id. Specifically, the `auth` variable will contain the following values:

| Field | Description | Type |
| --- | --- | --- |
| id | The new, user-specific alphanumeric ID. | String |
| provider | The authentication method used; in this case, `anonymous`. | String |
| uid | A unique ID combining the provider and ID, intended as the user's unique key across all providers. | String |


# Example

There is an example iOS app using anonymous login [available on Github](https://github.com/firebase/simple-login-demo-ios).
