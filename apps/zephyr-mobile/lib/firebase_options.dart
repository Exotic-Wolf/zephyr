import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions not configured for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBPy9T8AQ5waPwp_zDAZk2GLjFFDJGNPG8',
    appId: '1:724639603736:android:3ecd44a9778d059d44376d',
    messagingSenderId: '724639603736',
    projectId: 'zephyr-495115',
    storageBucket: 'zephyr-495115.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD1kFTnH3y8nolB-ubATas2oJU1TUJX0-4',
    appId: '1:724639603736:ios:d7df64a9e5bf3d5a44376d',
    messagingSenderId: '724639603736',
    projectId: 'zephyr-495115',
    storageBucket: 'zephyr-495115.firebasestorage.app',
    iosClientId: '724639603736-n8v2kjqfg40l7bqkt26kov8cmofhn2db.apps.googleusercontent.com',
    iosBundleId: 'com.zephyr.zephyrMobile',
  );
}
