// Placeholder so the starter can compile before Firebase is configured.
// Run `flutterfire configure`; the CLI will replace this file with real options.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'CONFIGURE_FIREBASE_API_KEY',
    appId: '1:000000000000:android:configure-me',
    messagingSenderId: '000000000000',
    projectId: 'bycsm-configure-me',
  );
}
