# Authenticating Users with Facebook - iOS


## Configuring Your Application

To get started with Facebook authentication in Firebase Simple Login, you need to first [create a new Facebook application](https://developers.facebook.com/apps). Click the __Create New App__ button in the top right of that page. Choose a name, namespace, and category for your application.

In your Facebook app configuration, click on the __Settings__ tab on the left-hand navigation menu. Then go to the __Advanced__ tab at the top and scroll down to the __Security__ section. At the bottom of that section, add `https://auth.firebase.com/auth/facebook/callback` to your __Valid OAuth redirect URIs__ and click __Save Changes__ at the bottom of the page.

Next, you'll need to get your app credentials from Facebook. Click on the __Basic__ tab at the top of the page. You should still be within the __Settings__ tab. Towards the top of this page, you will see your __App ID__ and __App Secret__. Your __App ID__ will be displayed in plain text and you can view your __App Secret__ by clicking on the __Show__ button and typing in your Facebook password. Copy these Facebook application credentials (__App ID__ and __Secret__) in the __Simple Login__ section in your Firebase Dashboard.

### Adding Contact Information

Facebook requires that you have a valid contact email specified in order to make your app available to all users. You can specify this email address from the same __Basic__ tab within the __Settings__ section. After you have provided your email, click on __Save Changes__. The last thing you need to do to approve your app is click on the __Status & Review__ tab on the left-hand navigation menu and move the slider at the top of that page to the __Yes__ position. When prompted with a popup, click __Confirm__. Your app will now be live and can be used with Firebase Simple Login.


## Using the Facebook SDK

When we attempt to log a user into the application, Firebase Simple Login will use the Facebook iOS SDK, if it's included in your app. If not, Firebase Simple Login will fall back to checking if the user has connected a Facebook account to their device. Once a user has authorized the app, future login attempts will be transparent.

In order to use the Facebook SDK:

* In your `.plist` file, you must have the __FacebookAppID__ and __FacebookDisplayName__ keys set to your Facebook application id and display name.

*In your `AppDelegate` file, you must handle redirects from Facebook to your application:

__Objective-C:__
```objc
#import <FacebookSDK/FacebookSDK.h>
@implementation AppDelegate
...
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    BOOL wasHandled = [FBAppCall handleOpenURL:url sourceApplication:sourceApplication];
    // add any app-specific handling code here
    return wasHandled;
}
@end
```

__Swift:__
```swift
class AppDelegate: UIResponder, UIApplicationDelegate {

    ...

    func application(application: UIApplication, openURL url: NSURL,
        sourceApplication: String!, annotation: AnyObject) -> Bool {

        var wasHandled = FBAppCall.handleOpenURL(url, sourceApplication:sourceApplication)

        // any app-specific handling code here
        return wasHandled
    }
}
```


## Authenticating Facebook users to your Firebase

Once your application has been setup to log users into Facebook, your application can then authenticate them to Firebase in order to take advantage of the security rules used to protect data in Firebase.

To log a user in, we'll need the application's Facebook App ID. In addition, the scope of permissions must be specified as well as the audience that the app is requesting. When no scope is specified, __email__ is assumed. If no audience is specified, [`ACFacebookAudienceOnlyMe`](https://developer.apple.com/library/ios/documentation/Accounts/Reference/ACAccountStoreClassRef/ACAccountStore.html) is assumed. Note that even if the Facebook SDK is present, the `ACFacebookAudience` constants should only be used to specify the audience.

### A note about read-only vs write permissions

Facebook requires that the user connect to the app before any write permissions can be requested. Unless we know that we have a returning user, it is recommended to request read-only permissions. Then, once the user has authorized, we can either login again with write permissions, or use the Accounts Framework directly to request more permissions. When a user logs in, if the login was through a Facebook account connected with the device, the `FAUser` passed to your block will have an `ACAccount` property called `thirdPartyUserAccount` that can be used in conjunction with `SLRequest` to interact with Facebook on the user's behalf. If the login was through the Facebook SDK, the account will not be present and we should continue to use the Facebook SDK to interact with Facebook on the user's behalf.


__Objective-C:__
```objc
FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:myRef];
[authClient loginToFacebookAppWithId:@"YOUR_FACEBOOK_APP_ID" permissions:@[@"email"]
    audience:ACFacebookAudienceOnlyMe
    withCompletionBlock:^(NSError *error, FAUser *user) {
    if (error != nil) {
      // There was an error logging in
    } else {
      // We have a logged in Facebook user
    }
}];
```

__Swift:__
```swift
var authClient = FirebaseSimpleLogin(ref:myRef)
authClient.loginToFacebookAppWithId("YOUR_FACEBOOK_APP_ID", permissions: ["email"],
    audience: ACFacebookAudienceOnlyMe, withCompletionBlock: { error, user in

    if error {
        // There was an error logging in
    } else if user {
        // We have a logged in Facebook user
    }
})
```

If we're successful, `user.thirdPartyUserData` will be an `NSDictionary` containing metadata returned from Facebook about this user. If the login was made through an account connected to the device, `user.thirdPartyUserAccount` will be an `ACAccount` corresponding to this user's Facebook account. Also, `user.userId` will be the user's Facebook id.


## After Authenticating

Now that the client is logged in, your [Security Rules](https://www.firebase.com/docs/ios/guide/securing-data.html) will have access to their verified Facebook ID. Specifically, the `auth` variable will contain the following values:

| Field | Description | Type |
| --- | --- | --- |
| id | The user's Facebook id. | String |
| provider | The authentication method used, in this case: `facebook`. | String |
| uid | A unique id combining the provider and id, intended as the unique key for user data. | String |


## Permission Scope

Facebook only provides us with access to a user's basic profile information. If we want access to other private data, we need to request permission. We can provide our permissions — also known as scopes — when calling the `login` method. The `scope` property will allow us to request access the these permissions.

The `email` and `user_likes` scopes will give us access to the user's primary email and a list of things that the user likes, respectively. Those are just two of [many permissions we can request](https://developers.facebook.com/docs/facebook-login/permissions/). To gain access to those permissions [a review process is required by Facebook](https://developers.facebook.com/docs/facebook-login/permissions/#review). If the review is approved we then can provide the permissions to the `login` method. Make sure to select these permission on Facebook's app dashboard in addition to providing them in `scope`.

When the user successfully logs in we will get back an `accessToken` in the `user` object. The Facebook permissions are encoded in the `accessToken` that is returned within the `user` object. With this `accessToken` we can query the Open Graph API to access our requested permissions.

__Objective-C:__
```objc
FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:myRef];
[authClient loginToFacebookAppWithId:@"YOUR_FACEBOOK_APP_ID" permissions:@[@"email, user_likes"]
    audience:ACFacebookAudienceOnlyMe
    withCompletionBlock:^(NSError *error, FAUser *user) {
    if (error != nil) {
      // There was an error logging in
    } else {
      // the access token will allow us to make Open Graph API calls
      NSLog(user.authToken);
    }
}];
```

__Swift:__
```swift
var authClient = FirebaseSimpleLogin(ref:myRef)
FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:myRef];
authClient.loginToFacebookAppWithId("YOUR_FACEBOOK_APP_ID", permissions: ["email, user_likes"],
    audience: ACFacebookAudienceOnlyMe, withCompletionBlock: { error, user in

    if error {
        // There was an error logging in
    } else if user {

      // the access token will allow us to make Open Graph API calls
      NSLog(user.authToken);

    }
})
```


## Example

There is an example iOS app using Facebook authentication [available on Github](https://github.com/firebase/simple-login-demo-ios).
