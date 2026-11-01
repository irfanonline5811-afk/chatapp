
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCes-Mu5_sAftBwzv4g6L0yY0_bXx1MQLc',
    appId: '1:657341398347:web:0f9da1acc0112171ca3cce',
    messagingSenderId: '657341398347',
    projectId: 'chat1-7015e',
    authDomain: 'chat1-7015e.firebaseapp.com',
    storageBucket: 'chat1-7015e.firebasestorage.app',
    measurementId: 'G-0V7HFG701J',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDjtguD7nWqeaFR4-FhyRiCP-FM7qOPoP0',
    appId: '1:657341398347:android:fae90ea5e3146d32ca3cce',
    messagingSenderId: '657341398347',
    projectId: 'chat1-7015e',
    storageBucket: 'chat1-7015e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBcT9tCvndD7mSJhLN5L-U_x-LgRpq_2ng',
    appId: '1:657341398347:ios:ac8db724df2dcc4bca3cce',
    messagingSenderId: '657341398347',
    projectId: 'chat1-7015e',
    storageBucket: 'chat1-7015e.firebasestorage.app',
    iosBundleId: 'com.example.chatapp1',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBcT9tCvndD7mSJhLN5L-U_x-LgRpq_2ng',
    appId: '1:657341398347:ios:ac8db724df2dcc4bca3cce',
    messagingSenderId: '657341398347',
    projectId: 'chat1-7015e',
    storageBucket: 'chat1-7015e.firebasestorage.app',
    iosBundleId: 'com.example.chatapp1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCes-Mu5_sAftBwzv4g6L0yY0_bXx1MQLc',
    appId: '1:657341398347:web:7e1c2339f811968eca3cce',
    messagingSenderId: '657341398347',
    projectId: 'chat1-7015e',
    authDomain: 'chat1-7015e.firebaseapp.com',
    storageBucket: 'chat1-7015e.firebasestorage.app',
    measurementId: 'G-RKW1D3G1ME',
  );
}
