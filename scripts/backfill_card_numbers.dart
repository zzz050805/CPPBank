import 'package:flutter/widgets.dart';

import 'package:doan_nganhang/services/firebase_helper.dart';
import 'package:doan_nganhang/services/user_firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseHelper.initializeFirebase();

  final int updatedCount = await UserFirestoreService.instance
      .backfillMissingCardNumbersForAllUsers();

  // ignore: avoid_print
  print('Backfill completed. Updated users: $updatedCount');
}
