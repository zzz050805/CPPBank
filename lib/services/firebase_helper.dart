import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseHelper {
  FirebaseHelper._();

  static Future<void> initializeFirebase({int maxRetries = 3}) async {
    if (Firebase.apps.isNotEmpty) {
      await _configureFirestore();
      return;
    }

    int attempt = 0;
    while (attempt < maxRetries) {
      attempt++;
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        await _configureFirestore();
        return;
      } catch (e) {
        debugPrint('Firebase init attempt $attempt failed: $e');
        if (attempt >= maxRetries) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  static Future<void> _configureFirestore() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    try {
      await firestore.enableNetwork();
    } catch (e) {
      debugPrint('Firestore network enabling failed: $e');
    }
  }
}
