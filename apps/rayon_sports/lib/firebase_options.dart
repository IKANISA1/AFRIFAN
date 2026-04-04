import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Default Firebase options for the Rayon Sports Flutter app.
///
/// Generated from the Firebase project `gen-lang-client-0172279957`
/// and checked in so bootstrap remains deterministic in CI and release builds.
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBZWg0JT-v2Qpirp63RbsPqzB4JY2onfJw',
    appId: '1:1074154147498:android:e28b44350c337988dc4ad3',
    messagingSenderId: '1074154147498',
    projectId: 'gen-lang-client-0172279957',
    storageBucket: 'gen-lang-client-0172279957.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC8dE6DUHuVTK9tFkNx31EcEqNeNogUpjw',
    appId: '1:1074154147498:ios:663184a8a24911d5dc4ad3',
    messagingSenderId: '1074154147498',
    projectId: 'gen-lang-client-0172279957',
    storageBucket: 'gen-lang-client-0172279957.firebasestorage.app',
    iosBundleId: 'rw.ikanisa.rayonSports',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyANrlSIDdY30yGkvmrmZaDYOoSCmWc7ZlM',
    appId: '1:1074154147498:web:bd48c4578e35ab4bdc4ad3',
    messagingSenderId: '1074154147498',
    projectId: 'gen-lang-client-0172279957',
    authDomain: 'gen-lang-client-0172279957.firebaseapp.com',
    storageBucket: 'gen-lang-client-0172279957.firebasestorage.app',
    measurementId: 'G-0S5RFM156J',
  );
}
