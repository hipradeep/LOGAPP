import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDVZ2Zhu9Y9UaMmdaOxrzW8k8Yljus0TEQ',
    appId: '1:901601418143:android:5e1f8f31282c21a19e3baa',
    messagingSenderId: '901601418143',
    projectId: 'test-app-dfa9e',
    storageBucket: 'test-app-dfa9e.firebasestorage.app',
  );
}
