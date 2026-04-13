import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../app_preferences.dart';
import '../l10n/app_text.dart';
import '../screen/login.dart';
import '../services/card_number_service.dart';
import '../widget/custom_confirm_dialog.dart';

const List<String> _kTransactionCollections = <String>[
  'Shopping',
  'shopping',
  'bill_payment',
  'pay_bill',
  'paybill',
  'phone_recharge',
  'recent_tranfer',
  'recent_transfer',
  'recent_transfers',
  'withdraw',
];

DateTime? parseTransactionTime(dynamic timeData) {
  if (timeData == null) {
    return null;
  }

  if (timeData is Timestamp) {
    return timeData.toDate();
  }

  if (timeData is DateTime) {
    return timeData;
  }

  if (timeData is int) {
    final int value = timeData;
    // Accept both seconds (10-digit) and milliseconds (13-digit) epochs.
    if (value.abs() < 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (timeData is String) {
    final String raw = timeData.trim();
    if (raw.isEmpty) {
      return null;
    }

    final DateTime? iso = DateTime.tryParse(raw);
    if (iso != null) {
      return iso;
    }

    const List<String> patterns = <String>[
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm',
      'dd/MM/yyyy',
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy HH:mm',
      'dd-MM-yyyy',
      'd/M/yyyy HH:mm:ss',
      'd/M/yyyy HH:mm',
      'd/M/yyyy',
      'd-M-yyyy HH:mm:ss',
      'd-M-yyyy HH:mm',
      'd-M-yyyy',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
    ];

    for (final String pattern in patterns) {
      try {
        return DateFormat(pattern).parseStrict(raw);
      } catch (_) {
        // Try next known pattern.
      }
    }
  }

  return null;
}

DateTime? _extractTransactionTime(Map<String, dynamic> data) {
  return parseTransactionTime(data['timestamp']) ??
      parseTransactionTime(data['date']) ??
      parseTransactionTime(data['createdAt']) ??
      parseTransactionTime(data['updatedAt']) ??
      parseTransactionTime(data['time']) ??
      parseTransactionTime(data['paidAt']);
}

bool _isTimeInRange(DateTime? value, DateTimeRange range) {
  if (value == null) {
    return false;
  }
  return !value.isBefore(range.start) && value.isBefore(range.end);
}

String _transactionTypeFromCollection(String collectionName) {
  switch (collectionName) {
    case 'Shopping':
    case 'shopping':
      return 'Mua sắm';
    case 'bill_payment':
      return 'Thanh toán hóa đơn';
    case 'pay_bill':
    case 'paybill':
      return 'Chi trả hóa đơn';
    case 'phone_recharge':
      return 'Nạp điện thoại';
    case 'recent_tranfer':
    case 'recent_transfer':
    case 'recent_transfers':
      return 'Chuyển khoản';
    case 'withdraw':
      return 'Rút tiền';
    default:
      return collectionName;
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _pageBg = Color(0xFFF5F7FF);
  static const Color _sidebarStart = Color(0xFF0B1E4D);
  static const Color _sidebarEnd = Color(0xFF020617);
  static const Color _neonBlue = Color(0xFF22D3EE);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedTab = 0;
  bool _isLoggingOut = false;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _servicesPricingStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _bannersStream;
  late Stream<int> _totalTransactionsCountStream;
  final Map<String, bool> _cardLockOverrides = <String, bool>{};
  final Set<String> _pendingCardLockUpdates = <String>{};

  static const List<({IconData icon, String vi, String en, String? textKey})>
  _tabConfig = <({IconData icon, String vi, String en, String? textKey})>[
    (
      icon: Icons.dashboard_rounded,
      vi: 'Dashboard',
      en: 'Dashboard',
      textKey: null,
    ),
    (
      icon: Icons.people_alt_rounded,
      vi: 'Người dùng',
      en: 'Users',
      textKey: null,
    ),
    (
      icon: Icons.price_change_rounded,
      vi: 'Dịch vụ',
      en: 'Services',
      textKey: null,
    ),
    (
      icon: Icons.photo_library_rounded,
      vi: 'Banner',
      en: 'Banners',
      textKey: null,
    ),
    (icon: Icons.credit_card, vi: 'Thẻ', en: 'Cards', textKey: 'tab_cards'),
  ];

  @override
  void initState() {
    super.initState();
    _servicesPricingStream = FirebaseFirestore.instance
        .collection('services')
        .snapshots(includeMetadataChanges: true)
        .asBroadcastStream();

    _bootstrapServicesData();

    _bannersStream = _adminCollection('home_banners')
        .orderBy('order', descending: false)
        .snapshots(includeMetadataChanges: true)
        .asBroadcastStream();

    _totalTransactionsCountStream = _allUsersTotalTransactionsCountStream()
        .asBroadcastStream();
  }

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  void _onSettingsMenuSelected(int value) {
    switch (value) {
      case 1:
        _showLanguageBottomSheet(context);
        break;
      case 2:
        _handleLogout();
        break;
      default:
        break;
    }
  }

  Future<void> _showLanguageBottomSheet(BuildContext parentContext) async {
    await showModalBottomSheet<void>(
      context: parentContext,
      builder: (BuildContext sheetContext) {
        final String currentCode = AppPreferences.instance.locale.languageCode;

        Future<void> selectLanguage(Locale locale) async {
          await AppPreferences.instance.setLocaleAndPersist(locale);
          if (!sheetContext.mounted) {
            return;
          }
          Navigator.pop(sheetContext);
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: Text(
                  AppText.text(sheetContext, 'select_language'),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                onTap: () => selectLanguage(const Locale('vi')),
                title: Text(AppText.text(sheetContext, 'language_vietnamese')),
                trailing: currentCode == 'vi'
                    ? const Icon(Icons.check, color: _primaryBlue)
                    : null,
              ),
              ListTile(
                onTap: () => selectLanguage(const Locale('en')),
                title: Text(AppText.text(sheetContext, 'language_english')),
                trailing: currentCode == 'en'
                    ? const Icon(Icons.check, color: _primaryBlue)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    if (!mounted || _isLoggingOut) {
      return;
    }

    await showCustomConfirmDialog(
      context: context,
      title: AppText.text(context, 'confirm_logout_title'),
      message: AppText.text(context, 'confirm_logout_msg'),
      confirmText: AppText.text(context, 'menu_logout'),
      cancelText: AppText.text(context, 'btn_cancel'),
      confirmColor: Colors.red,
      onConfirm: _performAdminLogout,
    );
  }

  Future<void> _performAdminLogout() async {
    if (!mounted || _isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext _) {
        return const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.text(context, 'logout_failed'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  String _tabLabel(
    ({IconData icon, String vi, String en, String? textKey}) tab,
  ) {
    final String? textKey = tab.textKey;
    if (textKey != null && textKey.isNotEmpty) {
      return AppText.text(context, textKey);
    }
    return _t(tab.vi, tab.en);
  }

  CollectionReference<Map<String, dynamic>> _adminCollection(String path) {
    return _firestore.collection('admin').doc('settings').collection(path);
  }

  Future<void> _bootstrapServicesData() async {
    await _restoreMissingServiceDocsFromLegacy();
  }

  bool _isShoppingBundleService(Map<String, dynamic> data) {
    final String kind = (data['kind'] ?? 'shopping_bundle').toString().trim();
    return kind.isEmpty || kind == 'shopping_bundle';
  }

  Future<void> _restoreMissingServiceDocsFromLegacy() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> servicesSnapshot =
          await _firestore.collection('services').get();
      final Set<String> existingDocIds = servicesSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
          .toSet();
      final Set<String> existingLegacyIds = servicesSnapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                (doc.data()['id'] ?? '').toString().trim(),
          )
          .where((String id) => id.isNotEmpty)
          .toSet();

      final QuerySnapshot<Map<String, dynamic>> legacySnapshot =
          await _adminCollection(
            'services_pricing',
          ).where('kind', isEqualTo: 'shopping_bundle').get();

      if (legacySnapshot.docs.isEmpty) {
        return;
      }

      WriteBatch batch = _firestore.batch();
      int operationCount = 0;

      for (final QueryDocumentSnapshot<Map<String, dynamic>> legacyDoc
          in legacySnapshot.docs) {
        final Map<String, dynamic> legacy = legacyDoc.data();
        final String legacyId =
            (legacy['id'] ?? legacyDoc.id).toString().trim().isEmpty
            ? legacyDoc.id
            : (legacy['id'] ?? legacyDoc.id).toString().trim();

        if (existingDocIds.contains(legacyId) ||
            existingLegacyIds.contains(legacyId)) {
          continue;
        }

        batch.set(
          _firestore.collection('services').doc(legacyId),
          <String, dynamic>{
            ...legacy,
            'id': legacyId,
            'createdAt': legacy['createdAt'] ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        operationCount += 1;
        if (operationCount >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }
    } catch (_) {
      // Keep dashboard usable even if legacy recovery fails.
    }
  }

  String _formatVnd(int amount) {
    return '${NumberFormat.decimalPattern('vi_VN').format(amount)} VND';
  }

  String _formatCommaAmount(double amount) {
    return '${NumberFormat('#,###', 'en_US').format(amount.round())} VND';
  }

  String _formatVndDouble(double amount) {
    return _formatVnd(amount.round());
  }

  int _sanitizeDiscountPercent(dynamic raw) {
    final int parsed = int.tryParse((raw ?? 0).toString()) ?? 0;
    if (parsed < 0) {
      return 0;
    }
    if (parsed > 100) {
      return 100;
    }
    return parsed;
  }

  List<Map<String, dynamic>> _parsePackageRows(List<dynamic> raw) {
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];

    for (final dynamic item in raw) {
      if (item is Map<String, dynamic>) {
        final String title = (item['title'] ?? '').toString().trim();
        final int price = _toDouble(item['price']).round();
        final int discountPercent = _sanitizeDiscountPercent(
          item['discountPercent'],
        );
        if (price > 0) {
          result.add(<String, dynamic>{
            'title': title,
            'price': price,
            'discountPercent': discountPercent,
          });
        }
        continue;
      }

      if (item is Map) {
        final Map<String, dynamic> map = item.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
        final String title = (map['title'] ?? '').toString().trim();
        final int price = _toDouble(map['price']).round();
        final int discountPercent = _sanitizeDiscountPercent(
          map['discountPercent'],
        );
        if (price > 0) {
          result.add(<String, dynamic>{
            'title': title,
            'price': price,
            'discountPercent': discountPercent,
          });
        }
        continue;
      }

      final int price = int.tryParse(item.toString()) ?? 0;
      if (price > 0) {
        result.add(<String, dynamic>{
          'title': '',
          'price': price,
          'discountPercent': 0,
        });
      }
    }

    return result;
  }

  Future<void> _pushShoppingDiscountNotifications({
    required String serviceId,
    required String serviceName,
    required List<Map<String, dynamic>> packages,
  }) async {
    int maxDiscount = 0;
    for (final Map<String, dynamic> item in packages) {
      final int discount = _sanitizeDiscountPercent(item['discountPercent']);
      if (discount > maxDiscount) {
        maxDiscount = discount;
      }
    }

    if (maxDiscount <= 0) {
      return;
    }

    final String title = '🔥 Ưu đãi giảm đến $maxDiscount% cho $serviceName!';
    final String body = 'Bấm vào đây để xem ngay các gói đang giảm giá!';

    final QuerySnapshot<Map<String, dynamic>> usersSnapshot = await _firestore
        .collection('users')
        .get();

    if (usersSnapshot.docs.isEmpty) {
      return;
    }

    WriteBatch batch = _firestore.batch();
    int operationCount = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> userDoc
        in usersSnapshot.docs) {
      final DocumentReference<Map<String, dynamic>> notificationRef = userDoc
          .reference
          .collection('notifications')
          .doc();

      batch.set(notificationRef, <String, dynamic>{
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'uu_dai',
        'category': 'promotion',
        'isRead': false,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'discountPercent': maxDiscount,
        'deepLink': 'shopping_service_detail',
      });

      operationCount += 1;
      if (operationCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        operationCount = 0;
      }
    }

    if (operationCount > 0) {
      await batch.commit();
    }
  }

  Future<void> _pushNewServiceNotifications({
    required String serviceId,
    required String serviceName,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> usersSnapshot = await _firestore
        .collection('users')
        .get();

    if (usersSnapshot.docs.isEmpty) {
      return;
    }

    final String languageCode = AppText.systemLanguageCode();
    final String title = AppText.textByCode(
      languageCode,
      'notify_new_service_title',
    );
    final String body = AppText.textByCodeWithParams(
      languageCode,
      'notify_new_service_body',
      <String, String>{'serviceName': serviceName},
    );

    WriteBatch batch = _firestore.batch();
    int operationCount = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> userDoc
        in usersSnapshot.docs) {
      final DocumentReference<Map<String, dynamic>> notificationRef = userDoc
          .reference
          .collection('notifications')
          .doc();

      batch.set(notificationRef, <String, dynamic>{
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'new_service',
        'category': 'promotion',
        'service_id': serviceId,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'titleKey': 'notify_new_service_title',
        'bodyKey': 'notify_new_service_body',
        'params': <String, dynamic>{'serviceName': serviceName},
        'title': title,
        'body': body,
        'deepLink': 'shopping_store',
      });

      operationCount += 1;
      if (operationCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        operationCount = 0;
      }
    }

    if (operationCount > 0) {
      await batch.commit();
    }
  }

  double _toDouble(dynamic raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      final String trimmed = raw.trim();
      final double? direct = double.tryParse(trimmed);
      if (direct != null) {
        return direct;
      }
      final String digits = trimmed.replaceAll(RegExp(r'[^0-9.]'), '');
      if (digits.isEmpty) {
        return 0;
      }
      return double.tryParse(digits) ?? 0;
    }
    return 0;
  }

  String _readUserName(Map<String, dynamic> data) {
    final String fullName = (data['fullName'] ?? '').toString().trim();
    final String fullname = (data['fullname'] ?? '').toString().trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
    if (fullname.isNotEmpty) {
      return fullname;
    }
    return '-';
  }

  String _readUserAccount(Map<String, dynamic> data) {
    final String raw = CardNumberService.readCardNumber(data);
    final String formatted = CardNumberService.formatCardNumber(raw);
    if (formatted.isNotEmpty) {
      return formatted;
    }
    return '-';
  }

  String _readUserPhone(Map<String, dynamic> data) {
    final String phone = (data['phoneNumber'] ?? '').toString().trim();
    if (phone.isNotEmpty) {
      return phone;
    }
    return '-';
  }

  String _readUserCccd(Map<String, dynamic> data) {
    final String cccd = (data['cccd'] ?? data['idNumber'] ?? '')
        .toString()
        .trim();
    if (cccd.isNotEmpty) {
      return cccd;
    }
    return '-';
  }

  String _readUserAddress(Map<String, dynamic> data) {
    final String address =
        (data['address'] ??
                data['homeAddress'] ??
                data['permanentAddress'] ??
                '')
            .toString()
            .trim();
    if (address.isNotEmpty) {
      return address;
    }
    return '-';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream() {
    return _firestore
        .collection('users')
        .snapshots(includeMetadataChanges: true);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _cardsStream() {
    return _firestore
        .collectionGroup('cards')
        .snapshots(includeMetadataChanges: true);
  }

  Map<String, _UserCardBalances> _buildCardBalancesByUser(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, _UserCardBalances> result = <String, _UserCardBalances>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final DocumentReference<Map<String, dynamic>>? userRef =
          doc.reference.parent.parent;
      if (userRef == null || userRef.parent.id != 'users') {
        continue;
      }

      final String cardId = doc.id.toLowerCase();
      final _UserCardBalances current =
          result[userRef.id] ?? const _UserCardBalances();
      final double balance = _toDouble(doc.data()['balance']);

      if (cardId == 'standard') {
        result[userRef.id] = current.copyWith(balanceNormal: balance);
      } else if (cardId == 'vip') {
        result[userRef.id] = current.copyWith(balanceVip: balance);
      }
    }

    return result;
  }

  double _readUserNormalBalance(Map<String, dynamic> data) {
    return _toDouble(
      data['balance_normal'] ??
          data['standardBalance'] ??
          data['balanceNormal'] ??
          data['balance'] ??
          0,
    );
  }

  double _readUserVipBalance(Map<String, dynamic> data) {
    return _toDouble(
      data['balance_vip'] ?? data['vipBalance'] ?? data['balanceVip'] ?? 0,
    );
  }

  double _readUserTotalBalance(Map<String, dynamic> data) {
    return _readUserNormalBalance(data) + _readUserVipBalance(data);
  }

  double _parseBalanceInput(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 0;
    }

    final String digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return 0;
    }

    return double.tryParse(digitsOnly) ?? 0;
  }

  void _openUsersManagementTab() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTab = 1;
    });
  }

  DateTimeRange _rangeForFilter(
    _AdminHistoryFilterType filterType,
    DateTime selectedPoint,
  ) {
    final DateTime base = DateTime(
      selectedPoint.year,
      selectedPoint.month,
      selectedPoint.day,
    );

    switch (filterType) {
      case _AdminHistoryFilterType.day:
        return DateTimeRange(
          start: base,
          end: base.add(const Duration(days: 1)),
        );
      case _AdminHistoryFilterType.month:
        final DateTime monthStart = DateTime(base.year, base.month, 1);
        final DateTime monthEnd = DateTime(base.year, base.month + 1, 1);
        return DateTimeRange(start: monthStart, end: monthEnd);
      case _AdminHistoryFilterType.year:
        final DateTime yearStart = DateTime(base.year, 1, 1);
        final DateTime yearEnd = DateTime(base.year + 1, 1, 1);
        return DateTimeRange(start: yearStart, end: yearEnd);
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _readUserSubCollectionDocs({
    required DocumentReference<Map<String, dynamic>> userRef,
    required String subCollection,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await userRef
          .collection(subCollection)
          .get();
      return snapshot.docs;
    } catch (_) {
      return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _deepScanAllTransactions({
    _AdminHistoryFilterType? filterType,
    DateTime? selectedPoint,
  }) async {
    final DateTimeRange? range = (filterType != null && selectedPoint != null)
        ? _rangeForFilter(filterType, selectedPoint)
        : null;
    final QuerySnapshot<Map<String, dynamic>> usersSnapshot = await _firestore
        .collection('users')
        .get();

    final List<Future<List<Map<String, dynamic>>>> userTasks = usersSnapshot
        .docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> userDoc) async {
          final String userName = _readUserName(userDoc.data());
          final DocumentReference<Map<String, dynamic>> userRef =
              userDoc.reference;

          final List<Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>
          subCollectionTasks = _kTransactionCollections
              .map(
                (String subCollection) => _readUserSubCollectionDocs(
                  userRef: userRef,
                  subCollection: subCollection,
                ),
              )
              .toList(growable: false);

          final List<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
          subCollectionResults = await Future.wait(subCollectionTasks);

          final List<Map<String, dynamic>> transactionsForUser =
              <Map<String, dynamic>>[];

          for (int i = 0; i < subCollectionResults.length; i++) {
            final String subCollection = _kTransactionCollections[i];
            final String transactionType = _transactionTypeFromCollection(
              subCollection,
            );

            for (final QueryDocumentSnapshot<Map<String, dynamic>> txDoc
                in subCollectionResults[i]) {
              final Map<String, dynamic> txData = Map<String, dynamic>.from(
                txDoc.data(),
              );
              final DateTime? parsedTime = _extractTransactionTime(txData);
              if (range != null && !_isTimeInRange(parsedTime, range)) {
                continue;
              }

              txData['userId'] = userDoc.id;
              txData['userName'] = userName;
              txData['transactionType'] = transactionType;
              txData['_parsedTime'] = parsedTime;
              txData['_sourceCollection'] = subCollection;
              transactionsForUser.add(txData);
            }
          }

          return transactionsForUser;
        })
        .toList(growable: false);

    final List<List<Map<String, dynamic>>> userResults = await Future.wait(
      userTasks,
    );
    final List<Map<String, dynamic>> mergedTransactions = userResults
        .expand((List<Map<String, dynamic>> userTx) => userTx)
        .toList(growable: false);

    final Map<String, Map<String, dynamic>> dedupByKey =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> tx in mergedTransactions) {
      final String userPart = (tx['userId'] ?? tx['userName'] ?? '')
          .toString()
          .trim();
      if (userPart.isEmpty) {
        continue;
      }

      final double amount = _toDouble(tx['amount']);
      final DateTime? parsedTime = tx['_parsedTime'] as DateTime?;
      final String minutePart = parsedTime == null
          ? 'no_time'
          : '${parsedTime.year.toString().padLeft(4, '0')}-'
                '${parsedTime.month.toString().padLeft(2, '0')}-'
                '${parsedTime.day.toString().padLeft(2, '0')} '
                '${parsedTime.hour.toString().padLeft(2, '0')}:'
                '${parsedTime.minute.toString().padLeft(2, '0')}';
      final String dedupKey =
          '${userPart}_${amount.toStringAsFixed(2)}_$minutePart';

      final Map<String, dynamic>? existing = dedupByKey[dedupKey];
      if (existing == null) {
        dedupByKey[dedupKey] = tx;
        continue;
      }

      final String existingSource = (existing['_sourceCollection'] ?? '')
          .toString();
      final String currentSource = (tx['_sourceCollection'] ?? '').toString();
      final bool currentIsCanonical =
          currentSource == 'pay_bill' || currentSource == 'paybill';
      final bool existingIsCanonical =
          existingSource == 'pay_bill' || existingSource == 'paybill';
      if (currentIsCanonical && !existingIsCanonical) {
        dedupByKey[dedupKey] = tx;
      }
    }

    final List<Map<String, dynamic>> allTransactions =
        dedupByKey.values.toList(growable: false)
          ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
            final DateTime? atA = a['_parsedTime'] as DateTime?;
            final DateTime? atB = b['_parsedTime'] as DateTime?;
            if (atA == null && atB == null) {
              return 0;
            }
            if (atA == null) {
              return 1;
            }
            if (atB == null) {
              return -1;
            }
            return atB.compareTo(atA);
          });

    return allTransactions;
  }

  List<_AdminUserTransactionStat> _buildUserStatsFromTransactions(
    List<Map<String, dynamic>> allTransactions,
  ) {
    final Map<String, ({String userName, int count})> byUser =
        <String, ({String userName, int count})>{};

    for (final Map<String, dynamic> tx in allTransactions) {
      final String userId = (tx['userId'] ?? '').toString();
      if (userId.isEmpty) {
        continue;
      }
      final String userName = (tx['userName'] ?? '-').toString();
      final ({String userName, int count}) current =
          byUser[userId] ?? (userName: userName, count: 0);
      byUser[userId] = (userName: current.userName, count: current.count + 1);
    }

    final List<_AdminUserTransactionStat> stats =
        byUser.entries
            .map(
              (MapEntry<String, ({String userName, int count})> entry) =>
                  _AdminUserTransactionStat(
                    userId: entry.key,
                    userName: entry.value.userName,
                    count: entry.value.count,
                  ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final int countDiff = b.count.compareTo(a.count);
            if (countDiff != 0) {
              return countDiff;
            }
            return a.userName.compareTo(b.userName);
          });

    return stats;
  }

  Stream<List<_AdminUserTransactionStat>> _allUsersTransactionStatsStream({
    required _AdminHistoryFilterType filterType,
    required DateTime selectedPoint,
  }) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> usersTrigger = _firestore
        .collection('users')
        .snapshots(includeMetadataChanges: true);
    final List<Stream<QuerySnapshot<Map<String, dynamic>>>> sourceTriggers =
        _kTransactionCollections
            .map(
              (String source) => _firestore
                  .collectionGroup(source)
                  .snapshots(includeMetadataChanges: true),
            )
            .toList(growable: false);

    return MergeStream<Object>(<Stream<Object>>[
      usersTrigger,
      ...sourceTriggers,
    ]).startWith(const Object()).switchMap((Object _) {
      return Stream.fromFuture(
        _deepScanAllTransactions(
          filterType: filterType,
          selectedPoint: selectedPoint,
        ).then(_buildUserStatsFromTransactions),
      );
    }).asBroadcastStream();
  }

  Stream<int> _allUsersTotalTransactionsCountStream() {
    final List<Stream<QuerySnapshot<Map<String, dynamic>>>> sourceTriggers =
        _kTransactionCollections
            .map(
              (String source) => _firestore
                  .collectionGroup(source)
                  .snapshots(includeMetadataChanges: true),
            )
            .toList(growable: false);

    return CombineLatestStream.list<QuerySnapshot<Map<String, dynamic>>>(
          sourceTriggers,
        )
        .map((List<QuerySnapshot<Map<String, dynamic>>> snapshots) {
          final Map<String, String> dedupByKey = <String, String>{};

          for (int i = 0; i < snapshots.length; i++) {
            final String source = _kTransactionCollections[i];
            final QuerySnapshot<Map<String, dynamic>> snapshot = snapshots[i];

            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in snapshot.docs) {
              final DocumentReference<Map<String, dynamic>>? userRef =
                  doc.reference.parent.parent;
              if (userRef == null || userRef.parent.id != 'users') {
                continue;
              }

              final Map<String, dynamic> data = doc.data();
              final double amount = _toDouble(data['amount']);
              final DateTime? parsedTime = _extractTransactionTime(data);
              final String minutePart = parsedTime == null
                  ? 'no_time'
                  : '${parsedTime.year.toString().padLeft(4, '0')}-'
                        '${parsedTime.month.toString().padLeft(2, '0')}-'
                        '${parsedTime.day.toString().padLeft(2, '0')} '
                        '${parsedTime.hour.toString().padLeft(2, '0')}:'
                        '${parsedTime.minute.toString().padLeft(2, '0')}';

              final String dedupKey =
                  '${userRef.id}_${amount.toStringAsFixed(2)}_$minutePart';

              final String? existingSource = dedupByKey[dedupKey];
              if (existingSource == null) {
                dedupByKey[dedupKey] = source;
                continue;
              }

              final bool currentIsCanonical =
                  source == 'pay_bill' || source == 'paybill';
              final bool existingIsCanonical =
                  existingSource == 'pay_bill' || existingSource == 'paybill';
              if (currentIsCanonical && !existingIsCanonical) {
                dedupByKey[dedupKey] = source;
              }
            }
          }

          return dedupByKey.length;
        })
        .startWith(0)
        .distinct();
  }

  Future<void> _showSystemBalancesOverlay() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'system-balance-overlay',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return Material(
              type: MaterialType.transparency,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 860,
                        maxHeight: 620,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    _t(
                                      'Tổng số dư hệ thống theo người dùng',
                                      'System balances by user',
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 38,
                                  child: _gradientActionButton(
                                    label: _t('Đóng', 'Close'),
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    icon: Icons.close_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: _usersStream(),
                                builder:
                                    (
                                      BuildContext context,
                                      AsyncSnapshot<
                                        QuerySnapshot<Map<String, dynamic>>
                                      >
                                      snapshot,
                                    ) {
                                      if (snapshot.hasError) {
                                        return Center(
                                          child: Text(
                                            _t(
                                              'Không thể tải dữ liệu người dùng',
                                              'Unable to load user data',
                                            ),
                                            style: GoogleFonts.poppins(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      }

                                      if (!snapshot.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }

                                      final List<
                                        QueryDocumentSnapshot<
                                          Map<String, dynamic>
                                        >
                                      >
                                      users =
                                          snapshot.data!.docs.toList(
                                            growable: false,
                                          )..sort((a, b) {
                                            final String aName = _readUserName(
                                              a.data(),
                                            );
                                            final String bName = _readUserName(
                                              b.data(),
                                            );
                                            return aName.compareTo(bName);
                                          });

                                      if (users.isEmpty) {
                                        return Center(
                                          child: Text(
                                            _t(
                                              'Chưa có user',
                                              'No users found',
                                            ),
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        );
                                      }

                                      return StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>
                                      >(
                                        stream: _cardsStream(),
                                        builder:
                                            (
                                              BuildContext context,
                                              AsyncSnapshot<
                                                QuerySnapshot<
                                                  Map<String, dynamic>
                                                >
                                              >
                                              cardsSnapshot,
                                            ) {
                                              final Map<
                                                String,
                                                _UserCardBalances
                                              >
                                              cardBalancesByUser =
                                                  cardsSnapshot.hasData
                                                  ? _buildCardBalancesByUser(
                                                      cardsSnapshot.data!.docs,
                                                    )
                                                  : const <
                                                      String,
                                                      _UserCardBalances
                                                    >{};

                                              return SingleChildScrollView(
                                                child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: DataTable(
                                                    columnSpacing: 22,
                                                    headingRowHeight: 44,
                                                    dataRowMinHeight: 50,
                                                    dataRowMaxHeight: 56,
                                                    headingRowColor:
                                                        const WidgetStatePropertyAll(
                                                          Color(0xFFF8FAFC),
                                                        ),
                                                    border: TableBorder(
                                                      horizontalInside:
                                                          BorderSide(
                                                            color:
                                                                const Color(
                                                                  0xFFE5E7EB,
                                                                ).withValues(
                                                                  alpha: 0.7,
                                                                ),
                                                          ),
                                                    ),
                                                    columns: <DataColumn>[
                                                      DataColumn(
                                                        label: Text(
                                                          _t('Tên', 'Name'),
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                      DataColumn(
                                                        label: Text(
                                                          _t(
                                                            'Số dư Thẻ thường',
                                                            'Normal Card Balance',
                                                          ),
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                      DataColumn(
                                                        label: Text(
                                                          _t(
                                                            'Số dư Thẻ VIP',
                                                            'VIP Card Balance',
                                                          ),
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                    rows: users
                                                        .map((
                                                          QueryDocumentSnapshot<
                                                            Map<String, dynamic>
                                                          >
                                                          doc,
                                                        ) {
                                                          final Map<
                                                            String,
                                                            dynamic
                                                          >
                                                          data = doc.data();
                                                          final _UserCardBalances?
                                                          cardData =
                                                              cardBalancesByUser[doc
                                                                  .id];
                                                          final double
                                                          normalBalance =
                                                              cardData
                                                                  ?.balanceNormal ??
                                                              _readUserNormalBalance(
                                                                data,
                                                              );
                                                          final double
                                                          vipBalance =
                                                              cardData
                                                                  ?.balanceVip ??
                                                              _readUserVipBalance(
                                                                data,
                                                              );

                                                          return DataRow(
                                                            cells: <DataCell>[
                                                              DataCell(
                                                                Text(
                                                                  _readUserName(
                                                                    data,
                                                                  ),
                                                                  style: GoogleFonts.poppins(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                              DataCell(
                                                                Align(
                                                                  alignment:
                                                                      Alignment
                                                                          .centerRight,
                                                                  child: Text(
                                                                    _formatVndDouble(
                                                                      normalBalance,
                                                                    ),
                                                                    style: GoogleFonts.poppins(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              DataCell(
                                                                Align(
                                                                  alignment:
                                                                      Alignment
                                                                          .centerRight,
                                                                  child: Text(
                                                                    _formatVndDouble(
                                                                      vipBalance,
                                                                    ),
                                                                    style: GoogleFonts.poppins(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        })
                                                        .toList(
                                                          growable: false,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            },
                                      );
                                    },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
      transitionBuilder:
          (BuildContext context, Animation<double> animation, _, Widget child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
    );
  }

  Future<void> _showTodayTransactionsByUserDialog() async {
    _AdminHistoryFilterType filterType = _AdminHistoryFilterType.day;
    DateTime selectedPoint = DateTime.now();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'today-transactions-overlay',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setDialogState) {
                String filterLabel() {
                  if (filterType == _AdminHistoryFilterType.day) {
                    return DateFormat('dd/MM/yyyy').format(selectedPoint);
                  }
                  if (filterType == _AdminHistoryFilterType.month) {
                    return DateFormat('MM/yyyy').format(selectedPoint);
                  }
                  return DateFormat('yyyy').format(selectedPoint);
                }

                Future<void> pickDate() async {
                  final DateTime now = DateTime.now();
                  final DateTime? picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: selectedPoint,
                    firstDate: DateTime(2000, 1, 1),
                    lastDate: DateTime(now.year + 2, 12, 31),
                    helpText: _t('Chọn mốc thời gian', 'Pick date point'),
                    cancelText: _t('Hủy', 'Cancel'),
                    confirmText: _t('Chọn', 'Select'),
                  );
                  if (picked == null) {
                    return;
                  }
                  setDialogState(() {
                    if (filterType == _AdminHistoryFilterType.day) {
                      selectedPoint = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                      );
                    } else if (filterType == _AdminHistoryFilterType.month) {
                      selectedPoint = DateTime(picked.year, picked.month, 1);
                    } else {
                      selectedPoint = DateTime(picked.year, 1, 1);
                    }
                  });
                }

                return Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 760,
                            maxHeight: 640,
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        _t(
                                          'Giao dịch theo User',
                                          'Transactions by user',
                                        ),
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 38,
                                      child: _gradientActionButton(
                                        label: _t('Đóng', 'Close'),
                                        onPressed: () =>
                                            Navigator.pop(dialogContext),
                                        icon: Icons.close_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    ChoiceChip(
                                      label: Text(
                                        _t('Hôm nay', 'Today'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                        ),
                                      ),
                                      selected:
                                          filterType ==
                                          _AdminHistoryFilterType.day,
                                      onSelected: (_) {
                                        setDialogState(() {
                                          filterType =
                                              _AdminHistoryFilterType.day;
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: Text(
                                        _t('Tháng này', 'This month'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                        ),
                                      ),
                                      selected:
                                          filterType ==
                                          _AdminHistoryFilterType.month,
                                      onSelected: (_) {
                                        setDialogState(() {
                                          filterType =
                                              _AdminHistoryFilterType.month;
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: Text(
                                        _t('Năm nay', 'This year'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                        ),
                                      ),
                                      selected:
                                          filterType ==
                                          _AdminHistoryFilterType.year,
                                      onSelected: (_) {
                                        setDialogState(() {
                                          filterType =
                                              _AdminHistoryFilterType.year;
                                        });
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: pickDate,
                                      icon: const Icon(
                                        Icons.event_rounded,
                                        size: 17,
                                      ),
                                      label: Text(
                                        filterLabel(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: StreamBuilder<List<_AdminUserTransactionStat>>(
                                    stream: _allUsersTransactionStatsStream(
                                      filterType: filterType,
                                      selectedPoint: selectedPoint,
                                    ),
                                    builder:
                                        (
                                          BuildContext context,
                                          AsyncSnapshot<
                                            List<_AdminUserTransactionStat>
                                          >
                                          snapshot,
                                        ) {
                                          if (!snapshot.hasData) {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }

                                          final List<_AdminUserTransactionStat>
                                          stats =
                                              snapshot.data ??
                                              const <
                                                _AdminUserTransactionStat
                                              >[];
                                          if (stats.isEmpty) {
                                            return Center(
                                              child: Text(
                                                _t(
                                                  'Không có giao dịch trong khoảng thời gian đã chọn',
                                                  'No transactions in selected range',
                                                ),
                                                style: GoogleFonts.poppins(
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          }

                                          return ListView.separated(
                                            itemCount: stats.length,
                                            separatorBuilder:
                                                (
                                                  BuildContext context,
                                                  int index,
                                                ) => const SizedBox(height: 8),
                                            itemBuilder: (BuildContext context, int index) {
                                              final _AdminUserTransactionStat
                                              item = stats[index];
                                              return Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  onTap: () {
                                                    Navigator.pop(
                                                      dialogContext,
                                                    );
                                                    if (!mounted) {
                                                      return;
                                                    }
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            _AdminUserTransactionHistoryScreen(
                                                              userId:
                                                                  item.userId,
                                                              userName:
                                                                  item.userName,
                                                              initialFilterType:
                                                                  filterType,
                                                              initialSelectedPoint:
                                                                  selectedPoint,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFFE5E7EB,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: <Widget>[
                                                        Expanded(
                                                          child: Text(
                                                            item.userName,
                                                            style:
                                                                GoogleFonts.poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 13,
                                                                ),
                                                          ),
                                                        ),
                                                        _statusBadge(
                                                          label:
                                                              '${item.count} ${_t('giao dịch', 'transactions')}',
                                                          background:
                                                              const Color(
                                                                0xFFEFF6FF,
                                                              ),
                                                          foreground:
                                                              const Color(
                                                                0xFF1D4ED8,
                                                              ),
                                                          icon: Icons
                                                              .receipt_long_rounded,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        const Icon(
                                                          Icons
                                                              .chevron_right_rounded,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
      transitionBuilder:
          (BuildContext context, Animation<double> animation, _, Widget child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
    );
  }

  List<_AdminUserSummary> _buildUserSummaries(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    Map<String, _UserCardBalances> cardBalancesByUser =
        const <String, _UserCardBalances>{},
  }) {
    return docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = doc.data();
          final _UserCardBalances? cardBalances = cardBalancesByUser[doc.id];
          final double balanceNormal =
              cardBalances?.balanceNormal ?? _readUserNormalBalance(data);
          final double balanceVip =
              cardBalances?.balanceVip ?? _readUserVipBalance(data);
          final bool hasVipCard = data['hasVipCard'] == true;
          final bool isStandardLocked = data['is_standard_locked'] == true;
          final bool isVipLocked = data['is_vip_locked'] == true;
          final double visibleNormalBalance = isStandardLocked
              ? 0
              : balanceNormal;
          final double visibleVipBalance = (hasVipCard && !isVipLocked)
              ? balanceVip
              : 0;
          final double totalBalance = visibleNormalBalance + visibleVipBalance;
          final String rawCardNumber = CardNumberService.readStoredCardNumber(
            data,
          );

          return _AdminUserSummary(
            id: doc.id,
            fullName: _readUserName(data),
            account: _readUserAccount(data),
            cardNumberRaw: rawCardNumber,
            phoneNumber: _readUserPhone(data),
            cccd: _readUserCccd(data),
            address: _readUserAddress(data),
            role: (data['role'] ?? 'user').toString(),
            isLocked: data['isLocked'] == true,
            hasVipCard: hasVipCard,
            isStandardCardLocked: isStandardLocked,
            isVipCardLocked: isVipLocked,
            balanceNormal: balanceNormal,
            balanceVip: balanceVip,
            totalBalance: totalBalance,
          );
        })
        .toList(growable: false);
  }

  Future<void> _showUserDetails(_AdminUserSummary user) async {
    final BuildContext parentContext = context;
    final TextEditingController nameController = TextEditingController(
      text: user.fullName == '-' ? '' : user.fullName,
    );
    final TextEditingController phoneController = TextEditingController(
      text: user.phoneNumber == '-' ? '' : user.phoneNumber,
    );
    final TextEditingController cccdController = TextEditingController(
      text: user.cccd == '-' ? '' : user.cccd,
    );
    final TextEditingController addressController = TextEditingController(
      text: user.address == '-' ? '' : user.address,
    );
    final TextEditingController normalBalanceController = TextEditingController(
      text: user.balanceNormal.round().toString(),
    );
    final TextEditingController vipBalanceController = TextEditingController(
      text: user.balanceVip.round().toString(),
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter _) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    22 + MediaQuery.of(innerContext).viewInsets.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _t('Thông tin người dùng', 'User details'),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF101828),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _sheetTextField(
                          controller: nameController,
                          label: _t('Họ tên', 'Full name'),
                        ),
                        const SizedBox(height: 8),
                        _sheetTextField(
                          controller: phoneController,
                          label: _t('Số điện thoại', 'Phone number'),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 8),
                        _sheetTextField(
                          controller: cccdController,
                          label: _t('CCCD', 'Citizen ID'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        _sheetTextField(
                          controller: addressController,
                          label: _t('Địa chỉ nhà', 'Home address'),
                        ),
                        const SizedBox(height: 8),
                        _sheetTextField(
                          controller: normalBalanceController,
                          label: _t('Số dư Thẻ Thường', 'Normal Card Balance'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        _sheetTextField(
                          controller: vipBalanceController,
                          label: _t('Số dư Thẻ VIP', 'VIP Card Balance'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                child: Text(
                                  _t('Đóng', 'Close'),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _gradientActionButton(
                                label: _t('Lưu', 'Save'),
                                icon: Icons.save_rounded,
                                onPressed: () async {
                                  final String nextName = nameController.text
                                      .trim();
                                  final String nextPhone = phoneController.text
                                      .trim();
                                  final String nextCccd = cccdController.text
                                      .trim();
                                  final String nextAddress = addressController
                                      .text
                                      .trim();
                                  final double nextNormalBalance =
                                      _parseBalanceInput(
                                        normalBalanceController.text,
                                      );
                                  final double nextVipBalance =
                                      _parseBalanceInput(
                                        vipBalanceController.text,
                                      );
                                  final double nextTotalBalance =
                                      (user.isStandardCardLocked
                                          ? 0
                                          : nextNormalBalance) +
                                      ((user.hasVipCard &&
                                              !user.isVipCardLocked)
                                          ? nextVipBalance
                                          : 0);
                                  final String currentCardRaw = user
                                      .cardNumberRaw
                                      .trim();
                                  final String nextCardNumber =
                                      currentCardRaw.isEmpty
                                      ? CardNumberService.generatePermanentCardNumber(
                                          <String, dynamic>{
                                            'cccd': nextCccd,
                                            'phoneNumber': nextPhone,
                                            'hasVipCard': user.hasVipCard,
                                          },
                                        )
                                      : currentCardRaw;

                                  if (nextName.isEmpty) {
                                    if (!parentContext.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(
                                      parentContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _t(
                                            'Vui lòng nhập họ tên',
                                            'Please enter full name',
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  try {
                                    final DocumentReference<
                                      Map<String, dynamic>
                                    >
                                    userRef = _firestore
                                        .collection('users')
                                        .doc(user.id);
                                    final WriteBatch batch = _firestore.batch();

                                    batch.set(
                                      userRef
                                          .collection('cards')
                                          .doc('standard'),
                                      <String, dynamic>{
                                        'balance': nextNormalBalance,
                                        'card_number': nextCardNumber,
                                        'cardNumber': nextCardNumber,
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      },
                                      SetOptions(merge: true),
                                    );

                                    batch.set(
                                      userRef.collection('cards').doc('vip'),
                                      <String, dynamic>{
                                        'balance': nextVipBalance,
                                        'card_number': nextCardNumber,
                                        'cardNumber': nextCardNumber,
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      },
                                      SetOptions(merge: true),
                                    );

                                    batch.set(userRef, <String, dynamic>{
                                      'fullName': nextName,
                                      'fullname': nextName,
                                      'phoneNumber': nextPhone,
                                      'cccd': nextCccd,
                                      'idNumber': nextCccd,
                                      'address': nextAddress,
                                      'card_number': nextCardNumber,
                                      'cardNumber': nextCardNumber,
                                      'balance_normal': nextNormalBalance,
                                      'balance_vip': nextVipBalance,
                                      'balance': nextTotalBalance,
                                      'totalBalance': nextTotalBalance,
                                      'availableBalance': nextTotalBalance,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));

                                    await batch.commit();

                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }

                                    if (!parentContext.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(
                                      parentContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _t(
                                            'Cập nhật thành công!',
                                            'Updated successfully!',
                                          ),
                                        ),
                                        backgroundColor: const Color(
                                          0xFF16A34A,
                                        ),
                                      ),
                                    );
                                  } catch (_) {
                                    if (!parentContext.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(
                                      parentContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _t(
                                            'Cập nhật thất bại',
                                            'Update failed',
                                          ),
                                        ),
                                        backgroundColor: const Color(
                                          0xFFDC2626,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: GoogleFonts.poppins(
        fontWeight: readOnly ? FontWeight.w700 : FontWeight.w500,
        color: readOnly ? const Color(0xFF0F172A) : const Color(0xFF111827),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 12),
        filled: readOnly,
        fillColor: readOnly ? const Color(0xFFF8FAFC) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _statusBadge({
    required String label,
    required Color background,
    required Color foreground,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientActionButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1D4ED8), Color(0xFF0B1E4D)],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon == null
            ? const SizedBox.shrink()
            : Icon(icon, size: 16, color: Colors.white),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBalanceChartCard(List<_AdminUserSummary> users) {
    final List<_AdminUserSummary> topUsers = users
        .take(6)
        .toList(growable: false);
    final double maxY = topUsers.isEmpty
        ? 1
        : (topUsers.first.totalBalance <= 0
              ? 1
              : topUsers.first.totalBalance * 1.2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('Biểu đồ số dư user', 'User balance chart'),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: topUsers.isEmpty
                ? Center(
                    child: Text(
                      _t('Chưa có dữ liệu', 'No data available'),
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF334155),
                          tooltipRoundedRadius: 8,
                          getTooltipItem:
                              (
                                BarChartGroupData group,
                                int groupIndex,
                                BarChartRodData rod,
                                int rodIndex,
                              ) {
                                return BarTooltipItem(
                                  _formatCommaAmount(rod.toY),
                                  GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                );
                              },
                        ),
                      ),
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final int idx = value.toInt();
                              if (idx < 0 || idx >= topUsers.length) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                '${idx + 1}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              return Text(
                                NumberFormat.compact(
                                  locale: 'vi',
                                ).format(value),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List<BarChartGroupData>.generate(
                        topUsers.length,
                        (int index) => BarChartGroupData(
                          x: index,
                          barRods: <BarChartRodData>[
                            BarChartRodData(
                              toY: topUsers[index].totalBalance,
                              width: 18,
                              color: _primaryBlue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          if (topUsers.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List<Widget>.generate(topUsers.length, (int idx) {
                final _AdminUserSummary user = topUsers[idx];
                return Text(
                  '${idx + 1}. ${user.fullName}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserBalancesCard(List<_AdminUserSummary> users) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('Tổng số dư từng user', 'User balances'),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final _AdminUserSummary user = users[index];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showUserDetails(user),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              user.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              user.account,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatVndDouble(user.totalBalance),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUserLock(
    DocumentReference<Map<String, dynamic>> ref,
    bool next,
  ) async {
    await ref.set(<String, dynamic>{
      'isLocked': next,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _editPackagePrices({
    required DocumentReference<Map<String, dynamic>> ref,
    required String serviceId,
    required String serviceName,
    required Map<String, dynamic> currentData,
  }) async {
    final List<Map<String, dynamic>> initialPackages = _parsePackageRows(
      (currentData['packages'] as List<dynamic>?) ?? <dynamic>[],
    );

    final List<Map<String, dynamic>> seedRows = initialPackages.isNotEmpty
        ? initialPackages
        : <Map<String, dynamic>>[
            <String, dynamic>{'title': '', 'price': 0, 'discountPercent': 0},
          ];

    final List<TextEditingController> titleControllers =
        List<TextEditingController>.generate(seedRows.length, (int index) {
          final String title = (seedRows[index]['title'] ?? '')
              .toString()
              .trim();
          return TextEditingController(text: title);
        });
    final List<TextEditingController> priceControllers =
        List<TextEditingController>.generate(seedRows.length, (int index) {
          final int price = (seedRows[index]['price'] as num?)?.toInt() ?? 0;
          return TextEditingController(text: price > 0 ? price.toString() : '');
        });
    final List<TextEditingController> discountControllers =
        List<TextEditingController>.generate(seedRows.length, (int index) {
          final int discount = _sanitizeDiscountPercent(
            seedRows[index]['discountPercent'],
          );
          return TextEditingController(
            text: discount > 0 ? discount.toString() : '',
          );
        });
    final List<TextEditingController> detachedControllers =
        <TextEditingController>[];

    String defaultPackageTitle(int index) {
      return '${_t('Gói', 'Package')} ${index + 1}';
    }

    final List<Map<String, dynamic>>?
    nextPackages = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Center(
                  child: Dialog(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _t('Sửa gói giá', 'Edit package pricing'),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 400),
                            child: SingleChildScrollView(
                              child: Column(
                                children: List<Widget>.generate(titleControllers.length, (
                                  int index,
                                ) {
                                  return Padding(
                                    key: ValueKey<TextEditingController>(
                                      titleControllers[index],
                                    ),
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            children: <Widget>[
                                              Expanded(
                                                child: Text(
                                                  '${_t('Gói', 'Package')} ${index + 1}',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              if (titleControllers.length > 1)
                                                IconButton(
                                                  onPressed: () {
                                                    FocusScope.of(
                                                      dialogContext,
                                                    ).unfocus();
                                                    setDialogState(() {
                                                      final TextEditingController
                                                      removedTitle =
                                                          titleControllers
                                                              .removeAt(index);
                                                      final TextEditingController
                                                      removedPrice =
                                                          priceControllers
                                                              .removeAt(index);
                                                      final TextEditingController
                                                      removedDiscount =
                                                          discountControllers
                                                              .removeAt(index);

                                                      // Dispose detached controllers after dialog closes
                                                      // to avoid disposing while TextField tree is still rebuilding.
                                                      detachedControllers.add(
                                                        removedTitle,
                                                      );
                                                      detachedControllers.add(
                                                        removedPrice,
                                                      );
                                                      detachedControllers.add(
                                                        removedDiscount,
                                                      );
                                                    });
                                                  },
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 18,
                                                  ),
                                                  tooltip: _t(
                                                    'Xóa gói',
                                                    'Remove package',
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: titleControllers[index],
                                            decoration: InputDecoration(
                                              labelText: _t(
                                                'Tên gói',
                                                'Package title',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: priceControllers[index],
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: _t(
                                                'Giá gốc',
                                                'Original price',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller:
                                                discountControllers[index],
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: _t(
                                                '% Giảm giá (0-100)',
                                                'Discount % (0-100)',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  titleControllers.add(TextEditingController());
                                  priceControllers.add(TextEditingController());
                                  discountControllers.add(
                                    TextEditingController(),
                                  );
                                });
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: Text(_t('Thêm gói', 'Add package')),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: Text(
                                  _t('Đóng', 'Close'),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _gradientActionButton(
                                label: _t('Lưu', 'Save'),
                                icon: Icons.save_rounded,
                                onPressed: () {
                                  final List<Map<String, dynamic>> packages =
                                      <Map<String, dynamic>>[];

                                  for (
                                    int i = 0;
                                    i < titleControllers.length;
                                    i++
                                  ) {
                                    final int price =
                                        int.tryParse(
                                          priceControllers[i].text
                                              .trim()
                                              .replaceAll(
                                                RegExp(r'[^0-9]'),
                                                '',
                                              ),
                                        ) ??
                                        0;
                                    final int discountPercent =
                                        _sanitizeDiscountPercent(
                                          discountControllers[i].text.trim(),
                                        );

                                    if (price > 0) {
                                      final String title =
                                          titleControllers[i].text
                                              .trim()
                                              .isNotEmpty
                                          ? titleControllers[i].text.trim()
                                          : defaultPackageTitle(i);
                                      packages.add(<String, dynamic>{
                                        'title': title,
                                        'price': price,
                                        'discountPercent': discountPercent,
                                      });
                                    }
                                  }

                                  if (packages.isEmpty) {
                                    if (!dialogContext.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(
                                      dialogContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _t(
                                            'Vui lòng nhập ít nhất 1 mức giá hợp lệ',
                                            'Please enter at least one valid price',
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.pop(dialogContext, packages);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (nextPackages != null) {
      await ref.set(<String, dynamic>{
        'packages': nextPackages,
        'discountPercent': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _adminCollection(
        'services_pricing',
      ).doc(serviceId).set(<String, dynamic>{
        'id': serviceId,
        'kind': 'shopping_bundle',
        'packages': nextPackages,
        'discountPercent': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _pushShoppingDiscountNotifications(
        serviceId: serviceId,
        serviceName: serviceName,
        packages: nextPackages,
      );
    }

    // The dialog Future resolves before the pop animation fully settles.
    // Dispose controllers after a short delay to avoid listener updates
    // on already-disposed controllers during transition rebuilds.
    _disposeTextControllersDeferred(<TextEditingController>[
      ...titleControllers,
      ...priceControllers,
      ...discountControllers,
      ...detachedControllers,
    ]);
  }

  void _disposeTextControllersDeferred(List<TextEditingController> controls) {
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      for (final TextEditingController controller in controls) {
        try {
          controller.dispose();
        } catch (_) {
          // Ignore double-dispose edge cases in debug teardown paths.
        }
      }
    });
  }

  bool _isValidHttpUrl(String raw) {
    final Uri? uri = Uri.tryParse(raw.trim());
    if (uri == null) {
      return false;
    }
    final String scheme = uri.scheme.toLowerCase();
    return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
  }

  Future<void> _showAddServiceDialog(BuildContext parentContext) async {
    final TextEditingController serviceNameController = TextEditingController();
    final TextEditingController logoUrlController = TextEditingController();
    final List<TextEditingController> titleControllers =
        <TextEditingController>[TextEditingController()];
    final List<TextEditingController> priceControllers =
        <TextEditingController>[TextEditingController()];
    final List<TextEditingController> discountControllers =
        <TextEditingController>[TextEditingController()];
    final List<TextEditingController> detachedControllers =
        <TextEditingController>[];

    String defaultPackageTitle(int index) {
      return '${_t('Gói', 'Package')} ${index + 1}';
    }

    Future<void> submit(BuildContext dialogContext) async {
      final String serviceName = serviceNameController.text.trim();
      final String logoUrl = logoUrlController.text.trim();

      if (serviceName.isEmpty) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Tên dịch vụ không được để trống',
                'Service name cannot be empty',
              ),
            ),
          ),
        );
        return;
      }

      if (logoUrl.isEmpty) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text(
              _t('Link logo không được để trống', 'Logo URL cannot be empty'),
            ),
          ),
        );
        return;
      }

      final List<Map<String, dynamic>> packages = <Map<String, dynamic>>[];
      for (int i = 0; i < titleControllers.length; i++) {
        final int price =
            int.tryParse(
              priceControllers[i].text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
        final int discountPercent = _sanitizeDiscountPercent(
          discountControllers[i].text.trim(),
        );
        if (price <= 0) {
          continue;
        }

        final String title = titleControllers[i].text.trim().isNotEmpty
            ? titleControllers[i].text.trim()
            : defaultPackageTitle(i);

        packages.add(<String, dynamic>{
          'title': title,
          'price': price,
          'discountPercent': discountPercent,
        });
      }

      if (packages.isEmpty) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Danh sách gói phải có ít nhất 1 gói hợp lệ',
                'Please add at least one valid package',
              ),
            ),
          ),
        );
        return;
      }

      try {
        final Map<String, dynamic> servicePayload = <String, dynamic>{
          'kind': 'shopping_bundle',
          'category': 'shopping_entertainment',
          'name': serviceName,
          'nameVi': serviceName,
          'nameEn': serviceName,
          'logoPath': logoUrl,
          'packages': packages,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final DocumentReference<Map<String, dynamic>> createdServiceRef =
            await FirebaseFirestore.instance
                .collection('services')
                .add(servicePayload);

        await _adminCollection(
          'services_pricing',
        ).doc(createdServiceRef.id).set(<String, dynamic>{
          ...servicePayload,
          'id': createdServiceRef.id,
        }, SetOptions(merge: true));

        await _pushNewServiceNotifications(
          serviceId: createdServiceRef.id,
          serviceName: serviceName,
        );

        if (!dialogContext.mounted) {
          return;
        }
        Navigator.pop(dialogContext);

        if (!parentContext.mounted) {
          return;
        }
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text(
              _t('Tạo mới dịch vụ thành công', 'Service created successfully'),
            ),
          ),
        );
      } catch (_) {
        if (!dialogContext.mounted) {
          return;
        }
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Không thể tạo dịch vụ mới, vui lòng thử lại',
                'Unable to create new service, please try again',
              ),
            ),
          ),
        );
      }
    }

    await showDialog<void>(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final String logoUrl = logoUrlController.text.trim();
            final bool canPreviewLogo = _isValidHttpUrl(logoUrl);

            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Center(
                  child: Dialog(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 560),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              _t('Tạo mới dịch vụ', 'Create new service'),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    TextField(
                                      controller: serviceNameController,
                                      decoration: InputDecoration(
                                        labelText: _t(
                                          'Tên dịch vụ / Sản phẩm',
                                          'Service / Product name',
                                        ),
                                        hintText: _t(
                                          'Ví dụ: Youtube Premium',
                                          'Example: Youtube Premium',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        Expanded(
                                          child: TextField(
                                            controller: logoUrlController,
                                            onChanged: (_) {
                                              setDialogState(() {});
                                            },
                                            decoration: InputDecoration(
                                              labelText: _t(
                                                'Link ảnh Logo (URL)',
                                                'Logo image link (URL)',
                                              ),
                                              hintText: _t(
                                                'Ví dụ: https://...',
                                                'Example: https://...',
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFFF8FAFC),
                                            border: Border.all(
                                              color: const Color(0xFFE5E7EB),
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: canPreviewLogo
                                              ? Image.network(
                                                  logoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        BuildContext context,
                                                        Object error,
                                                        StackTrace? stackTrace,
                                                      ) {
                                                        return Icon(
                                                          Icons.image_outlined,
                                                          color: Colors
                                                              .grey
                                                              .shade500,
                                                          size: 18,
                                                        );
                                                      },
                                                )
                                              : Icon(
                                                  Icons.image_outlined,
                                                  color: Colors.grey.shade500,
                                                  size: 18,
                                                ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    const Divider(height: 1),
                                    const SizedBox(height: 14),
                                    Text(
                                      _t('Danh sách các gói', 'Package list'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Column(
                                      children: List<Widget>.generate(titleControllers.length, (
                                        int index,
                                      ) {
                                        return Padding(
                                          key: ValueKey<TextEditingController>(
                                            titleControllers[index],
                                          ),
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0xFFE5E7EB),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Row(
                                                  children: <Widget>[
                                                    Expanded(
                                                      child: Text(
                                                        '${_t('Gói', 'Package')} ${index + 1}',
                                                        style:
                                                            GoogleFonts.poppins(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 12,
                                                            ),
                                                      ),
                                                    ),
                                                    if (titleControllers
                                                            .length >
                                                        1)
                                                      IconButton(
                                                        onPressed: () {
                                                          FocusScope.of(
                                                            dialogContext,
                                                          ).unfocus();
                                                          setDialogState(() {
                                                            final TextEditingController
                                                            removedTitle =
                                                                titleControllers
                                                                    .removeAt(
                                                                      index,
                                                                    );
                                                            final TextEditingController
                                                            removedPrice =
                                                                priceControllers
                                                                    .removeAt(
                                                                      index,
                                                                    );
                                                            final TextEditingController
                                                            removedDiscount =
                                                                discountControllers
                                                                    .removeAt(
                                                                      index,
                                                                    );

                                                            detachedControllers
                                                                .add(
                                                                  removedTitle,
                                                                );
                                                            detachedControllers
                                                                .add(
                                                                  removedPrice,
                                                                );
                                                            detachedControllers
                                                                .add(
                                                                  removedDiscount,
                                                                );
                                                          });
                                                        },
                                                        icon: const Icon(
                                                          Icons
                                                              .delete_outline_rounded,
                                                          size: 18,
                                                        ),
                                                        tooltip: _t(
                                                          'Xóa gói',
                                                          'Remove package',
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller:
                                                      titleControllers[index],
                                                  decoration: InputDecoration(
                                                    labelText: _t(
                                                      'Tên gói',
                                                      'Package title',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller:
                                                      priceControllers[index],
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration: InputDecoration(
                                                    labelText: _t(
                                                      'Giá gốc',
                                                      'Original price',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller:
                                                      discountControllers[index],
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration: InputDecoration(
                                                    labelText: _t(
                                                      '% Giảm giá (0-100)',
                                                      'Discount % (0-100)',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          setDialogState(() {
                                            titleControllers.add(
                                              TextEditingController(),
                                            );
                                            priceControllers.add(
                                              TextEditingController(),
                                            );
                                            discountControllers.add(
                                              TextEditingController(),
                                            );
                                          });
                                        },
                                        icon: const Icon(Icons.add_rounded),
                                        label: Text(
                                          _t('Thêm gói', 'Add package'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text(
                                    _t('Đóng', 'Close'),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _gradientActionButton(
                                  label: _t('Lưu', 'Save'),
                                  icon: Icons.save_rounded,
                                  onPressed: () async {
                                    await submit(dialogContext);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    _disposeTextControllersDeferred(<TextEditingController>[
      serviceNameController,
      logoUrlController,
      ...titleControllers,
      ...priceControllers,
      ...discountControllers,
      ...detachedControllers,
    ]);
  }

  Future<void> _showDeleteConfirmDialog(
    BuildContext parentContext,
    String documentId,
    String serviceName,
  ) async {
    await showCustomConfirmDialog(
      context: parentContext,
      title: AppText.text(parentContext, 'confirm_delete_service_title'),
      message: AppText.textWithParams(
        parentContext,
        'confirm_delete_service_message',
        <String, String>{'serviceName': serviceName},
      ),
      confirmText: AppText.text(parentContext, 'btn_delete'),
      cancelText: AppText.text(parentContext, 'btn_cancel'),
      confirmColor: Colors.red,
      onConfirm: () async {
        await FirebaseFirestore.instance
            .collection('services')
            .doc(documentId)
            .delete();

        await _adminCollection('services_pricing').doc(documentId).delete();

        if (!parentContext.mounted) {
          return;
        }
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text(
              AppText.text(parentContext, 'service_deleted_success'),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editBanner(
    DocumentReference<Map<String, dynamic>> ref,
    String imageUrl,
    bool isActive,
  ) async {
    final TextEditingController urlController = TextEditingController(
      text: imageUrl,
    );
    bool active = isActive;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Center(
                  child: Dialog(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _t('Sửa banner', 'Edit banner'),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: urlController,
                            decoration: InputDecoration(
                              hintText: _t(
                                'Link ảnh hoặc assets/...',
                                'Image URL or assets/...',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            value: active,
                            onChanged: (bool value) {
                              setDialogState(() {
                                active = value;
                              });
                            },
                            title: Text(
                              _t('Đang hiển thị', 'Is active'),
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: Text(
                                  _t('Đóng', 'Close'),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _gradientActionButton(
                                label: _t('Lưu', 'Save'),
                                icon: Icons.save_rounded,
                                onPressed: () async {
                                  final String url = urlController.text.trim();
                                  if (url.isEmpty) {
                                    return;
                                  }
                                  await ref.set(<String, dynamic>{
                                    'imageUrl': url,
                                    'isActive': active,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                                  if (!dialogContext.mounted) return;
                                  Navigator.pop(dialogContext);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addBanner() async {
    final TextEditingController urlController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withValues(alpha: 0.16)),
              ),
            ),
            Center(
              child: Dialog(
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _t('Thêm banner', 'Add banner'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlController,
                        decoration: InputDecoration(
                          hintText: _t(
                            'Link ảnh hoặc assets/...',
                            'Image URL or assets/...',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(
                              _t('Đóng', 'Close'),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _gradientActionButton(
                            label: _t('Thêm', 'Add'),
                            icon: Icons.add_rounded,
                            onPressed: () async {
                              final String url = urlController.text.trim();
                              if (url.isEmpty) {
                                return;
                              }

                              final CollectionReference<Map<String, dynamic>>
                              collection = _adminCollection('home_banners');
                              final DocumentReference<Map<String, dynamic>>
                              ref = collection.doc();

                              await ref.set(<String, dynamic>{
                                'imageUrl': url,
                                'isActive': true,
                                'order': DateTime.now().millisecondsSinceEpoch,
                                'createdAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream(),
      builder: (BuildContext context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _cardsStream(),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                cardsSnapshot,
              ) {
                final Map<String, _UserCardBalances> cardBalancesByUser =
                    cardsSnapshot.hasData
                    ? _buildCardBalancesByUser(cardsSnapshot.data!.docs)
                    : const <String, _UserCardBalances>{};

                final List<_AdminUserSummary> users = _buildUserSummaries(
                  docs,
                  cardBalancesByUser: cardBalancesByUser,
                )..sort((a, b) => b.totalBalance.compareTo(a.totalBalance));

                final int totalUsers = users.length;
                final double totalBalance = users.fold<double>(
                  0,
                  (double sum, _AdminUserSummary user) =>
                      sum + user.totalBalance,
                );

                return StreamBuilder<int>(
                  stream: _totalTransactionsCountStream,
                  builder:
                      (BuildContext context, AsyncSnapshot<int> txSnapshot) {
                        final String txCountText = '${txSnapshot.data ?? 0}';

                        return LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final double width = constraints.maxWidth;
                                final int crossAxisCount = width >= 1200
                                    ? 3
                                    : width >= 760
                                    ? 2
                                    : 1;
                                final double childAspectRatio =
                                    crossAxisCount == 1 ? 2.55 : 3.1;

                                final List<Widget> metricCards = <Widget>[
                                  _metricCard(
                                    title: _t('Tổng User', 'Total users'),
                                    value: '$totalUsers',
                                    icon: Icons.people_alt_rounded,
                                    onTap: _openUsersManagementTab,
                                  ),
                                  _metricCard(
                                    title: _t(
                                      'Tổng số dư hệ thống',
                                      'System total balance',
                                    ),
                                    value: _formatVndDouble(totalBalance),
                                    icon: Icons.account_balance_wallet_rounded,
                                    onTap: _showSystemBalancesOverlay,
                                  ),
                                  _metricCard(
                                    title: _t(
                                      'Tổng giao dịch user',
                                      'Total user transactions',
                                    ),
                                    value: txCountText,
                                    icon: Icons.receipt_long_rounded,
                                    onTap: _showTodayTransactionsByUserDialog,
                                  ),
                                ];

                                final Widget metricsSection =
                                    crossAxisCount == 1
                                    ? Column(
                                        children: metricCards
                                            .map(
                                              (Widget card) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                child: Center(
                                                  child: FractionallySizedBox(
                                                    widthFactor: 0.9,
                                                    child: card,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(growable: false),
                                      )
                                    : GridView.count(
                                        crossAxisCount: crossAxisCount,
                                        mainAxisSpacing: 16,
                                        crossAxisSpacing: 16,
                                        childAspectRatio: childAspectRatio,
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        children: metricCards,
                                      );

                                return ListView(
                                  children: <Widget>[
                                    metricsSection,
                                    const SizedBox(height: 14),
                                    _buildBalanceChartCard(users),
                                    const SizedBox(height: 14),
                                    _buildUserBalancesCard(users),
                                  ],
                                );
                              },
                        );
                      },
                );
              },
        );
      },
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final Widget card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE7EEFF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream(),
      builder: (BuildContext context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _cardsStream(),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                cardsSnapshot,
              ) {
                final Map<String, _UserCardBalances> cardBalancesByUser =
                    cardsSnapshot.hasData
                    ? _buildCardBalancesByUser(cardsSnapshot.data!.docs)
                    : const <String, _UserCardBalances>{};

                final List<_AdminUserSummary> users = _buildUserSummaries(
                  docs,
                  cardBalancesByUser: cardBalancesByUser,
                );

                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            showCheckboxColumn: false,
                            columnSpacing: 18,
                            horizontalMargin: 10,
                            headingRowHeight: 44,
                            dataRowMinHeight: 50,
                            dataRowMaxHeight: 58,
                            headingRowColor: const WidgetStatePropertyAll(
                              Color(0xFFF8FAFC),
                            ),
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: const Color(
                                  0xFFE5E7EB,
                                ).withValues(alpha: 0.7),
                              ),
                            ),
                            columns: <DataColumn>[
                              DataColumn(
                                label: Text(
                                  _t('Họ tên', 'Full name'),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  _t('Trạng thái', 'Status'),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  _t('Hành động', 'Action'),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            rows: users
                                .map((_AdminUserSummary user) {
                                  final bool canToggle = user.role != 'admin';
                                  final DocumentReference<Map<String, dynamic>>
                                  ref = _firestore
                                      .collection('users')
                                      .doc(user.id);

                                  return DataRow(
                                    cells: <DataCell>[
                                      DataCell(
                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          onTap: () => _showUserDetails(user),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            child: Text(
                                              user.fullName,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _primaryBlue,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        user.isLocked
                                            ? _statusBadge(
                                                label: _t(
                                                  'Đã bị khóa',
                                                  'Locked',
                                                ),
                                                background: const Color(
                                                  0xFFFEE2E2,
                                                ),
                                                foreground: const Color(
                                                  0xFFB91C1C,
                                                ),
                                                icon: Icons.lock_rounded,
                                              )
                                            : _statusBadge(
                                                label: _t(
                                                  'Đang hoạt động',
                                                  'Active',
                                                ),
                                                background: const Color(
                                                  0xFFDCFCE7,
                                                ),
                                                foreground: const Color(
                                                  0xFF166534,
                                                ),
                                                icon:
                                                    Icons.check_circle_rounded,
                                              ),
                                      ),
                                      DataCell(
                                        ElevatedButton(
                                          onPressed: canToggle
                                              ? () => _toggleUserLock(
                                                  ref,
                                                  !user.isLocked,
                                                )
                                              : null,
                                          child: Text(
                                            user.isLocked
                                                ? _t('Mở khóa', 'Unlock')
                                                : _t('Khóa', 'Lock'),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
        );
      },
    );
  }

  Widget _buildServicesTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _servicesPricingStream,
      builder: (BuildContext context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs
                .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                  return _isShoppingBundleService(doc.data());
                })
                .toList(growable: false)
              ..sort((a, b) {
                final String aName = (a.data()['nameVi'] ?? a.id).toString();
                final String bName = (b.data()['nameVi'] ?? b.id).toString();
                return aName.compareTo(bName);
              });

        if (docs.isEmpty) {
          return Center(
            child: Text(
              _t('Chưa có dịch vụ để quản lý', 'No services available yet'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: 10),
          itemBuilder: (BuildContext context, int index) {
            final QueryDocumentSnapshot<Map<String, dynamic>> doc = docs[index];
            final Map<String, dynamic> data = doc.data();
            final String name = _t(
              (data['nameVi'] ?? doc.id).toString(),
              (data['nameEn'] ?? doc.id).toString(),
            );
            final String logoPath = (data['logoPath'] ?? '').toString();
            final List<Map<String, dynamic>> packageRows = _parsePackageRows(
              (data['packages'] as List<dynamic>?) ?? <dynamic>[],
            );
            final String priceLabel = packageRows.isEmpty
                ? _t('Chưa có mức giá', 'No prices yet')
                : packageRows
                      .map((Map<String, dynamic> item) {
                        final String title = (item['title'] ?? '')
                            .toString()
                            .trim();
                        final int price = (item['price'] as num?)?.toInt() ?? 0;
                        final int discountPercent = _sanitizeDiscountPercent(
                          item['discountPercent'],
                        );
                        final String base = discountPercent <= 0
                            ? _formatVnd(price)
                            : '${_formatVnd(price)} (-$discountPercent%)';
                        if (discountPercent <= 0) {
                          return title.isEmpty ? base : '$title: $base';
                        }
                        return title.isEmpty ? base : '$title: $base';
                      })
                      .join(' | ');

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: logoPath.startsWith('http')
                        ? Image.network(
                            logoPath,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stackTrace,
                                ) => const Icon(
                                  Icons.image_not_supported_outlined,
                                ),
                          )
                        : Image.asset(
                            logoPath,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stackTrace,
                                ) => const Icon(
                                  Icons.image_not_supported_outlined,
                                ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          priceLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475467),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: _t('Chỉnh sửa giá', 'Edit prices'),
                        onPressed: () => _editPackagePrices(
                          ref: doc.reference,
                          serviceId: doc.id,
                          serviceName: name,
                          currentData: data,
                        ),
                        icon: const Icon(Icons.edit_rounded),
                        color: _primaryBlue,
                      ),
                      IconButton(
                        tooltip: _t('Xóa dịch vụ', 'Delete service'),
                        onPressed: () =>
                            _showDeleteConfirmDialog(context, doc.id, name),
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBannersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _bannersStream,
      builder: (BuildContext context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs;

        return Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _addBanner,
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: Text(
                  _t('Thêm banner', 'Add banner'),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (BuildContext context, int index) {
                  final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                      docs[index];
                  final Map<String, dynamic> data = doc.data();
                  final String imageUrl = (data['imageUrl'] ?? '').toString();
                  final bool isActive = data['isActive'] == true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 64,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFFECEFF8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: imageUrl.startsWith('http')
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (
                                      BuildContext context,
                                      Object error,
                                      StackTrace? stackTrace,
                                    ) {
                                      return const Icon(
                                        Icons.broken_image_outlined,
                                      );
                                    },
                              )
                            : Image.asset(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (
                                      BuildContext context,
                                      Object error,
                                      StackTrace? stackTrace,
                                    ) {
                                      return const Icon(
                                        Icons.image_not_supported_outlined,
                                      );
                                    },
                              ),
                      ),
                      title: Text(
                        imageUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: isActive
                            ? _statusBadge(
                                label: _t('Đang hiển thị', 'Displayed'),
                                background: const Color(0xFFDCFCE7),
                                foreground: const Color(0xFF166534),
                                icon: Icons.check_circle_rounded,
                              )
                            : _statusBadge(
                                label: _t('Bị ẩn', 'Hidden'),
                                background: const Color(0xFFFEE2E2),
                                foreground: const Color(0xFFB91C1C),
                                icon: Icons.visibility_off_rounded,
                              ),
                      ),
                      dense: true,
                      isThreeLine: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: () =>
                                _editBanner(doc.reference, imageUrl, isActive),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => doc.reference.delete(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCardsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream(),
      builder: (BuildContext context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Text(
              _t('Chưa có người dùng', 'No users found'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (BuildContext context, int index) {
            final QueryDocumentSnapshot<Map<String, dynamic>> doc = docs[index];
            final Map<String, dynamic> data = doc.data();

            final bool isStandardLocked = data['is_standard_locked'] == true;
            final bool isVipLocked = data['is_vip_locked'] == true;
            final bool hasVipCard = data['hasVipCard'] == true;
            final String userName = _readUserName(data);
            final String userPhone = _readUserPhone(data);
            final String cardNumber = _readUserAccount(data);
            final String standardKey = _cardLockUpdateKey(
              userId: doc.id,
              fieldName: 'is_standard_locked',
            );
            final String vipKey = _cardLockUpdateKey(
              userId: doc.id,
              fieldName: 'is_vip_locked',
            );
            final bool effectiveStandardLocked =
                _cardLockOverrides[standardKey] ?? isStandardLocked;
            final bool effectiveVipLocked =
                _cardLockOverrides[vipKey] ?? isVipLocked;
            final bool standardUpdating = _pendingCardLockUpdates.contains(
              standardKey,
            );
            final bool vipUpdating = _pendingCardLockUpdates.contains(vipKey);

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE7EEFF),
                  child: Icon(
                    Icons.person_rounded,
                    color: _primaryBlue,
                    size: 20,
                  ),
                ),
                title: Text(
                  userName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  '$userPhone • $cardNumber',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF667085),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                children: <Widget>[
                  _buildCardLockTile(
                    userId: doc.id,
                    fieldName: 'is_standard_locked',
                    cardName: AppText.text(context, 'card_standard'),
                    isLocked: effectiveStandardLocked,
                    isUpdating: standardUpdating,
                  ),
                  const Divider(height: 1),
                  _buildCardLockTile(
                    userId: doc.id,
                    fieldName: 'is_vip_locked',
                    cardName: AppText.text(context, 'card_vip'),
                    isLocked: effectiveVipLocked,
                    isUpdating: vipUpdating,
                    isEnabled: hasVipCard,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCardLockTile({
    required String userId,
    required String fieldName,
    required String cardName,
    required bool isLocked,
    required bool isUpdating,
    bool isEnabled = true,
  }) {
    final String statusText = !isEnabled
        ? _t('Chưa có thẻ VIP', 'No VIP card')
        : isLocked
        ? AppText.text(context, 'status_locked')
        : AppText.text(context, 'status_active');
    final Color statusColor = !isEnabled
        ? const Color(0xFF64748B)
        : isLocked
        ? const Color(0xFFB91C1C)
        : const Color(0xFF166534);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        cardName,
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          statusText,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            !isEnabled
                ? _t('Không khả dụng', 'Unavailable')
                : isLocked
                ? AppText.text(context, 'unlock_card')
                : AppText.text(context, 'lock_card'),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF344054),
            ),
          ),
          const SizedBox(width: 8),
          if (isUpdating)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (isUpdating) const SizedBox(width: 8),
          Switch(
            value: isLocked,
            onChanged: (!isEnabled || isUpdating)
                ? null
                : (bool newValue) {
                    _updateCardLockState(
                      userId: userId,
                      fieldName: fieldName,
                      currentValue: isLocked,
                      newValue: newValue,
                    );
                  },
          ),
        ],
      ),
    );
  }

  String _cardLockUpdateKey({
    required String userId,
    required String fieldName,
  }) {
    return '$userId::$fieldName';
  }

  Future<void> _updateCardLockState({
    required String userId,
    required String fieldName,
    required bool currentValue,
    required bool newValue,
  }) async {
    if (currentValue == newValue) {
      return;
    }

    final String updateKey = _cardLockUpdateKey(
      userId: userId,
      fieldName: fieldName,
    );
    if (_pendingCardLockUpdates.contains(updateKey)) {
      return;
    }

    if (mounted) {
      setState(() {
        _pendingCardLockUpdates.add(updateKey);
        _cardLockOverrides[updateKey] = newValue;
      });
    }

    try {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentReference<Map<String, dynamic>> userRef = _firestore
            .collection('users')
            .doc(userId);
        final DocumentReference<Map<String, dynamic>> standardCardRef = userRef
            .collection('cards')
            .doc('standard');
        final DocumentReference<Map<String, dynamic>> vipCardRef = userRef
            .collection('cards')
            .doc('vip');

        final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
            await transaction.get(userRef);
        final DocumentSnapshot<Map<String, dynamic>> standardCardSnapshot =
            await transaction.get(standardCardRef);
        final DocumentSnapshot<Map<String, dynamic>> vipCardSnapshot =
            await transaction.get(vipCardRef);

        final Map<String, dynamic> userData =
            userSnapshot.data() ?? <String, dynamic>{};
        final bool hasVipCard = userData['hasVipCard'] == true;
        final bool currentStandardLocked =
            userData['is_standard_locked'] == true;
        final bool currentVipLocked = userData['is_vip_locked'] == true;

        final bool nextStandardLocked = fieldName == 'is_standard_locked'
            ? newValue
            : currentStandardLocked;
        final bool nextVipLocked = fieldName == 'is_vip_locked'
            ? newValue
            : currentVipLocked;

        final Map<String, dynamic> standardCardData =
            standardCardSnapshot.data() ?? <String, dynamic>{};
        final Map<String, dynamic> vipCardData =
            vipCardSnapshot.data() ?? <String, dynamic>{};

        final double standardBalance = _toDouble(standardCardData['balance']);
        final double vipBalance = _toDouble(vipCardData['balance']);
        final double availableBalance =
            (nextStandardLocked ? 0 : standardBalance) +
            ((hasVipCard && !nextVipLocked) ? vipBalance : 0);

        transaction.set(userRef, <String, dynamic>{
          fieldName: newValue,
          'balance_normal': standardBalance,
          'balance_vip': vipBalance,
          'balance': availableBalance,
          'totalBalance': availableBalance,
          'availableBalance': availableBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (mounted) {
        setState(() {
          _pendingCardLockUpdates.remove(updateKey);
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingCardLockUpdates.remove(updateKey);
        _cardLockOverrides[updateKey] = currentValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Không thể cập nhật trạng thái thẻ',
              'Unable to update card status',
            ),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }

  Widget _buildContent() {
    return IndexedStack(
      index: _selectedTab,
      children: <Widget>[
        KeyedSubtree(
          key: const PageStorageKey<String>('admin-tab-dashboard'),
          child: _buildDashboardTab(),
        ),
        KeyedSubtree(
          key: const PageStorageKey<String>('admin-tab-users'),
          child: _buildUsersTab(),
        ),
        KeyedSubtree(
          key: const PageStorageKey<String>('admin-tab-services'),
          child: _buildServicesTab(),
        ),
        KeyedSubtree(
          key: const PageStorageKey<String>('admin-tab-banners'),
          child: _buildBannersTab(),
        ),
        KeyedSubtree(
          key: const PageStorageKey<String>('admin-tab-cards'),
          child: _buildCardsTab(),
        ),
      ],
    );
  }

  Widget _sidebarItem({
    required int index,
    required IconData icon,
    required String label,
    bool compact = false,
  }) {
    final bool selected = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withValues(alpha: 0.1),
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected
                ? const LinearGradient(
                    colors: <Color>[Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: _neonBlue.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? _neonBlue
                      : Colors.white.withValues(alpha: 0.75),
                ),
              ),
              if (!compact) ...<Widget>[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List<Widget>.generate(_tabConfig.length, (int index) {
            final ({IconData icon, String vi, String en, String? textKey}) tab =
                _tabConfig[index];

            return Padding(
              padding: EdgeInsets.only(
                right: index == _tabConfig.length - 1 ? 0 : 8,
              ),
              child: _mobileTabChip(
                index: index,
                icon: tab.icon,
                label: _tabLabel(tab),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _mobileTabChip({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool selected = _selectedTab == index;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? _primaryBlue.withValues(alpha: 0.12)
              : const Color(0xFFF8FAFC),
          border: Border.all(
            color: selected
                ? _primaryBlue.withValues(alpha: 0.22)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: selected ? _primaryBlue : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _primaryBlue : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopSidebar(bool wide) {
    return Container(
      width: wide ? 260 : 86,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_sidebarStart, _sidebarEnd],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 6),
          Text(
            wide ? _t('Quản trị', 'Administration') : 'ADM',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          _sidebarItem(
            index: 0,
            icon: Icons.dashboard_rounded,
            label: _t('Dashboard', 'Dashboard'),
            compact: !wide,
          ),
          _sidebarItem(
            index: 1,
            icon: Icons.people_alt_rounded,
            label: _t('Người dùng', 'Users'),
            compact: !wide,
          ),
          _sidebarItem(
            index: 2,
            icon: Icons.price_change_rounded,
            label: _t('Dịch vụ', 'Services'),
            compact: !wide,
          ),
          _sidebarItem(
            index: 3,
            icon: Icons.photo_library_rounded,
            label: _t('Banner', 'Banners'),
            compact: !wide,
          ),
          _sidebarItem(
            index: 4,
            icon: Icons.credit_card,
            label: AppText.text(context, 'tab_cards'),
            compact: !wide,
          ),
        ],
      ),
    );
  }

  Widget _contentPanel({EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(0, 12, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _buildContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF0B1E4D), Color(0xFF020617)],
            ),
          ),
        ),
        title: Text(
          _t('CCPBank Admin Dashboard', 'CCPBank Admin Dashboard'),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: <Widget>[
          PopupMenuButton<int>(
            tooltip: AppText.text(context, 'menu_settings'),
            icon: const Icon(Icons.settings, color: Colors.white),
            onSelected: _onSettingsMenuSelected,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              PopupMenuItem<int>(
                value: 1,
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.language, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      AppText.text(context, 'menu_switch_language'),
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<int>(
                value: 2,
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.logout, size: 18, color: Colors.red),
                    const SizedBox(width: 10),
                    Text(
                      AppText.text(context, 'menu_logout'),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: wide
          ? Row(
              children: <Widget>[
                _desktopSidebar(wide),
                Expanded(child: _contentPanel()),
              ],
            )
          : Column(
              children: <Widget>[
                _mobileTabBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: _contentPanel(margin: EdgeInsets.zero),
                  ),
                ),
              ],
            ),
      floatingActionButton: _selectedTab == 2
          ? FloatingActionButton(
              onPressed: () => _showAddServiceDialog(context),
              backgroundColor: _primaryBlue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

class _UserCardBalances {
  const _UserCardBalances({this.balanceNormal = 0, this.balanceVip = 0});

  final double balanceNormal;
  final double balanceVip;

  double get totalBalance => balanceNormal + balanceVip;

  _UserCardBalances copyWith({double? balanceNormal, double? balanceVip}) {
    return _UserCardBalances(
      balanceNormal: balanceNormal ?? this.balanceNormal,
      balanceVip: balanceVip ?? this.balanceVip,
    );
  }
}

class _AdminUserSummary {
  const _AdminUserSummary({
    required this.id,
    required this.fullName,
    required this.account,
    required this.cardNumberRaw,
    required this.phoneNumber,
    required this.cccd,
    required this.address,
    required this.role,
    required this.isLocked,
    required this.hasVipCard,
    required this.isStandardCardLocked,
    required this.isVipCardLocked,
    required this.balanceNormal,
    required this.balanceVip,
    required this.totalBalance,
  });

  final String id;
  final String fullName;
  final String account;
  final String cardNumberRaw;
  final String phoneNumber;
  final String cccd;
  final String address;
  final String role;
  final bool isLocked;
  final bool hasVipCard;
  final bool isStandardCardLocked;
  final bool isVipCardLocked;
  final double balanceNormal;
  final double balanceVip;
  final double totalBalance;
}

enum _AdminHistoryFilterType { day, month, year }

class _AdminUserTransactionStat {
  const _AdminUserTransactionStat({
    required this.userId,
    required this.userName,
    required this.count,
  });

  final String userId;
  final String userName;
  final int count;
}

class _AdminMergedTransaction {
  const _AdminMergedTransaction({
    required this.sourceKey,
    required this.typeLabel,
    required this.amount,
    required this.occurredAt,
  });

  final String sourceKey;
  final String typeLabel;
  final double amount;
  final DateTime? occurredAt;
}

class _AdminUserTransactionHistoryScreen extends StatefulWidget {
  const _AdminUserTransactionHistoryScreen({
    required this.userId,
    required this.userName,
    required this.initialFilterType,
    required this.initialSelectedPoint,
  });

  final String userId;
  final String userName;
  final _AdminHistoryFilterType initialFilterType;
  final DateTime initialSelectedPoint;

  @override
  State<_AdminUserTransactionHistoryScreen> createState() =>
      _AdminUserTransactionHistoryScreenState();
}

class _AdminUserTransactionHistoryScreenState
    extends State<_AdminUserTransactionHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late _AdminHistoryFilterType _filterType;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _filterType = widget.initialFilterType;
    _selectedDate = widget.initialSelectedPoint;
  }

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  DateTimeRange _currentRange() {
    final DateTime base = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    switch (_filterType) {
      case _AdminHistoryFilterType.day:
        return DateTimeRange(
          start: base,
          end: base.add(const Duration(days: 1)),
        );
      case _AdminHistoryFilterType.month:
        final DateTime monthStart = DateTime(base.year, base.month, 1);
        final DateTime monthEnd = DateTime(base.year, base.month + 1, 1);
        return DateTimeRange(start: monthStart, end: monthEnd);
      case _AdminHistoryFilterType.year:
        final DateTime yearStart = DateTime(base.year, 1, 1);
        final DateTime yearEnd = DateTime(base.year + 1, 1, 1);
        return DateTimeRange(start: yearStart, end: yearEnd);
    }
  }

  String _sourceLabel(String sourceKey) {
    switch (sourceKey) {
      case 'Shopping':
      case 'shopping':
        return _t('Mua sắm', 'Shopping');
      case 'bill_payment':
        return _t('Thanh toán hóa đơn', 'Bill payment');
      case 'pay_bill':
      case 'paybill':
        return _t('Chi trả hóa đơn', 'Pay bill');
      case 'phone_recharge':
        return _t('Nạp điện thoại', 'Phone recharge');
      case 'recent_tranfer':
      case 'recent_transfer':
      case 'recent_transfers':
        return _t('Chuyển khoản', 'Transfer');
      case 'withdraw':
        return _t('Rút tiền', 'Withdraw');
      default:
        return sourceKey;
    }
  }

  double _readAmount(Map<String, dynamic> data) {
    final dynamic raw =
        data['amount'] ??
        data['money'] ??
        data['transactionAmount'] ??
        data['price'] ??
        data['value'];
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      final String clean = raw.replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(clean) ?? 0;
    }
    return 0;
  }

  int _sourcePriority(String sourceKey) {
    switch (sourceKey) {
      case 'pay_bill':
      case 'paybill':
        return 100;
      case 'recent_tranfer':
        return 95;
      case 'bill_payment':
        return 90;
      case 'phone_recharge':
        return 85;
      case 'withdraw':
        return 80;
      case 'Shopping':
      case 'shopping':
        return 70;
      case 'recent_transfer':
        return 60;
      case 'recent_transfers':
        return 55;
      default:
        return 0;
    }
  }

  Stream<List<_AdminMergedTransaction>> _userTransactionsStream() {
    final DateTimeRange range = _currentRange();
    final List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams =
        _kTransactionCollections
            .map(
              (String source) => _firestore
                  .collection('users')
                  .doc(widget.userId)
                  .collection(source)
                  .snapshots(includeMetadataChanges: true),
            )
            .toList(growable: false);

    return CombineLatestStream.list<QuerySnapshot<Map<String, dynamic>>>(
      streams,
    ).map((List<QuerySnapshot<Map<String, dynamic>>> snapshots) {
      final Map<String, _AdminMergedTransaction> mergedByKey =
          <String, _AdminMergedTransaction>{};
      final Map<String, int> priorityByKey = <String, int>{};

      for (int i = 0; i < snapshots.length; i++) {
        final String sourceKey = _kTransactionCollections[i];
        final QuerySnapshot<Map<String, dynamic>> sourceSnapshot = snapshots[i];

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in sourceSnapshot.docs) {
          final Map<String, dynamic> data = doc.data();
          final DateTime? txTime = _extractTransactionTime(data);
          if (!_isTimeInRange(txTime, range)) {
            continue;
          }

          final double amount = _readAmount(data);
          final String transactionCode =
              (data['transactionCode'] ?? data['relatedId'] ?? data['id'] ?? '')
                  .toString()
                  .trim();
          final String minuteKey = txTime == null
              ? 'no_time'
              : '${txTime.year.toString().padLeft(4, '0')}-'
                    '${txTime.month.toString().padLeft(2, '0')}-'
                    '${txTime.day.toString().padLeft(2, '0')} '
                    '${txTime.hour.toString().padLeft(2, '0')}:'
                    '${txTime.minute.toString().padLeft(2, '0')}';

          final String dedupKey = transactionCode.isNotEmpty
              ? '${widget.userId}_code_$transactionCode'
              : '${widget.userId}_${amount.toStringAsFixed(2)}_$minuteKey';

          final int currentPriority = _sourcePriority(sourceKey);
          final int existingPriority = priorityByKey[dedupKey] ?? -1;
          if (currentPriority < existingPriority) {
            continue;
          }

          mergedByKey[dedupKey] = _AdminMergedTransaction(
            sourceKey: sourceKey,
            typeLabel: _sourceLabel(sourceKey),
            amount: amount,
            occurredAt: txTime,
          );
          priorityByKey[dedupKey] = currentPriority;
        }
      }

      final List<_AdminMergedTransaction> merged = mergedByKey.values.toList(
        growable: false,
      );

      merged.sort((a, b) {
        final DateTime? atA = a.occurredAt;
        final DateTime? atB = b.occurredAt;
        if (atA == null && atB == null) {
          return 0;
        }
        if (atA == null) {
          return 1;
        }
        if (atB == null) {
          return -1;
        }
        return atB.compareTo(atA);
      });

      return merged;
    });
  }

  String _selectedDateText() {
    switch (_filterType) {
      case _AdminHistoryFilterType.day:
        return DateFormat('dd/MM/yyyy').format(_selectedDate);
      case _AdminHistoryFilterType.month:
        return DateFormat('MM/yyyy').format(_selectedDate);
      case _AdminHistoryFilterType.year:
        return DateFormat('yyyy').format(_selectedDate);
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: _t('Chọn mốc thời gian', 'Pick date point'),
      cancelText: _t('Hủy', 'Cancel'),
      confirmText: _t('Chọn', 'Select'),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (_filterType == _AdminHistoryFilterType.day) {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      } else if (_filterType == _AdminHistoryFilterType.month) {
        _selectedDate = DateTime(picked.year, picked.month, 1);
      } else {
        _selectedDate = DateTime(picked.year, 1, 1);
      }
    });
  }

  String _formatMoney(double value) {
    return '${NumberFormat.decimalPattern('vi_VN').format(value.round())} VND';
  }

  Widget _txStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.check_circle_rounded,
            size: 13,
            color: Color(0xFF166534),
          ),
          const SizedBox(width: 4),
          Text(
            _t('Thành công', 'Success'),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF166534),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF0B1E4D), Color(0xFF020617)],
            ),
          ),
        ),
        title: Text(
          _t(
            'Lịch sử giao dịch: ${widget.userName}',
            'Transaction history: ${widget.userName}',
          ),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        label: Text(
                          _t('Ngày', 'Day'),
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        selected: _filterType == _AdminHistoryFilterType.day,
                        onSelected: (_) {
                          setState(() {
                            _filterType = _AdminHistoryFilterType.day;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: Text(
                          _t('Tháng', 'Month'),
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        selected: _filterType == _AdminHistoryFilterType.month,
                        onSelected: (_) {
                          setState(() {
                            _filterType = _AdminHistoryFilterType.month;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: Text(
                          _t('Năm', 'Year'),
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        selected: _filterType == _AdminHistoryFilterType.year,
                        onSelected: (_) {
                          setState(() {
                            _filterType = _AdminHistoryFilterType.year;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _t(
                            'Mốc lọc: ${_selectedDateText()}',
                            'Filter point: ${_selectedDateText()}',
                          ),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.event_rounded, size: 18),
                        label: Text(
                          _t('Chọn ngày', 'Pick date'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: StreamBuilder<List<_AdminMergedTransaction>>(
                  stream: _userTransactionsStream(),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<_AdminMergedTransaction>> snapshot,
                      ) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final List<_AdminMergedTransaction> docs =
                            snapshot.data ?? const <_AdminMergedTransaction>[];

                        if (docs.isEmpty) {
                          return Center(
                            child: Text(
                              _t(
                                'Không có giao dịch trong khoảng thời gian đã chọn',
                                'No transactions in selected range',
                              ),
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                              child: Row(
                                children: <Widget>[
                                  Text(
                                    _t(
                                      'Tổng ${docs.length} giao dịch',
                                      'Total ${docs.length} transactions',
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    columnSpacing: 20,
                                    headingRowHeight: 42,
                                    dataRowMinHeight: 44,
                                    dataRowMaxHeight: 52,
                                    headingRowColor:
                                        const WidgetStatePropertyAll(
                                          Color(0xFFF8FAFC),
                                        ),
                                    border: TableBorder(
                                      horizontalInside: BorderSide(
                                        color: const Color(
                                          0xFFE5E7EB,
                                        ).withValues(alpha: 0.7),
                                      ),
                                    ),
                                    columns: <DataColumn>[
                                      DataColumn(
                                        label: Text(
                                          _t(
                                            'Loại giao dịch',
                                            'Transaction type',
                                          ),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          _t('Số tiền', 'Amount'),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          _t('Thời gian', 'Time'),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          _t('Trạng thái', 'Status'),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: docs
                                        .map((_AdminMergedTransaction item) {
                                          final String timeText =
                                              item.occurredAt == null
                                              ? '-'
                                              : DateFormat(
                                                  'dd/MM/yyyy HH:mm',
                                                ).format(item.occurredAt!);
                                          return DataRow(
                                            cells: <DataCell>[
                                              DataCell(
                                                Row(
                                                  children: <Widget>[
                                                    CircleAvatar(
                                                      radius: 13,
                                                      backgroundColor:
                                                          const Color(
                                                            0xFFEAF2FF,
                                                          ),
                                                      child: Icon(
                                                        Icons
                                                            .receipt_long_rounded,
                                                        size: 14,
                                                        color: const Color(
                                                          0xFF1D4ED8,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      item.typeLabel,
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Text(
                                                    _formatMoney(item.amount),
                                                    style: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: const Color(
                                                        0xFF0F766E,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  timeText,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              DataCell(_txStatusBadge()),
                                            ],
                                          );
                                        })
                                        .toList(growable: false),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
