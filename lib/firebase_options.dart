// File generated from Firebase project `kerala-rate`.
// Re-run `flutterfire configure` to refresh platform-specific values (especially iOS/web).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAjHFZzIFSOy41A8KlpFxw5ab_XoJzbBS4',
    appId: '1:108406995110:android:337e2342876f26b7a15c67',
    messagingSenderId: '108406995110',
    projectId: 'kerala-rate',
    storageBucket: 'kerala-rate.firebasestorage.app',
  );

  /// Register an iOS app in Firebase Console, then run `flutterfire configure`.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAjHFZzIFSOy41A8KlpFxw5ab_XoJzbBS4',
    appId: '1:108406995110:ios:0000000000000000000000',
    messagingSenderId: '108406995110',
    projectId: 'kerala-rate',
    storageBucket: 'kerala-rate.firebasestorage.app',
    iosBundleId: 'com.example.spiceroot',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAjHFZzIFSOy41A8KlpFxw5ab_XoJzbBS4',
    appId: '1:108406995110:ios:0000000000000000000000',
    messagingSenderId: '108406995110',
    projectId: 'kerala-rate',
    storageBucket: 'kerala-rate.firebasestorage.app',
    iosBundleId: 'com.example.spiceroot',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAjHFZzIFSOy41A8KlpFxw5ab_XoJzbBS4',
    appId: '1:108406995110:web:0000000000000000000000',
    messagingSenderId: '108406995110',
    projectId: 'kerala-rate',
    authDomain: 'kerala-rate.firebaseapp.com',
    storageBucket: 'kerala-rate.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAjHFZzIFSOy41A8KlpFxw5ab_XoJzbBS4',
    appId: '1:108406995110:web:0000000000000000000000',
    messagingSenderId: '108406995110',
    projectId: 'kerala-rate',
    authDomain: 'kerala-rate.firebaseapp.com',
    storageBucket: 'kerala-rate.firebasestorage.app',
  );
}
