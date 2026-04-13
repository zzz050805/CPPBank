import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../core/app_translations.dart';
import '../data/notification_firestore_service.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../shoppingservice/service_data.dart';
import '../shoppingservice/service_model.dart';
import '../shoppingservice/shopping_store_screen.dart';
import '../services/home_cache_service.dart';
import '../services/notification_service.dart';
import '../widget/pressable_scale.dart';
import '../widget/shimmer_box.dart';
import '../widget/transaction_detail_popup.dart';
import 'search_screen.dart';
import 'setting_screen.dart';
import 'transfer_money.dart';
import 'phone_recharge.dart';
import 'bill.dart';
import 'QR.dart';
import 'credit_card.dart';
import 'chat_placeholder_screen.dart';
import 'notification.dart';
import 'withdraw_money.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.showBottomNav = true});

  final bool showBottomNav;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _selectedIndex = 0;
  bool _isBalanceVisible = false;
  int _currentBannerIndex = 0;
  int touchedIndex = -1;
  String? _spendingDataUid;
  Future<Map<String, double>>? _spendingDataFutureCache;
  String? _recentTransactionsUid;
  String? _recentTransactionsLanguageCode;
  Future<List<_HomeTransactionModel>>? _recentTransactionsFutureCache;
  double _lastKnownTotalBalance = 0;
  bool _hasLoadedBalance = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _promotionHeadsUpSubscription;
  final Set<String> _seenPromotionNotificationIds = <String>{};
  bool _promotionHeadsUpReady = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  String _formatCurrency(double value) {
    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value).replaceAll(',', '.');
  }

  @override
  void initState() {
    super.initState();
    final HomeCacheData cachedHomeData =
        HomeCacheService.instance.notifier.value;
    if (cachedHomeData.isReady) {
      _lastKnownTotalBalance = cachedHomeData.totalBalance;
      _hasLoadedBalance = true;
    }

    final String uid = _resolveUid();
    if (uid.isNotEmpty) {
      HomeCacheService.instance.startRealtimeSync(uid);
      if (!HomeCacheService.instance.notifier.value.isReady) {
        HomeCacheService.instance.preloadForUser(
          userId: uid,
          fallbackName: UserFirestoreService.instance.latestProfile?.fullname,
        );
      }
      _startPromotionHeadsUpListener(uid);
    }
  }

  void refreshHomeData() {
    final String uid = _resolveUid();
    if (uid.isNotEmpty) {
      HomeCacheService.instance.startRealtimeSync(uid);
      HomeCacheService.instance.refreshCurrent();
      _startPromotionHeadsUpListener(uid);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      touchedIndex = -1;
      _spendingDataUid = null;
      _spendingDataFutureCache = null;
      _recentTransactionsUid = null;
      _recentTransactionsLanguageCode = null;
      _recentTransactionsFutureCache = null;
    });
  }

  @override
  void dispose() {
    _promotionHeadsUpSubscription?.cancel();
    super.dispose();
  }

  void _startPromotionHeadsUpListener(String uid) {
    _promotionHeadsUpSubscription?.cancel();
    _seenPromotionNotificationIds.clear();
    _promotionHeadsUpReady = false;

    _promotionHeadsUpSubscription = NotificationFirestoreService.instance
        .userNotificationsRef(uid)
        .orderBy('timestamp', descending: true)
        .limit(40)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
          if (!_promotionHeadsUpReady) {
            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in snapshot.docs) {
              _seenPromotionNotificationIds.add(doc.id);
            }
            _promotionHeadsUpReady = true;
            return;
          }

          for (final DocumentChange<Map<String, dynamic>> change
              in snapshot.docChanges) {
            if (change.type != DocumentChangeType.added) {
              continue;
            }

            final Map<String, dynamic>? data = change.doc.data();
            if (data == null) {
              continue;
            }

            final String notificationId = change.doc.id;
            if (_seenPromotionNotificationIds.contains(notificationId)) {
              continue;
            }
            _seenPromotionNotificationIds.add(notificationId);

            if (!_shouldShowHeadsUp(data)) {
              continue;
            }

            if (!mounted) {
              continue;
            }

            final String title = _resolveHeadsUpTitle(data);
            final String body = _resolveHeadsUpBody(data);
            NotificationService().showNotification(
              title: title,
              body: body,
              lightVibration: true,
              payload: _buildHeadsUpPayload(data),
            );
          }
        });
  }

  void _pushPremium(Widget page, {bool refreshOnReturn = false}) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page)).then(
      (value) {
        if (refreshOnReturn) {
          refreshHomeData();
        }
      },
    );
  }

  void _replacePremium(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  String _resolveUid() {
    final String cachedUid = HomeCacheService.instance.notifier.value.userId;
    if (cachedUid.isNotEmpty) {
      return cachedUid;
    }

    final String? fromService = UserFirestoreService.instance.currentUserDocId;
    if (fromService != null && fromService.isNotEmpty) {
      return fromService;
    }

    final String? fromProfile =
        UserFirestoreService.instance.latestProfile?.uid;
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }

    final String? fromAuth = FirebaseAuth.instance.currentUser?.uid;
    if (fromAuth != null && fromAuth.isNotEmpty) {
      return fromAuth;
    }

    return '';
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = (value ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  DateTime _readTimestamp(dynamic rawTimestamp) {
    if (rawTimestamp is Timestamp) {
      return rawTimestamp.toDate();
    }
    if (rawTimestamp is DateTime) {
      return rawTimestamp;
    }
    if (rawTimestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    }
    if (rawTimestamp is String) {
      final DateTime? parsed = DateTime.tryParse(rawTimestamp);
      if (parsed != null) {
        return parsed;
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _billTypeToTextKey(String billType) {
    switch (billType.trim().toLowerCase()) {
      case 'electric':
        return 'bill_type_electric';
      case 'water':
        return 'bill_type_water';
      case 'internet':
        return 'bill_type_internet';
      case 'mobile':
      case 'mobile_postpaid':
        return 'bill_type_mobile';
      default:
        return 'service';
    }
  }

  Map<String, String> _readNotificationParams(dynamic raw) {
    final Map<String, String> result = <String, String>{};
    if (raw is! Map) {
      return result;
    }

    raw.forEach((dynamic key, dynamic value) {
      final String k = key.toString().trim();
      final String v = (value ?? '').toString().trim();
      if (k.isEmpty || v.isEmpty) {
        return;
      }
      result[k] = v;
    });

    return result;
  }

  num _readNotificationAmountValue(dynamic value) {
    if (value is num) {
      return value;
    }
    if (value is String) {
      final String text = value.trim();
      if (text.isEmpty) {
        return 0;
      }
      final num? direct = num.tryParse(text);
      if (direct != null) {
        return direct;
      }

      final String digitsOnly = text.replaceAll(RegExp(r'[^0-9.-]'), '');
      return digitsOnly.isEmpty ? 0 : (num.tryParse(digitsOnly) ?? 0);
    }
    return 0;
  }

  String _resolveHeadsUpTitle(Map<String, dynamic> data) {
    final String type = (data['type'] ?? '').toString().trim().toLowerCase();
    final String rawTitle = (data['title'] ?? '').toString().trim();
    final String fallback = rawTitle.isNotEmpty
        ? rawTitle
        : (type == 'uu_dai'
              ? _t('Ưu đãi mới', 'New offer')
              : (type == 'new_service'
                    ? AppText.text(context, 'notify_new_service_title')
                    : _t('Thông báo mới', 'New notification')));

    String titleKey = (data['titleKey'] ?? '').toString().trim();
    if (titleKey.isEmpty) {
      return fallback;
    }

    Map<String, String> params = _readNotificationParams(data['titleParams']);
    if (params.isEmpty) {
      params = _readNotificationParams(data['params']);
    }

    final String resolved = AppText.textWithParams(
      context,
      titleKey,
      params,
    ).trim();
    if (resolved.isEmpty || resolved == titleKey) {
      return fallback;
    }

    return resolved;
  }

  String _resolveHeadsUpBody(Map<String, dynamic> data) {
    final String type = (data['type'] ?? '').toString().trim().toLowerCase();
    final String serviceName = (data['serviceName'] ?? data['service'] ?? '')
        .toString()
        .trim();
    final String rawBody = (data['body'] ?? '').toString().trim();
    final String fallback = rawBody.isNotEmpty
        ? rawBody
        : (type == 'uu_dai'
              ? _t('Bạn vừa nhận được ưu đãi mới.', 'You received a new offer.')
              : (type == 'new_service'
                    ? AppText.textWithParams(
                        context,
                        'notify_new_service_body',
                        <String, String>{'serviceName': serviceName},
                      )
                    : _t('Không có mô tả', 'No description')));

    String bodyKey = (data['bodyKey'] ?? '').toString().trim();
    if (bodyKey.isEmpty) {
      return fallback;
    }

    Map<String, String> params = _readNotificationParams(data['bodyParams']);
    if (params.isEmpty) {
      params = _readNotificationParams(data['params']);
    }

    if (params.isEmpty) {
      final String amount = _readNotificationAmountValue(data['amount']) > 0
          ? '${_formatCurrency(_readNotificationAmountValue(data['amount']).toDouble())} VND'
          : (data['amountText'] ?? '').toString().trim();

      final String receiverName = _firstNonEmpty(<dynamic>[
        data['receiver_name'],
        data['receiverName'],
        data['recipientName'],
      ]);
      final String serviceName = _firstNonEmpty(<dynamic>[
        data['service'],
        data['serviceName'],
      ]);

      params = <String, String>{
        if (amount.isNotEmpty) 'amount': amount,
        if (receiverName.isNotEmpty) 'name': receiverName,
        if (receiverName.isNotEmpty) 'receiverName': receiverName,
        if (serviceName.isNotEmpty) 'service': serviceName,
        if (serviceName.isNotEmpty) 'serviceName': serviceName,
      };
    }

    final String resolved = AppText.textWithParams(
      context,
      bodyKey,
      params,
    ).trim();
    if (resolved.isEmpty || resolved == bodyKey) {
      return fallback;
    }

    return resolved;
  }

  bool _shouldShowHeadsUp(Map<String, dynamic> data) {
    final String type = (data['type'] ?? '').toString().trim().toLowerCase();
    final String category = (data['category'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return type == 'uu_dai' ||
        type == 'promotion' ||
        type == 'shopping_discount' ||
        type == 'new_service' ||
        type == 'transfer' ||
        type == 'withdraw' ||
        type == 'shopping' ||
        category == 'promotion';
  }

  Map<String, dynamic>? _buildHeadsUpPayload(Map<String, dynamic> data) {
    final String type = (data['type'] ?? '').toString().trim().toLowerCase();
    if (type == 'new_service') {
      final String serviceId =
          (data['service_id'] ??
                  data['serviceId'] ??
                  data['targetServiceId'] ??
                  '')
              .toString()
              .trim();
      if (serviceId.isEmpty) {
        return null;
      }

      return <String, dynamic>{
        'type': 'new_service',
        'service_id': serviceId,
        'targetServiceId': serviceId,
      };
    }

    return null;
  }

  bool _resolveTransferIsNegative(Map<String, dynamic> data, String uid) {
    bool? toBool(dynamic raw) {
      if (raw is bool) {
        return raw;
      }
      if (raw is num) {
        return raw != 0;
      }
      if (raw is String) {
        final String normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' || normalized == '0' || normalized == 'no') {
          return false;
        }
      }
      return null;
    }

    final dynamic rawIsNegative = data['isNegative'];
    final bool? parsedIsNegative = toBool(rawIsNegative);
    if (parsedIsNegative != null) {
      return parsedIsNegative;
    }

    final dynamic rawIsIncoming = data['isIncoming'];
    final bool? parsedIsIncoming = toBool(rawIsIncoming);
    if (parsedIsIncoming != null) {
      return !parsedIsIncoming;
    }

    final String direction = _firstNonEmpty([
      data['direction'],
      data['transactionType'],
      data['transferType'],
      data['type'],
    ]).toLowerCase();
    if (direction == 'in' ||
        direction == 'incoming' ||
        direction == 'receive' ||
        direction == 'received' ||
        direction == 'credit') {
      return false;
    }
    if (direction == 'out' ||
        direction == 'outgoing' ||
        direction == 'send' ||
        direction == 'sent' ||
        direction == 'debit') {
      return true;
    }

    final String senderUid = _firstNonEmpty([
      data['senderId'],
      data['senderUid'],
      data['fromId'],
      data['fromUid'],
      data['fromUserId'],
      data['ownerUid'],
      data['userId'],
      data['uid'],
    ]);
    if (senderUid.isNotEmpty) {
      return senderUid == uid;
    }

    final String receiverUid = _firstNonEmpty([
      data['receiverId'],
      data['receiverUid'],
      data['toId'],
      data['toUid'],
      data['toUserId'],
    ]);
    if (receiverUid.isNotEmpty) {
      return receiverUid != uid;
    }

    return true;
  }

  double _parseFirestoreAmount(dynamic rawAmount) {
    if (rawAmount == null) {
      return 0;
    }

    // Required primary parsing path for mixed Firestore types.
    final double direct = double.tryParse(rawAmount.toString()) ?? 0.0;
    if (direct != 0) {
      return direct.abs();
    }

    final String digitsOnly = rawAmount.toString().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (digitsOnly.isEmpty) {
      return 0;
    }

    return double.tryParse(digitsOnly) ?? 0.0;
  }

  double _readUserBalanceField(dynamic rawValue) {
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    if (rawValue is String) {
      final String trimmed = rawValue.trim();
      if (trimmed.isEmpty) {
        return 0;
      }

      final double? direct = double.tryParse(trimmed);
      if (direct != null) {
        return direct;
      }

      final String digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.isEmpty) {
        return 0;
      }
      return double.tryParse(digitsOnly) ?? 0;
    }
    return 0;
  }

  double _extractFirstAmount(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      if (!data.containsKey(key) || data[key] == null) {
        continue;
      }

      final double parsed = _parseFirestoreAmount(data[key]);
      if (parsed > 0) {
        return parsed;
      }
    }
    return 0;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeCollectionDocs(
    DocumentReference<Map<String, dynamic>> userRef,
    String collectionName,
  ) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await userRef
          .collection(collectionName)
          .get();
      return snapshot.docs;
    } catch (_) {
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }
  }

  Future<Map<String, double>> fetchSpendingData() async {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      // ignore: avoid_print
      print('--- DEBUG TỔNG CHI TIÊU ---');
      // ignore: avoid_print
      print('Tổng Chuyển khoản: 0.0');
      // ignore: avoid_print
      print('Tổng Nạp ĐT: 0.0');
      // ignore: avoid_print
      print('Tổng Hóa đơn: 0.0');
      // ignore: avoid_print
      print('Tổng Mua sắm: 0.0');
      return <String, double>{
        'transfer': 0,
        'bill': 0,
        'phone': 0,
        'shopping': 0,
      };
    }

    final DocumentReference<Map<String, dynamic>> userRef = FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid);

    final List<List<QueryDocumentSnapshot<Map<String, dynamic>>>> collections =
        await Future.wait<List<QueryDocumentSnapshot<Map<String, dynamic>>>>([
          _safeCollectionDocs(userRef, 'transfer'),
          _safeCollectionDocs(userRef, 'bill_payment'),
          _safeCollectionDocs(userRef, 'phone_recharge'),
          _safeCollectionDocs(userRef, 'recent_transfers'),
          _safeCollectionDocs(userRef, 'Shopping'),
        ]);

    double transferTotal = 0;
    double billTotal = 0;
    double phoneTotal = 0;
    double shoppingTotal = 0;

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> transferDocs =
        collections[0].isNotEmpty ? collections[0] : collections[3];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in transferDocs) {
      final Map<String, dynamic> data = doc.data();
      final double amount = _extractFirstAmount(data, <String>[
        'amount',
        'transferAmount',
        'amountVnd',
        'amountText',
      ]);
      final bool isExpense = _resolveTransferIsNegative(data, uid);

      if (isExpense && amount > 0) {
        transferTotal += amount;
      }
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in collections[1]) {
      final Map<String, dynamic> data = doc.data();
      final double amount = _extractFirstAmount(data, <String>[
        'amount',
        'amountVnd',
        'totalAmount',
        'amountText',
      ]);
      final dynamic rawIsNegative = data['isNegative'];
      final bool isExpense = rawIsNegative is bool
          ? rawIsNegative
          : _resolveTransferIsNegative(data, uid);

      if (isExpense && amount > 0) {
        billTotal += amount;
      }
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in collections[2]) {
      final Map<String, dynamic> data = doc.data();
      final double amount = _extractFirstAmount(data, <String>[
        'amount',
        'amountVnd',
        'totalAmount',
        'amountText',
      ]);
      final dynamic rawIsNegative = data['isNegative'];
      final bool isExpense = rawIsNegative is bool
          ? rawIsNegative
          : _resolveTransferIsNegative(data, uid);

      if (isExpense && amount > 0) {
        phoneTotal += amount;
      }
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in collections[4]) {
      final Map<String, dynamic> data = doc.data();
      final double amount = _extractFirstAmount(data, <String>[
        'amount',
        'amountVnd',
        'totalAmount',
        'amountText',
      ]);
      final dynamic rawIsNegative = data['isNegative'];
      final bool isExpense = rawIsNegative is bool
          ? rawIsNegative
          : _resolveTransferIsNegative(data, uid);

      if (isExpense && amount > 0) {
        shoppingTotal += amount;
      }
    }

    // ignore: avoid_print
    print('--- DEBUG TỔNG CHI TIÊU ---');
    // ignore: avoid_print
    print('Tổng Chuyển khoản: $transferTotal');
    // ignore: avoid_print
    print('Tổng Nạp ĐT: $phoneTotal');
    // ignore: avoid_print
    print('Tổng Hóa đơn: $billTotal');
    // ignore: avoid_print
    print('Tổng Mua sắm: $shoppingTotal');

    return <String, double>{
      'transfer': transferTotal,
      'bill': billTotal,
      'phone': phoneTotal,
      'shopping': shoppingTotal,
    };
  }

  Future<Map<String, double>> _spendingDataFuture(String uid) {
    if (_spendingDataUid != uid || _spendingDataFutureCache == null) {
      _spendingDataUid = uid;
      _spendingDataFutureCache = fetchSpendingData();
    }
    return _spendingDataFutureCache!;
  }

  Future<List<_HomeTransactionModel>> fetchRecentTransactions() async {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      return <_HomeTransactionModel>[];
    }

    final DocumentReference<Map<String, dynamic>> userRef = FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid);

    const List<_HomeTransactionSource> sources = <_HomeTransactionSource>[
      _HomeTransactionSource(
        collectionName: 'transfer',
        activityType: 'transfer',
      ),
      _HomeTransactionSource(
        collectionName: 'transfers',
        activityType: 'transfer',
      ),
      _HomeTransactionSource(
        collectionName: 'recent_transfers',
        activityType: 'transfer',
      ),
      _HomeTransactionSource(
        collectionName: 'withdraw',
        activityType: 'withdraw',
      ),
      _HomeTransactionSource(
        collectionName: 'withdrawals',
        activityType: 'withdraw',
      ),
      _HomeTransactionSource(
        collectionName: 'phone_recharge',
        activityType: 'phone_recharge',
      ),
      _HomeTransactionSource(
        collectionName: 'phone_recharges',
        activityType: 'phone_recharge',
      ),
      _HomeTransactionSource(
        collectionName: 'Shopping',
        activityType: 'shopping',
      ),
      _HomeTransactionSource(
        collectionName: 'shopping',
        activityType: 'shopping',
      ),
    ];

    final List<List<QueryDocumentSnapshot<Map<String, dynamic>>>> snapshots =
        await Future.wait<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          sources
              .map(
                (_HomeTransactionSource source) =>
                    _safeCollectionDocs(userRef, source.collectionName),
              )
              .toList(growable: false),
        );

    final List<Map<String, dynamic>> mergedDocs = <Map<String, dynamic>>[];
    for (int index = 0; index < sources.length; index++) {
      final _HomeTransactionSource source = sources[index];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshots[index]) {
        mergedDocs.add(<String, dynamic>{
          'id': doc.id,
          'activityType': source.activityType,
          'sourceCollection': source.collectionName,
          'data': doc.data(),
        });
      }
    }

    mergedDocs.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final Map<String, dynamic> dataA =
          (a['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final Map<String, dynamic> dataB =
          (b['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      final DateTime timestampA = _readTimestamp(
        dataA['createdAt'] ?? dataA['timestamp'] ?? dataA['updatedAt'],
      );
      final DateTime timestampB = _readTimestamp(
        dataB['createdAt'] ?? dataB['timestamp'] ?? dataB['updatedAt'],
      );

      return timestampB.compareTo(timestampA);
    });

    final List<_HomeTransactionModel> transactions = <_HomeTransactionModel>[];

    for (final Map<String, dynamic> merged in mergedDocs.take(10)) {
      final String id = (merged['id'] ?? '').toString();
      final String activityType = (merged['activityType'] ?? '').toString();
      final Map<String, dynamic> data =
          (merged['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      final DateTime timestamp = _readTimestamp(
        data['createdAt'] ?? data['timestamp'] ?? data['updatedAt'],
      );

      String title = '';
      String subtitle = '';
      double amount = 0;

      switch (activityType) {
        case 'phone_recharge':
          final String provider = _firstNonEmpty([
            data['provider'],
            data['network'],
            data['carrier'],
            data['telco'],
          ]);
          final String phoneNumber = _firstNonEmpty([
            data['phoneNumber'],
            data['phone'],
            data['targetPhone'],
            data['targetAccount'],
          ]);

          title = provider.isEmpty
              ? _t('Nạp ĐT', 'Top-up')
              : '${_t('Nạp ĐT', 'Top-up')} $provider';
          subtitle = phoneNumber.isEmpty
              ? _t('SĐT không xác định', 'Unknown phone number')
              : '${_t('SĐT', 'Phone')}: $phoneNumber';
          amount = _extractFirstAmount(data, <String>[
            'amount',
            'amountVnd',
            'totalAmount',
            'amountText',
          ]);
          break;

        case 'withdraw':
          final String withdrawCode = _firstNonEmpty([
            data['withdrawCode'],
            data['code'],
            data['transactionCode'],
          ]);

          title = _t('Rút tiền mặt', 'Cash withdrawal');
          subtitle = withdrawCode.isEmpty
              ? _t('Rút tiền ATM', 'ATM withdrawal')
              : '${_t('Mã GD', 'Txn code')}: $withdrawCode';
          amount = _extractFirstAmount(data, <String>[
            'amount',
            'amountVnd',
            'totalAmount',
            'amountText',
          ]);
          break;

        case 'shopping':
          final String serviceName = _firstNonEmpty([
            data['serviceName'],
            data['title'],
            data['packageName'],
            data['provider'],
          ]);
          final String targetAccount = _firstNonEmpty([
            data['targetAccount'],
            data['toCardNumber'],
            data['card_number'],
            data['cardNumber'],
            data['accountNumber'],
            data['customerCode'],
            data['playerId'],
            data['phoneNumber'],
          ]);

          title = serviceName.isEmpty
              ? _t('Thanh toán dịch vụ', 'Service payment')
              : '${_t('Thanh toán', 'Payment')} $serviceName';
          subtitle = targetAccount.isEmpty
              ? _t('TK đích không xác định', 'Unknown destination account')
              : '${_t('TK đích', 'To')}: $targetAccount';
          amount = _extractFirstAmount(data, <String>[
            'amount',
            'amountVnd',
            'totalAmount',
            'amountText',
          ]);
          break;

        case 'transfer':
        default:
          final String recipientName = _firstNonEmpty([
            data['accountName'],
            data['recipientName'],
            data['receiverName'],
          ]);
          final String destinationAccount = _firstNonEmpty([
            data['toCardNumber'],
            data['card_number'],
            data['cardNumber'],
            data['toAccountNumber'],
            data['accountNumber'],
            data['receiverAccount'],
            data['targetAccount'],
          ]);

          title = recipientName.isEmpty
              ? _t('Chuyển khoản', 'Transfer')
              : '${_t('Chuyển khoản đến', 'Transfer to')} $recipientName';
          subtitle = destinationAccount.isEmpty
              ? _t('TK đích không xác định', 'Unknown destination account')
              : '${_t('TK đích', 'To')}: $destinationAccount';
          amount = _extractFirstAmount(data, <String>[
            'amount',
            'transferAmount',
            'amountVnd',
            'amountText',
          ]);
          break;
      }

      if (amount <= 0) {
        continue;
      }

      transactions.add(
        _HomeTransactionModel(
          id: id,
          title: title,
          subtitle: subtitle,
          amount: amount,
          timestamp: timestamp,
          type: activityType,
          isNegative: true,
          data: <String, dynamic>{
            ...data,
            'id': id,
            'title': title,
            'subtitle': subtitle,
            'amount': amount,
            'timestamp': timestamp,
            'type': activityType,
            'isNegative': true,
          },
        ),
      );
    }

    return transactions.take(5).toList(growable: false);
  }

  Future<List<_HomeTransactionModel>> _recentTransactionsFuture(String uid) {
    final String languageCode = Localizations.localeOf(context).languageCode;

    if (_recentTransactionsUid != uid ||
        _recentTransactionsLanguageCode != languageCode ||
        _recentTransactionsFutureCache == null) {
      _recentTransactionsUid = uid;
      _recentTransactionsLanguageCode = languageCode;
      _recentTransactionsFutureCache = fetchRecentTransactions();
    }
    return _recentTransactionsFutureCache!;
  }

  IconData _iconForTransactionType(String type) {
    switch (type) {
      case 'withdraw':
        return Icons.atm_rounded;
      case 'transfer':
        return Icons.swap_horiz_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'phone_recharge':
      default:
        return Icons.phone_android_rounded;
    }
  }

  Widget _buildNotificationBell() {
    final String uid = _resolveUid();

    if (uid.isEmpty) {
      return _buildNotificationBellWithCount(0);
    }

    return StreamBuilder<int>(
      stream: NotificationFirestoreService.instance.unreadCountStream(uid),
      builder: (context, snapshot) {
        final int unreadCount = snapshot.data ?? 0;
        return _buildNotificationBellWithCount(unreadCount);
      },
    );
  }

  Widget _buildNotificationBellWithCount(int unreadCount) {
    final String badgeText = unreadCount > 99 ? '99+' : '$unreadCount';

    return PressableScale(
      onTap: () async {
        final String uid = _resolveUid();
        if (uid.isNotEmpty) {
          await NotificationFirestoreService.instance.markAllAsRead(uid);
        }
        if (!mounted) {
          return;
        }
        _pushPremium(const NotificationScreen());
      },
      borderRadius: BorderRadius.circular(30),
      splashColor: Colors.white24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, color: Colors.white, size: 32),
          if (unreadCount > 0)
            Positioned(
              right: -4,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderUserName() {
    return ValueListenableBuilder<HomeCacheData>(
      valueListenable: HomeCacheService.instance.notifier,
      builder: (context, cacheData, _) {
        if (!cacheData.isReady && cacheData.userName.trim().isEmpty) {
          return Align(
            alignment: Alignment.centerLeft,
            child: _buildNameSkeleton(),
          );
        }

        final String name = cacheData.userName.trim().isEmpty
            ? _t('Khách hàng', 'Customer')
            : cacheData.userName;

        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            name.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.fade,
            softWrap: true,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.05,
            ),
          ),
        );
      },
    );
  }

  Widget _buildNameSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: 156,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  final List<String> _defaultBannerImages = <String>[
    'assets/images/banner1.jpg',
    'assets/images/banner2.jpg',
    'assets/images/banner3.jpg',
    'assets/images/banner4.jpg',
  ];

  Stream<List<_HomeBannerItem>> _homeBannersStream() {
    return FirebaseFirestore.instance
        .collection('admin')
        .doc('settings')
        .collection('home_banners')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<_HomeBannerItem> banners =
              snapshot.docs
                  .map(
                    (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                        _HomeBannerItem.fromMap(id: doc.id, data: doc.data()),
                  )
                  .toList(growable: false)
                ..sort(
                  (_HomeBannerItem a, _HomeBannerItem b) =>
                      a.order.compareTo(b.order),
                );

          return banners;
        });
  }

  int _readDiscountPercent(dynamic raw) {
    if (raw is num) {
      return raw.round();
    }
    if (raw is String) {
      return int.tryParse(raw.trim()) ?? 0;
    }
    return 0;
  }

  bool _hasVoucherValue(dynamic raw) {
    if (raw == null) {
      return false;
    }
    if (raw is bool) {
      return raw;
    }
    if (raw is String) {
      return raw.trim().isNotEmpty;
    }
    if (raw is Iterable) {
      for (final dynamic item in raw) {
        if (_hasVoucherValue(item)) {
          return true;
        }
      }
      return false;
    }
    if (raw is Map) {
      for (final dynamic value in raw.values) {
        if (_hasVoucherValue(value)) {
          return true;
        }
      }
      return false;
    }
    return false;
  }

  bool _serviceHasPromotion(Map<String, dynamic> data) {
    if (_readDiscountPercent(data['discountPercent']) > 0) {
      return true;
    }

    final List<dynamic> packages =
        (data['packages'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic item in packages) {
      if (item is Map<String, dynamic>) {
        if (_readDiscountPercent(item['discountPercent']) > 0) {
          return true;
        }
      } else if (item is Map) {
        if (_readDiscountPercent(item['discountPercent']) > 0) {
          return true;
        }
      }
    }

    return _hasVoucherValue(data['voucher']) ||
        _hasVoucherValue(data['voucherCode']) ||
        _hasVoucherValue(data['voucherCodes']) ||
        _hasVoucherValue(data['vouchers']) ||
        _hasVoucherValue(data['coupon']) ||
        _hasVoucherValue(data['couponCode']) ||
        _hasVoucherValue(data['couponCodes']);
  }

  Stream<Map<String, bool>> _shoppingPromotionPreviewStream() {
    return FirebaseFirestore.instance
        .collection('admin')
        .doc('settings')
        .collection('services_pricing')
        .where('kind', isEqualTo: 'shopping_bundle')
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final Map<String, bool> promotions = <String, bool>{};

          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snapshot.docs) {
            final Map<String, dynamic> data = doc.data();
            promotions[doc.id] = _serviceHasPromotion(data);
          }

          return promotions;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF000DC0,
      ), // Nền xanh để mép header không hở trắng
      body: widget.showBottomNav
          ? Stack(children: [_buildSlivers(), _buildPillBottomNav()])
          : _buildSlivers(),
    );
  }

  Widget _buildSlivers() {
    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return <Widget>[
          SliverAppBar(
            pinned: true,
            // SỬA CHÍNH: Tạo Header Xanh Bo Tròn Mượt Mà
            backgroundColor: const Color(0xFF000DC0), // Xanh đậm CCP
            elevation: 0,
            expandedHeight: 120, // Tăng nhẹ chiều cao
            collapsedHeight: 120,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ), // Bo mượt phần đuôi header
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 45),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _t("Xin chào,", "Hello,"),
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          _buildHeaderUserName(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildNotificationBell(),
                  ],
                ),
              ),
            ),
          ),
        ];
      },
      // --- PHẦN BODY BÊN DƯỚI ---
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 42, color: const Color(0xFF000DC0)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                clipBehavior: Clip.none,
                child: Column(
                  children: [
                    _buildBalanceCardSection(),
                    const SizedBox(height: 8),
                    _buildActionGrid(),
                    _buildBannerCarouselRealtime(),
                    _buildSpendingChart(),
                    const SizedBox(height: 20),
                    _buildShoppingSection(),
                    _buildTransactionHistory(),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCardSection() {
    return ValueListenableBuilder<HomeCacheData>(
      valueListenable: HomeCacheService.instance.notifier,
      builder: (context, cacheData, _) {
        final bool shouldShowSkeleton =
            !cacheData.isReady && !_hasLoadedBalance;

        if (shouldShowSkeleton) {
          return _buildBalanceCardSkeleton();
        }

        return _buildBalanceCard();
      },
    );
  }

  Widget _buildBalanceCardSkeleton() {
    return Transform.translate(
      offset: const Offset(0, 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 188,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 140,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SỬA CHÍNH: THẺ SỐ DƯ NỔI LÊN, BO GÓC CHUẨN XỊN ---
  Widget _buildBalanceCard() {
    return Transform.translate(
      offset: const Offset(
        0,
        16,
      ), // Giữ vị trí thẻ cân hơn với viền trắng bo góc
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Container(
          height: 140,
          // Chỉnh gradient và bo góc cho xịn
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3122AB),
                Color(0xFF050C9C),
              ], // Gradient xanh chuyên nghiệp
            ),
            borderRadius: BorderRadius.circular(20), // Bo góc chuẩn 20
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ), // Viền trắng mảnh, dịu hơn
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ), // Bóng đổ sâu
              BoxShadow(
                color: const Color(0xFF000B7A).withOpacity(0.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF4BD4FF).withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 2),
              ), // Ánh xanh nhẹ thò ra
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.all(0.6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19.4),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                          width: 0.7,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.09),
                            Colors.transparent,
                            Colors.cyanAccent.withOpacity(0.04),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Thêm xíu họa tiết vòng tròn chìm cho thẻ nó sang
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -42,
                  top: -74,
                  child: Container(
                    width: 164,
                    height: 164,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.09),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -92,
                  bottom: -112,
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.cyanAccent.withOpacity(0.03),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _t(
                              'Tổng số dư khả dụng',
                              'Total available balance',
                            ),
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(
                              () => _isBalanceVisible = !_isBalanceVisible,
                            ),
                            child: Icon(
                              _isBalanceVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildRealtimeTotalBalance(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          PressableScale(
                            onTap: () {
                              _pushPremium(
                                const NotificationScreen(initialTabIndex: 0),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            splashColor: Colors.white24,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 1,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _t(
                                      'Lịch sử giao dịch',
                                      'Transaction history',
                                    ),
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFAEEBFF),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 14,
                                    color: Color(0xFFAEEBFF),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Icon 2 vòng tròn lồng nhau
                          SizedBox(
                            width: 28,
                            height: 18,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.cyan.withOpacity(0.7),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.blue.withOpacity(0.7),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRealtimeTotalBalance() {
    final String uid = _resolveUid();
    final HomeCacheData cachedHomeData =
        HomeCacheService.instance.notifier.value;
    if (cachedHomeData.isReady) {
      _lastKnownTotalBalance = cachedHomeData.totalBalance;
      _hasLoadedBalance = true;
    }

    if (uid.isEmpty) {
      if (!_isBalanceVisible) {
        return _buildHiddenBalanceText();
      }
      return _buildBalanceText(0);
    }

    final DocumentReference<Map<String, dynamic>> userRef = FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(includeMetadataChanges: true),
      builder: (context, userSnapshot) {
        final Map<String, dynamic> userData =
            userSnapshot.data?.data() ?? <String, dynamic>{};
        final bool hasVipCard = userData['hasVipCard'] == true;
        final bool isStandardLocked = userData['is_standard_locked'] == true;
        final bool isVipLocked = userData['is_vip_locked'] == true;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: userRef
              .collection('cards')
              .snapshots(includeMetadataChanges: true),
          builder: (context, cardsSnapshot) {
            double normalBalance = 0;
            double vipBalance = 0;
            bool hasCardData = false;

            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in cardsSnapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
              final String cardId = doc.id.toLowerCase();
              final double balance = _readUserBalanceField(
                doc.data()['balance'],
              );

              if (cardId == 'standard') {
                normalBalance = balance;
                hasCardData = true;
              } else if (cardId == 'vip') {
                vipBalance = balance;
                hasCardData = true;
              }
            }

            if (cardsSnapshot.connectionState == ConnectionState.waiting &&
                !_hasLoadedBalance) {
              if (!_isBalanceVisible) {
                return _buildHiddenBalanceText();
              }

              if (_lastKnownTotalBalance > 0) {
                return _buildBalanceText(_lastKnownTotalBalance);
              }

              if (cachedHomeData.isReady) {
                return _buildBalanceText(cachedHomeData.totalBalance);
              }

              return _buildBalanceSkeleton();
            }

            double resolvedTotal = 0;

            if (hasCardData) {
              resolvedTotal =
                  (isStandardLocked ? 0 : normalBalance) +
                  ((hasVipCard && !isVipLocked) ? vipBalance : 0);
            } else {
              final dynamic rawNormal =
                  userData['balance_normal'] ??
                  userData['standardBalance'] ??
                  userData['balanceNormal'];
              final dynamic rawVip =
                  userData['balance_vip'] ??
                  userData['vipBalance'] ??
                  userData['balanceVip'];

              final bool hasSplitBalance = rawNormal != null || rawVip != null;
              if (hasSplitBalance) {
                final double standardFallback = _readUserBalanceField(
                  rawNormal,
                );
                final double vipFallback = _readUserBalanceField(rawVip);
                resolvedTotal =
                    (isStandardLocked ? 0 : standardFallback) +
                    ((hasVipCard && !isVipLocked) ? vipFallback : 0);
              } else {
                resolvedTotal = _readUserBalanceField(
                  userData['availableBalance'] ??
                      userData['totalBalance'] ??
                      userData['balance'],
                );
              }
            }

            _lastKnownTotalBalance = resolvedTotal;
            _hasLoadedBalance = true;

            if (!_isBalanceVisible) {
              return _buildHiddenBalanceText();
            }

            return _buildBalanceText(_lastKnownTotalBalance);
          },
        );
      },
    );
  }

  Widget _buildBalanceText(double totalBalance) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: totalBalance),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${_formatCurrency(animatedValue)} ',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: 'VND',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHiddenBalanceText() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '*** *** ',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: 'VND',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSkeleton() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShimmerBox(width: 150, height: 28, radius: 8),
        SizedBox(width: 8),
        ShimmerBox(width: 34, height: 16, radius: 6),
      ],
    );
  }

  // --- CÁC PHẦN DƯỚI GIỮ NGUYÊN ---
  Widget _buildActionGrid() {
    final List<_ActionItemData> items = <_ActionItemData>[
      _ActionItemData(
        icon: Icons.account_balance_wallet,
        color: Colors.purple,
        title: _t('Chuyển tiền', 'Transfer'),
        onTap: () =>
            _pushPremium(const TransferMoneyScreen(), refreshOnReturn: true),
      ),
      _ActionItemData(
        icon: Icons.receipt_long,
        color: Colors.green,
        title: _t('Thanh toán\nhóa đơn', 'Bill\npayment'),
        onTap: () => _pushPremium(const BillScreen(), refreshOnReturn: true),
      ),
      _ActionItemData(
        icon: Icons.atm,
        color: Colors.blue,
        title: _t('Rút tiền', 'Withdraw'),
        onTap: () =>
            _pushPremium(const WithdrawATMPage(), refreshOnReturn: true),
      ),
      _ActionItemData(
        icon: Icons.qr_code_scanner,
        color: Colors.pink,
        title: _t('Quét QR', 'Scan QR'),
        onTap: () => _pushPremium(const QrScreen()),
      ),
      _ActionItemData(
        icon: Icons.phone_android,
        color: Colors.orange,
        title: _t('Nạp tiền\nđiện thoại', 'Phone\nTop up'),
        onTap: () =>
            _pushPremium(const PhoneRechargeScreen(), refreshOnReturn: true),
      ),
      _ActionItemData(
        icon: Icons.credit_card,
        color: Colors.deepOrange,
        title: _t('Thẻ tín dụng', 'Credit card'),
        onTap: () {
          _pushPremium(const CreditCardScreen(), refreshOnReturn: true);
        },
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.25,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
        ),
        itemBuilder: (context, index) {
          final _ActionItemData item = items[index];
          return _actionItem(
            item.icon,
            item.color,
            item.title,
            onTap: item.onTap,
          );
        },
      ),
    );
  }

  Widget _actionItem(
    IconData icon,
    Color color,
    String title, {
    VoidCallback? onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: const Color(0xFF000DC0).withOpacity(0.12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF343434),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCarouselRealtime() {
    return StreamBuilder<List<_HomeBannerItem>>(
      stream: _homeBannersStream(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<_HomeBannerItem>> snapshot,
          ) {
            final List<_HomeBannerItem> banners =
                (snapshot.data != null && snapshot.data!.isNotEmpty)
                ? snapshot.data!
                : _defaultBannerImages
                      .asMap()
                      .entries
                      .map(
                        (MapEntry<int, String> entry) => _HomeBannerItem(
                          id: 'default_${entry.key}',
                          imageUrl: entry.value,
                          order: entry.key,
                        ),
                      )
                      .toList(growable: false);

            if (_currentBannerIndex >= banners.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _currentBannerIndex = 0;
                });
              });
            }

            return _buildBannerCarousel(banners);
          },
    );
  }

  Widget _buildBannerImage(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[300],
          child: Center(
            child: Text(
              AppTranslations.getText(context, 'banner_fallback_label'),
            ),
          ),
        ),
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[300],
        child: Center(
          child: Text(
            AppTranslations.getText(context, 'banner_fallback_label'),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerCarousel(List<_HomeBannerItem> bannerItems) {
    if (bannerItems.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
      child: Column(
        children: [
          Align(
            alignment: Alignment.center,
            child: FractionallySizedBox(
              widthFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.75),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: const Color(0xFF1E34D8).withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CarouselSlider(
                    options: CarouselOptions(
                      height: 146,
                      viewportFraction: 0.86,
                      padEnds: true,
                      autoPlay: true,
                      autoPlayInterval: const Duration(seconds: 3),
                      autoPlayAnimationDuration: const Duration(
                        milliseconds: 850,
                      ),
                      autoPlayCurve: Curves.easeInOutCubic,
                      enlargeCenterPage: true,
                      enlargeFactor: 0.16,
                      onPageChanged: (index, reason) {
                        if (_currentBannerIndex != index) {
                          setState(() {
                            _currentBannerIndex = index;
                          });
                        }
                      },
                    ),
                    items: bannerItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final _HomeBannerItem banner = entry.value;
                      final isActive = _currentBannerIndex == index;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isActive ? 0.12 : 0.05,
                              ),
                              blurRadius: isActive ? 10 : 6,
                              offset: Offset(0, isActive ? 5 : 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildBannerImage(banner.imageUrl),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withOpacity(
                                          isActive ? 0.1 : 0.06,
                                        ),
                                        Colors.transparent,
                                        Colors.black.withOpacity(
                                          isActive ? 0.1 : 0.06,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(bannerItems.length, (index) {
              final isActive = _currentBannerIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: isActive ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isActive
                      ? const Color(0xFF000DC0)
                      : Colors.grey.withOpacity(0.45),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingSection() {
    return StreamBuilder<Map<String, bool>>(
      stream: _shoppingPromotionPreviewStream(),
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, bool>> snapshot) {
            final Map<String, bool> promotionPreview =
                snapshot.data ?? <String, bool>{};

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PressableScale(
                    onTap: () => _pushPremium(const ShoppingStoreScreen()),
                    borderRadius: BorderRadius.circular(10),
                    splashColor: const Color(0xFF000DC0).withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _t(
                              "Mua sắm - Giải trí",
                              "Shopping - Entertainment",
                            ),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Color(0xFF000DC0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final int crossAxisCount = constraints.maxWidth >= 420
                              ? 5
                              : 4;

                          return GridView.builder(
                            itemCount: shoppingServices.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.80,
                                ),
                            itemBuilder: (BuildContext context, int index) {
                              final ServiceModel service =
                                  shoppingServices[index];
                              return _buildShoppingPreviewItem(
                                service,
                                hasPromotion:
                                    promotionPreview[service.id] ?? false,
                              );
                            },
                          );
                        },
                  ),
                ],
              ),
            );
          },
    );
  }

  Widget _buildShoppingPreviewItem(
    ServiceModel service, {
    required bool hasPromotion,
  }) {
    final String languageCode = Localizations.localeOf(context).languageCode;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showShoppingTeaserSheet(service),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                service.logoPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFF2F4F7),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      size: 20,
                      color: Color(0xFF98A2B3),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            service.localizedName(languageCode),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF475467),
              height: 1.2,
            ),
          ),
          if (hasPromotion) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              _t('Đang giảm giá', 'On sale'),
              textAlign: TextAlign.center,
              maxLines: 2,
              softWrap: true,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF16A34A),
                height: 1.15,
              ),
            ),
          ] else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  void _showShoppingTeaserSheet(ServiceModel service) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFC7CEDF),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    service.logoPath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFF2F4F7),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          size: 24,
                          color: Color(0xFF98A2B3),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                service.localizedName(
                  Localizations.localeOf(sheetContext).languageCode,
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF101828),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                service.localizedDescription(
                  Localizations.localeOf(sheetContext).languageCode,
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF667085),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000DC0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ShoppingStoreScreen(),
                      ),
                    );
                  },
                  child: Text(
                    _t('Tiếp tục →', 'Continue →'),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpendingChart() {
    const Color darkBlue = Color(0xFF000A95);
    const Color lightBlue = Color(0xFF42A5F5);
    const Color silverGrey = Color(0xFFCBD5E1);
    const Color shoppingPurple = Color(0xFF9C27B0);
    const Color emptyGrey = Color(0xFFE5E7EB);
    const Color textPrimary = Color(0xFF1F2937);
    const List<Color> transferGradient = <Color>[
      Color(0xFF00065E),
      Color(0xFF000EA8),
    ];
    const List<Color> billGradient = <Color>[
      Color(0xFFB7E3FF),
      Color(0xFF4AA9FF),
    ];
    const List<Color> phoneGradient = <Color>[
      Color(0xFFF5F7FA),
      Color(0xFFD7DEE8),
    ];
    const List<Color> shoppingGradient = <Color>[
      Color(0xFFD9A4FF),
      Color(0xFF8A2BE2),
    ];
    const List<Color> emptyGradient = <Color>[
      Color(0xFFF2F4F7),
      Color(0xFFE5E7EB),
    ];
    const double normalRadius = 74;
    const double touchedRadius = 84;
    const double centerSpaceRadius = 54;
    final String uid = _resolveUid();
    final Future<Map<String, double>> spendingFuture = uid.isEmpty
        ? Future<Map<String, double>>.value(<String, double>{
            'transfer': 0,
            'bill': 0,
            'phone': 0,
            'shopping': 0,
          })
        : _spendingDataFuture(uid);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: FutureBuilder<Map<String, double>>(
        future: spendingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final Map<String, double> data =
              snapshot.data ??
              <String, double>{
                'transfer': 0,
                'bill': 0,
                'phone': 0,
                'shopping': 0,
              };

          final double transferValue = (data['transfer'] ?? 0).toDouble();
          final double billValue = (data['bill'] ?? 0).toDouble();
          final double phoneValue = (data['phone'] ?? 0).toDouble();
          final double shoppingValue = (data['shopping'] ?? 0).toDouble();

          final List<_SpendingSlice> displaySlices = <_SpendingSlice>[
            _SpendingSlice(
              labelVi: 'Chuyển khoản',
              labelEn: 'Transfer',
              value: transferValue,
              color: darkBlue,
              gradientColors: transferGradient,
            ),
            _SpendingSlice(
              labelVi: 'Thanh toán hóa đơn',
              labelEn: 'Bill payment',
              value: billValue,
              color: lightBlue,
              gradientColors: billGradient,
            ),
            _SpendingSlice(
              labelVi: 'Nạp ĐT',
              labelEn: 'Top up',
              value: phoneValue,
              color: silverGrey,
              gradientColors: phoneGradient,
            ),
            _SpendingSlice(
              labelVi: 'Mua sắm - Giải trí',
              labelEn: 'Shopping & Entertainment',
              value: shoppingValue,
              color: shoppingPurple,
              gradientColors: shoppingGradient,
            ),
          ];

          final double totalSpending =
              transferValue + billValue + phoneValue + shoppingValue;

          final NumberFormat currencyFormatter = NumberFormat.currency(
            locale: 'vi',
            symbol: 'VND',
          );

          final bool hasSpending = totalSpending > 0;
          final int activeIndex =
              hasSpending &&
                  touchedIndex >= 0 &&
                  touchedIndex < displaySlices.length
              ? touchedIndex
              : -1;

          final String centerLabel = activeIndex == -1
              ? _t('Tổng chi tiêu', 'Total spending')
              : _t(
                  displaySlices[activeIndex].labelVi,
                  displaySlices[activeIndex].labelEn,
                );

          final double centerAmount = activeIndex == -1
              ? totalSpending
              : displaySlices[activeIndex].value;

          final Color centerAmountColor = activeIndex == -1
              ? darkBlue
              : displaySlices[activeIndex].color;

          final List<_SpendingSlice> pieSlices = totalSpending == 0
              ? const <_SpendingSlice>[
                  _SpendingSlice(
                    labelVi: 'Không có chi tiêu',
                    labelEn: 'No spending',
                    value: 1,
                    color: emptyGrey,
                    gradientColors: emptyGradient,
                  ),
                ]
              : displaySlices;

          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.68)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.48),
                      blurRadius: 12,
                      offset: const Offset(-2, -2),
                    ),
                  ],
                ),
                child: DefaultTextStyle.merge(
                  style: GoogleFonts.poppins(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _t('Thống kê tiêu dùng', 'Spending statistics'),
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 230,
                        height: 230,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            IgnorePointer(
                              child: Container(
                                width: 215,
                                height: 215,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0B1D3A,
                                      ).withOpacity(0.12),
                                      blurRadius: 22,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            PieChart(
                              PieChartData(
                                centerSpaceRadius: centerSpaceRadius,
                                sectionsSpace: 2,
                                startDegreeOffset: -90,
                                borderData: FlBorderData(show: false),
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (
                                        FlTouchEvent event,
                                        PieTouchResponse? pieTouchResponse,
                                      ) {
                                        if (!event
                                                .isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection ==
                                                null) {
                                          if (touchedIndex != -1) {
                                            setState(() {
                                              touchedIndex = -1;
                                            });
                                          }
                                          return;
                                        }

                                        final int nextIndex = pieTouchResponse
                                            .touchedSection!
                                            .touchedSectionIndex;
                                        if (nextIndex != touchedIndex) {
                                          setState(() {
                                            touchedIndex = nextIndex;
                                          });
                                        }
                                      },
                                ),
                                sections: List<PieChartSectionData>.generate(
                                  pieSlices.length,
                                  (int index) {
                                    final bool isTouched = activeIndex == index;
                                    final _SpendingSlice slice =
                                        pieSlices[index];
                                    final List<Color> sectionGradientColors =
                                        isTouched
                                        ? slice.gradientColors
                                              .map(
                                                (Color color) => Color.lerp(
                                                  color,
                                                  Colors.black,
                                                  0.14,
                                                )!,
                                              )
                                              .toList()
                                        : slice.gradientColors;

                                    return PieChartSectionData(
                                      value: slice.value,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: sectionGradientColors,
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.26),
                                        width: 1.2,
                                      ),
                                      title: '',
                                      showTitle: false,
                                      radius: isTouched
                                          ? touchedRadius
                                          : normalRadius,
                                    );
                                  },
                                ),
                              ),
                              swapAnimationDuration: const Duration(
                                milliseconds: 500,
                              ),
                              swapAnimationCurve: Curves.easeOutCubic,
                            ),
                            ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  width: centerSpaceRadius * 2,
                                  height: centerSpaceRadius * 2,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.72),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(-2, -2),
                                      ),
                                      BoxShadow(
                                        color: const Color(
                                          0xFF0D1D38,
                                        ).withOpacity(0.1),
                                        blurRadius: 12,
                                        offset: const Offset(2, 5),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      IgnorePointer(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              center: const Alignment(
                                                -0.2,
                                                -0.4,
                                              ),
                                              radius: 1.1,
                                              colors: [
                                                Colors.white.withOpacity(0.36),
                                                Colors.transparent,
                                                const Color(
                                                  0xFF0F1F39,
                                                ).withOpacity(0.08),
                                              ],
                                              stops: const [0, 0.62, 1],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              centerLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                currencyFormatter.format(
                                                  centerAmount,
                                                ),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 23,
                                                  fontWeight: FontWeight.bold,
                                                  color: centerAmountColor,
                                                  height: 1,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: List<Widget>.generate(displaySlices.length, (
                          int index,
                        ) {
                          final _SpendingSlice slice = displaySlices[index];
                          final bool isActive = index == activeIndex;
                          return _buildSpendingLegendChip(
                            gradientColors: slice.gradientColors,
                            label: _t(slice.labelVi, slice.labelEn),
                            textColor: textPrimary,
                            isActive: isActive,
                            onTap: () {
                              setState(() {
                                touchedIndex = isActive ? -1 : index;
                              });
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpendingLegendChip({
    required List<Color> gradientColors,
    required String label,
    required Color textColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.82)
              : Colors.white.withOpacity(0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? gradientColors.last.withOpacity(0.75)
                : Colors.white.withOpacity(0.66),
            width: isActive ? 1.3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F1F39).withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.34),
              blurRadius: 8,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.last.withOpacity(0.45),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: textColor,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    final String uid = _resolveUid();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('Giao dịch gần đây', 'Recent transactions'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: () =>
                    _pushPremium(const NotificationScreen(initialTabIndex: 0)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF000DC0),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _t('Xem tất cả', 'View all'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF000DC0),
                  ),
                ),
              ),
            ],
          ),
          if (uid.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _t('Bạn chưa đăng nhập.', 'You are not logged in.'),
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
            )
          else
            FutureBuilder<List<_HomeTransactionModel>>(
              future: _recentTransactionsFuture(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        _transactionItemSkeleton(),
                        const SizedBox(height: 10),
                        _transactionItemSkeleton(),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _t(
                        'Không tải được lịch sử giao dịch.',
                        'Unable to load transaction history.',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  );
                }

                final List<_HomeTransactionModel> transactions =
                    snapshot.data ?? <_HomeTransactionModel>[];

                if (transactions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _t('Chưa có giao dịch nào.', 'No transactions yet.'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final _HomeTransactionModel item = transactions[index];
                    final Map<String, dynamic> transaction = item.data;
                    final String dateText = DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(item.timestamp);
                    final String subtitle = dateText;
                    final String amount = '- ${_formatCurrency(item.amount)}';

                    return InkWell(
                      onTap: () {
                        TransactionDetailPopup.show(context, transaction);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: _transactionItem(
                        _iconForTransactionType(item.type),
                        item.title,
                        subtitle,
                        amount,
                        Colors.red,
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _transactionItemSkeleton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          ShimmerBox(width: 28, height: 28, radius: 14),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 140, height: 10, radius: 5),
                SizedBox(height: 8),
                ShimmerBox(width: 90, height: 9, radius: 5),
              ],
            ),
          ),
          SizedBox(width: 10),
          ShimmerBox(width: 70, height: 10, radius: 5),
        ],
      ),
    );
  }

  Widget _transactionItem(
    IconData icon,
    String title,
    String date,
    String amount,
    Color amountColor,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF000DC0).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF000DC0)),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        date,
        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
      ),
      trailing: Text(
        "$amount VND",
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildPillBottomNav() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _pillNavItem(Icons.home, _t("Trang chính", "Home"), 0),
            _pillNavItem(Icons.search, "", 1),
            _pillNavItem(Icons.chat_bubble_outline, "", 2),
            _pillNavItem(Icons.settings_outlined, "", 3),
          ],
        ),
      ),
    );
  }

  Widget _pillNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return PressableScale(
      onTap: () {
        if (index == 0) {
          _replacePremium(const HomeScreen());
        } else if (index == 1) {
          _replacePremium(const SearchScreen());
        } else if (index == 2) {
          _replacePremium(const ChatPlaceholderScreen());
        } else if (index == 3) {
          _replacePremium(const SettingScreen());
        }
      },
      borderRadius: BorderRadius.circular(20),
      splashColor: const Color(0xFF000DC0).withOpacity(0.12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFF000DC0),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 22,
            ),
            if (isSelected && label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpendingSlice {
  const _SpendingSlice({
    required this.labelVi,
    required this.labelEn,
    required this.value,
    required this.color,
    required this.gradientColors,
  });

  final String labelVi;
  final String labelEn;
  final double value;
  final Color color;
  final List<Color> gradientColors;
}

class _HomeTransactionModel {
  const _HomeTransactionModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.timestamp,
    required this.type,
    required this.isNegative,
    required this.data,
  });

  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime timestamp;
  final String type;
  final bool isNegative;
  final Map<String, dynamic> data;
}

class _HomeTransactionSource {
  const _HomeTransactionSource({
    required this.collectionName,
    required this.activityType,
  });

  final String collectionName;
  final String activityType;
}

class _HomeBannerItem {
  const _HomeBannerItem({
    required this.id,
    required this.imageUrl,
    required this.order,
  });

  final String id;
  final String imageUrl;
  final int order;

  factory _HomeBannerItem.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return _HomeBannerItem(
      id: id,
      imageUrl: (data['imageUrl'] ?? '').toString().trim(),
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }
}

class _ActionItemData {
  const _ActionItemData({
    required this.icon,
    required this.color,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback? onTap;
}
