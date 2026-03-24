import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProfileData {
  const UserProfileData({
    required this.uid,
    required this.fullname,
    required this.email,
  });

  final String uid;
  final String fullname;
  final String email;
}

class UserFirestoreService {
  UserFirestoreService._();

  static final UserFirestoreService instance = UserFirestoreService._();

  final ValueNotifier<String?> _fallbackDocId = ValueNotifier<String?>(null);

  void setFallbackDocId(String? docId) {
    _fallbackDocId.value = docId;
  }

  UserProfileData _mapDocToProfile(
    String docId,
    Map<String, dynamic> data, {
    String? fallbackEmail,
  }) {
    final String fullname = (data['fullname'] ?? data['fullName'] ?? '')
        .toString()
        .trim();
    final String email = (data['email'] ?? fallbackEmail ?? '')
        .toString()
        .trim();

    return UserProfileData(
      uid: docId,
      fullname: fullname.isEmpty ? '...' : fullname,
      email: email.isEmpty ? '...@...' : email,
    );
  }

  Stream<UserProfileData?> currentUserProfileStream() {
    return Stream<UserProfileData?>.multi((controller) {
      StreamSubscription<User?>? authSub;
      StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? docSub;

      Future<void> bindDoc(String docId, {String? fallbackEmail}) async {
        await docSub?.cancel();
        docSub = FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .snapshots()
            .listen((doc) {
              if (!doc.exists) {
                controller.add(
                  UserProfileData(
                    uid: docId,
                    fullname: 'Không tìm thấy user',
                    email: fallbackEmail ?? '...@...',
                  ),
                );
                return;
              }

              final Map<String, dynamic> data =
                  doc.data() ?? <String, dynamic>{};
              controller.add(
                _mapDocToProfile(docId, data, fallbackEmail: fallbackEmail),
              );
            });
      }

      Future<void> resolveSource() async {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await bindDoc(user.uid, fallbackEmail: user.email);
          return;
        }

        final String? fallbackDocId = _fallbackDocId.value;
        if (fallbackDocId != null && fallbackDocId.isNotEmpty) {
          await bindDoc(fallbackDocId);
          return;
        }

        await docSub?.cancel();
        controller.add(null);
      }

      void fallbackListener() {
        if (FirebaseAuth.instance.currentUser == null) {
          resolveSource();
        }
      }

      authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
        resolveSource();
      });

      _fallbackDocId.addListener(fallbackListener);
      resolveSource();

      controller.onCancel = () async {
        _fallbackDocId.removeListener(fallbackListener);
        await authSub?.cancel();
        await docSub?.cancel();
      };
    });
  }

  Future<UserProfileData?> getCurrentUserProfile() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? docId = user?.uid ?? _fallbackDocId.value;
    if (docId == null || docId.isEmpty) return null;

    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(docId)
        .get();

    if (!doc.exists) {
      return UserProfileData(
        uid: docId,
        fullname: 'Không tìm thấy user',
        email: user?.email ?? '...@...',
      );
    }

    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return _mapDocToProfile(docId, data, fallbackEmail: user?.email);
  }
}
