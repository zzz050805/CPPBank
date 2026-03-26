import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProfileData {
  const UserProfileData({
    required this.uid,
    required this.fullname,
    required this.email,
    this.hasVipCard = false,
  });

  final String uid;
  final String fullname;
  final String email;
  final bool hasVipCard;
}

class UserFirestoreService {
  UserFirestoreService._();

  static final UserFirestoreService instance = UserFirestoreService._();

  final ValueNotifier<String?> _fallbackDocId = ValueNotifier<String?>(null);
  final StreamController<UserProfileData?> _profileController =
      StreamController<UserProfileData?>.broadcast();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  bool _isProfileBindingInitialized = false;
  UserProfileData? _latestProfile;

  UserProfileData? get latestProfile => _latestProfile;

  bool _isNetworkError(FirebaseException e) {
    final String code = e.code.toLowerCase();
    return code == 'unavailable' ||
        code == 'network-request-failed' ||
        code == 'deadline-exceeded';
  }

  Map<String, dynamic> _standardCardPayload() => <String, dynamic>{
    'balance': 0.0,
    'cardNumber': '**** 1010',
    'cardType': 'Standard',
    'color': '#1A1A75',
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> _vipCardPayload() => <String, dynamic>{
    'balance': 0.0,
    'cardNumber': '**** 2020',
    'cardType': 'VIP',
    'color': '#1A1A1A',
    'updatedAt': FieldValue.serverTimestamp(),
  };

  String? get currentUserDocId {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) return uid;
    final String? fallbackDocId = _fallbackDocId.value;
    if (fallbackDocId != null && fallbackDocId.isNotEmpty) return fallbackDocId;
    return null;
  }

  void setFallbackDocId(String? docId) {
    _fallbackDocId.value = docId;
  }

  void _emitProfile(UserProfileData? profile) {
    _latestProfile = profile;
    if (!_profileController.isClosed) {
      _profileController.add(profile);
    }
  }

  Future<void> _bindDoc(String docId, {String? fallbackEmail}) async {
    await _docSub?.cancel();
    try {
      await ensureUserDataExists(userId: docId);
    } catch (e) {
      debugPrint('ensureUserDataExists failed in stream binding: $e');
    }

    _docSub = FirebaseFirestore.instance
        .collection('users')
        .doc(docId)
        .snapshots()
        .listen(
          (doc) {
            if (!doc.exists) {
              _emitProfile(
                UserProfileData(
                  uid: docId,
                  fullname: 'Không tìm thấy user',
                  email: fallbackEmail ?? '...@...',
                  hasVipCard: false,
                ),
              );
              return;
            }

            final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
            _emitProfile(
              _mapDocToProfile(docId, data, fallbackEmail: fallbackEmail),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Profile stream error: $error');
          },
        );
  }

  Future<void> _resolveSource() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _bindDoc(user.uid, fallbackEmail: user.email);
      return;
    }

    final String? fallbackDocId = _fallbackDocId.value;
    if (fallbackDocId != null && fallbackDocId.isNotEmpty) {
      await _bindDoc(fallbackDocId);
      return;
    }

    await _docSub?.cancel();
    _emitProfile(null);
  }

  void _onFallbackDocIdChanged() {
    if (FirebaseAuth.instance.currentUser == null) {
      unawaited(_resolveSource());
    }
  }

  void _ensureProfileBindingInitialized() {
    if (_isProfileBindingInitialized) return;
    _isProfileBindingInitialized = true;

    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      unawaited(_resolveSource());
    });

    _fallbackDocId.addListener(_onFallbackDocIdChanged);
    unawaited(_resolveSource());
  }

  Future<bool> ensureUserDataExists({
    required String userId,
    Map<String, dynamic> userData = const <String, dynamic>{},
  }) async {
    if (userId.isEmpty) return false;

    final DocumentReference<Map<String, dynamic>> userRef = FirebaseFirestore
        .instance
        .collection('users')
        .doc(userId);
    final CollectionReference<Map<String, dynamic>> cardsRef = userRef
        .collection('cards');
    final DocumentReference<Map<String, dynamic>> standardCardRef = cardsRef
        .doc('standard');
    final DocumentReference<Map<String, dynamic>> vipCardRef = cardsRef.doc(
      'vip',
    );

    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc = await userRef
          .get();

      // Bước 1: chỉ thêm hasVipCard khi field này thực sự chưa tồn tại.
      if (!userDoc.exists) {
        final Map<String, dynamic> sanitizedUserData =
            Map<String, dynamic>.from(userData)..remove('hasVipCard');
        await userRef.set(<String, dynamic>{
          ...sanitizedUserData,
          'hasVipCard': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        final Map<String, dynamic> existingData =
            userDoc.data() ?? <String, dynamic>{};
        if (existingData['hasVipCard'] == null) {
          await userRef.set(<String, dynamic>{
            'hasVipCard': false,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        if (userData.isNotEmpty) {
          final Map<String, dynamic> sanitizedUserData =
              Map<String, dynamic>.from(userData)..remove('hasVipCard');
          if (sanitizedUserData.isNotEmpty) {
            await userRef.set(sanitizedUserData, SetOptions(merge: true));
          }
        }
      }

      // Bước 2: chỉ tạo cards khi document chưa tồn tại, không reset balance.
      final DocumentSnapshot<Map<String, dynamic>> standardCardDoc =
          await standardCardRef.get();
      if (!standardCardDoc.exists) {
        await standardCardRef.set(_standardCardPayload());
      }

      final DocumentSnapshot<Map<String, dynamic>> vipCardDoc = await vipCardRef
          .get();
      if (!vipCardDoc.exists) {
        await vipCardRef.set(_vipCardPayload());
      }

      return true;
    } on FirebaseException catch (e) {
      if (_isNetworkError(e)) {
        debugPrint('ensureUserDataExists network error for $userId: ${e.code}');
        return false;
      }
      rethrow;
    }
  }

  Future<bool> initUserData({
    required String userId,
    Map<String, dynamic> userData = const <String, dynamic>{},
  }) async {
    return ensureUserDataExists(userId: userId, userData: userData);
  }

  Future<bool> syncCurrentUserData({String? docIdOverride}) async {
    final String? docId = docIdOverride ?? currentUserDocId;
    if (docId == null || docId.isEmpty) return false;

    return ensureUserDataExists(userId: docId);
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
    final bool hasVipCard = data['hasVipCard'] == true;

    return UserProfileData(
      uid: docId,
      fullname: fullname.isEmpty ? '...' : fullname,
      email: email.isEmpty ? '...@...' : email,
      hasVipCard: hasVipCard,
    );
  }

  Stream<UserProfileData?> currentUserProfileStream() {
    _ensureProfileBindingInitialized();
    return Stream<UserProfileData?>.multi((controller) {
      if (_latestProfile != null) {
        controller.add(_latestProfile);
      }

      final StreamSubscription<UserProfileData?> sub = _profileController.stream
          .listen(controller.add, onError: controller.addError);

      controller.onCancel = () async {
        await sub.cancel();
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
        hasVipCard: false,
      );
    }

    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return _mapDocToProfile(docId, data, fallbackEmail: user?.email);
  }
}
