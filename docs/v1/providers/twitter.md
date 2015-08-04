# Authenticating Users with Twitter - iOS


## Configuring Your Application

To get started with Twitter authentication in Firebase Simple Login, you need to first [create a new Twitter application](https://apps.twitter.com/). Click the __Create New App__ button at the top right of that page and fill in a name, description, and website for your application. Set the application's __Callback URL__ to `https://auth.firebase.com/auth/twitter/callback` so that your application can properly communicate with Firebase.

After configuring your Twitter application, head on over to the __Simple Login__ section in your Firebase Dashboard. Enable Twitter authentication and then copy your Twitter application credentials (__API key__ and __API secret__) into the appropriate inputs. You can find your Twitter application's key and secret at the top of the __API Keys__ tab of the application's Twitter dashboard.


## Authenticating Twitter users to your Firebase

If the user has connected one or more Twitter accounts to their iOS device, we can prompt them to authorize the app. Since devices can have more than one Twitter account, we will need to provide a block that determines which account to log in. After the user has been authenticated with Twitter, signing them into Firebase can be triggered by:

__Objective-C:__
```obj
FirebaseSimpleLogin* authClient = [[FirebaseSimpleLogin alloc] initWithRef:myRef];
[authClient loginToTwitterAppWithId:@"YOUR_CONSUMER_KEY"
    multipleAccountsHandler:^int(NSArray *usernames) {

    // If you do not wish to authenticate with any of these usernames, return NSNotFound.
    return [yourApp selectUserName:usernames];
} withCompletionBlock:^(NSError *error, FAUser *user) {
    if (error != nil) {
      // There was an error authenticating
    } else {
      // We have an authenticated Twitter user
    }
}];
```

__Swift:__
```swift
var authClient = FirebaseSimpleLogin(ref:myRef)
authClient.loginToTwitterAppWithId("YOUR_CONSUMER_KEY",
    multipleAccountsHandler: { usernames -> Int32 in

    // If you do not wish to authenticate with any of these usernames, return NSNotFound.
    return yourApp.selectUserName(usernames)
}, withCompletionBlock: { error, user in
    if error {
        // There was an error authenticating
    } else {
        // We have an authenticated Twitter user
    }
})
```

If we're successful `user.thirdPartyUserData` will be an `NSDictionary` containing metadata returned from Twitter about this user and `user.userId` will be the user's Twitter ID.


## Authenticating with Multiple Accounts

As mentioned in the previous section, since many users have multiple Twitter accounts (personal, work, parody, etc.) we have to ensure that they can authenticate via any of the accounts they have access to. Below is some example code that demonstrates how we can use the `loginToTwitterAppWithId: multipleAccountsHandler:^int(NSArray *)` method to authenticate when a user has multiple Twitter accounts on his or her device.

```objc
- (void)authenticateWithTwitter {
  if (self.currentTwitterHandle) {
    // If the user has a currently selected Twitter handle, log them in normally
    Firebase *ref = [[Firebase alloc] initWithUrl:@"https://<your-firebase>.firebaseio.com"];
    FirebaseSimpleLogin *authClient = [[FirebaseSimpleLogin alloc] initWithRef:ref];
    [authClient loginToTwitterAppWithId:@"TWITTER_APP_ID" multipleAccountsHandler:^int(NSArray *usernames) {
      // Return an int representing the user selected or NSNotFound
      return (int)[usernames indexOfObject:self.currentTwitterHandle];
    } withCompletionBlock:^(NSError *error, FAUser *user) {
      if (error != nil) {
        // An error has occurred!
      } else {
        // We have a user
      }
    }];
  } else {
    // Access account store to pull twitter accounts on device
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    // Present appropriate UI elements to indicate loading, as this operation can take several seconds
    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
        if (granted) {
          NSArray *accounts = [accountStore accountsWithAccountType:accountType];
          [self handleMultipleTwitterAccounts:accounts];
        } else {
          // User has denied access to Twitter accounts
        }
    }];
  }
}

- (void)handleMultipleTwitterAccounts:(NSArray *)accounts {
  switch ([accounts count]) {
    case 0:
      // Deal with setting up a Twitter account (could also not be set up on the device, deal with this differently)
      [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/signup"]];
      break;

    case 1:
      // Single user system, go straight to login
      self.currentTwitterHandle = [[accounts firstObject] username];
      [self authenticateWithTwitter];
      break;

    default:
      // Handle multiple users
      [self selectTwitterAccount:accounts];
      break;
  }
}

- (void)selectTwitterAccount:(NSArray *)accounts {
  // Pop up action sheet which has different user accounts as options
  UIActionSheet *selectUserActionSheet = [[UIActionSheet alloc] initWithTitle:@"Select Twitter Account" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles: nil];
  for (ACAccount *account in accounts) {
    [selectUserActionSheet addButtonWithTitle:[account username]];
  }
  selectUserActionSheet.cancelButtonIndex = [selectUserActionSheet addButtonWithTitle:@"Cancel"];
  [selectUserActionSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
  self.currentTwitterHandle = [actionSheet buttonTitleAtIndex:buttonIndex];
  [self authenticateWithTwitter];
}
```

You should now be able to authenthicate any one of mutiple Twitter accounts tied to a device!

Be sure to present your users with appropriate UI during login (for instance, `UIActivityIndicatorView`), and during error conditions (for instance, a `UIAlertView`).


## After Authenticating

Now that the client is logged in, your [Security Rules](https://www.firebase.com/docs/ios/guide/securing-data.html) will have access to their verified Twitter user id. Specifically, the `auth` variable will contain the following values:

| Field | Description | Type |
| --- | --- | --- |
| id | The user's Twitter id. | String |
| provider | The authentication method used, in this case: `twitter`. | String |
| uid | A unique id combining the provider and id, intended as the unique key for user data. | String |


## Example

There is an example iOS app using Twitter authentication [available on Github](https://github.com/firebase/simple-login-demo-ios).
