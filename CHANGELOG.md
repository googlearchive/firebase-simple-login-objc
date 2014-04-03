## Firebase Simple Login iOS Changelog:

v1.3.1
-------------
Release Date: 2014-04-03

* Add support for latest Facebook iOS SDK (v3.13) and document changes ([#2](https://github.com/firebase/firebase-simple-login/issues/2))

v1.3.0
-------------
Release Date: 2014-03-06

* Add support for Google / Google+ authentication ([#1](https://github.com/firebase/firebase-simple-login/issues/1))
* Add 'uid' field on FAUser object

v1.2.1
-------------
Release Date: 2014-02-03

* Add options argument to enable security debug mode

v1.2.0
-------------
Release Date: 2014-01-15

* Add support for password resets (see [https://www.firebase.com/docs/security/simple-login-java-email-password.html](https://www.firebase.com/docs/security/simple-login-java-email-password.html))

v1.1.2
-------------
Release Date: 2013-11-19

* Fixes for iOS7 and support for ARM64

v1.1.0
-------------
Release Date: 2013-09-30

* Add support for anonymous authentication provider
* Fix error checking for 'FacebookAppId' instead of 'FacebookAppID'
* Translate OS-level ACFacebookAudience to appropriate FBSession constant if Facebook SDK is present
