import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class HomeCacheData {
  const HomeCacheData({
    this.userId = '',
    this.userName = '',
    this.standardBalance = 0,
    this.vipBalance = 0,
    this.hasVipCard = false,
    this.isStandardLocked = false,
    this.isVipLocked = false,
    this.isReady = false,
  });

  final String userId;
  final String userName;
  final double standardBalance;
  final double vipBalance;
  final bool hasVipCard;
  final bool isStandardLocked;
  final bool isVipLocked;
  final bool isReady;

  double get totalBalance {
    final double visibleStandard = isStandardLocked ? 0 : standardBalance;
    final double visibleVip = (hasVipCard && !isVipLocked) ? vipBalance : 0;
    return visibleStandard + visibleVip;
  }

  HomeCacheData copyWith({
    String? userId,
    String? userName,
    double? standardBalance,
    double? vipBalance,
    bool? hasVipCard,
    bool? isStandardLocked,
    bool? isVipLocked,
    bool? isReady,
  }) {
    return HomeCacheData(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      standardBalance: standardBalance ?? this.standardBalance,
      vipBalance: vipBalance ?? this.vipBalance,
      hasVipCard: hasVipCard ?? this.hasVipCard,
      isStandardLocked: isStandardLocked ?? this.isStandardLocked,
      isVipLocked: isVipLocked ?? this.isVipLocked,
      isReady: isReady ?? this.isReady,
    );
  }

  static const HomeCacheData empty = HomeCacheData();
}

class HomeCacheService {
  HomeCacheService._();

  static final HomeCacheService instance = HomeCacheService._();

  final ValueNotifier<HomeCacheData> notifier = ValueNotifier<HomeCacheData>(
    HomeCacheData.empty,
  );

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cardsSub;

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  bool _parseHasVipCard(dynamic value) {
    return _parseBool(value);
  }

  double _readBalance(dynamic raw) {
    if (raw is num) {
      return raw.toDouble();
    }

    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) return 0;

      final double? direct = double.tryParse(trimmed);
      if (direct != null) return direct;

      final String digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.isEmpty) return 0;
      return double.tryParse(digitsOnly) ?? 0;
    }

    return 0;
  }

  void _mergeUserDoc(Map<String, dynamic> data, {String? fallbackName}) {
    final String nextName =
        (data['fullname'] ?? data['fullName'] ?? fallbackName ?? '')
            .toString()
            .trim();

    notifier.value = notifier.value.copyWith(
      userName: nextName,
      hasVipCard: _parseHasVipCard(data['hasVipCard']),
      isStandardLocked: _parseBool(data['is_standard_locked']),
      isVipLocked: _parseBool(data['is_vip_locked']),
    );
  }

  void _mergeCardsDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    double standardBalance = notifier.value.standardBalance;
    double vipBalance = notifier.value.vipBalance;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final String cardId = doc.id.toLowerCase();
      final double balance = _readBalance(doc.data()['balance']);

      if (cardId == 'standard') {
        standardBalance = balance;
      } else if (cardId == 'vip') {
        vipBalance = balance;
      }
    }

    notifier.value = notifier.value.copyWith(
      standardBalance: standardBalance,
      vipBalance: vipBalance,
    );
  }

  Future<void> preloadForUser({
    required String userId,
    String? fallbackName,
  }) async {
    if (userId.isEmpty) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> userRef = FirebaseFirestore
        .instance
        .collection('users')
        .doc(userId);

    final List<dynamic> fetched = await Future.wait<dynamic>([
      userRef.get(),
      userRef.collection('cards').get(),
    ]);

    final DocumentSnapshot<Map<String, dynamic>> userDoc =
        fetched[0] as DocumentSnapshot<Map<String, dynamic>>;
    final QuerySnapshot<Map<String, dynamic>> cardsSnapshot =
        fetched[1] as QuerySnapshot<Map<String, dynamic>>;

    final Map<String, dynamic> userData = userDoc.data() ?? <String, dynamic>{};
    _mergeUserDoc(userData, fallbackName: fallbackName);
    _mergeCardsDocs(cardsSnapshot.docs);

    notifier.value = notifier.value.copyWith(
      userId: userId,
      userName: notifier.value.userName.isEmpty
          ? (fallbackName ?? notifier.value.userName)
          : notifier.value.userName,
      isReady: true,
    );
  }

  Future<void> refreshCurrent() async {
    final String userId = notifier.value.userId;
    if (userId.isEmpty) {
      return;
    }
    await preloadForUser(userId: userId, fallbackName: notifier.value.userName);
  }

  void applyPaymentDeduction(double amount) {
    if (amount <= 0) {
      return;
    }

    final HomeCacheData current = notifier.value;
    double nextStandard = current.standardBalance;
    double nextVip = current.vipBalance;

    if (nextStandard >= amount) {
      nextStandard -= amount;
    } else {
      final double remaining = amount - nextStandard;
      nextStandard = 0;
      nextVip = (nextVip - remaining).clamp(0, double.infinity).toDouble();
    }

    notifier.value = current.copyWith(
      standardBalance: nextStandard,
      vipBalance: nextVip,
      isReady: true,
    );
  }

  void startRealtimeSync(String userId) {
    if (userId.isEmpty) {
      return;
    }

    if (notifier.value.userId != userId) {
      notifier.value = notifier.value.copyWith(userId: userId);
    }

    _userSub?.cancel();
    _cardsSub?.cancel();

    final DocumentReference<Map<String, dynamic>> userRef = FirebaseFirestore
        .instance
        .collection('users')
        .doc(userId);

    _userSub = userRef.snapshots().listen((snapshot) {
      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
      _mergeUserDoc(data, fallbackName: notifier.value.userName);
      notifier.value = notifier.value.copyWith(isReady: true);
    });

    _cardsSub = userRef.collection('cards').snapshots().listen((snapshot) {
      _mergeCardsDocs(snapshot.docs);
      notifier.value = notifier.value.copyWith(isReady: true);
    });
  }

  Future<void> clear() async {
    await _userSub?.cancel();
    await _cardsSub?.cancel();
    notifier.value = HomeCacheData.empty;
  }
}
