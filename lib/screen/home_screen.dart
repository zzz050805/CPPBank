import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import '../core/app_translations.dart';
import '../data/notification_firestore_service.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../shoppingservice/service_data.dart';
import '../shoppingservice/service_model.dart';
import '../shoppingservice/shopping_store_screen.dart';
import '../widget/pressable_scale.dart';
import '../widget/shimmer_box.dart';
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
  late final Stream<UserProfileData?> _profileStream;
  String? _spendingDataUid;
  Future<Map<String, double>>? _spendingDataFutureCache;
  String? _recentTransactionsUid;
  String? _recentTransactionsLanguageCode;
  Future<List<_HomeTransactionModel>>? _recentTransactionsFutureCache;
  double _lastKnownTotalBalance = 0;
  bool _hasLoadedBalance = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  String _formatCurrency(double value) {
    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value).replaceAll(',', '.');
  }

  @override
  void initState() {
    super.initState();
    _profileStream = UserFirestoreService.instance.currentUserProfileStream();
  }

  void refreshHomeData() {
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

  bool _parseHasVipCard(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  String _resolveUid() {
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

  num _readNumericValue(dynamic raw) {
    if (raw is num) {
      return raw;
    }

    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return 0;
      }
      final num? direct = num.tryParse(trimmed);
      if (direct != null) {
        return direct;
      }
      final String digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.isEmpty) {
        return 0;
      }
      return num.tryParse(digitsOnly) ?? 0;
    }

    return 0;
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

    final List<List<QueryDocumentSnapshot<Map<String, dynamic>>>> collections =
        await Future.wait<List<QueryDocumentSnapshot<Map<String, dynamic>>>>([
          _safeCollectionDocs(userRef, 'phone_recharge'),
          _safeCollectionDocs(userRef, 'withdraw'),
          _safeCollectionDocs(userRef, 'transfer'),
          _safeCollectionDocs(userRef, 'bill_payment'),
        ]);

    final List<_HomeTransactionModel> transactions = <_HomeTransactionModel>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in collections[0]) {
      final Map<String, dynamic> data = doc.data();
      final String provider = (data['provider'] ?? '').toString().trim();
      final String phoneNumber = (data['phoneNumber'] ?? '').toString().trim();

      transactions.add(
        _HomeTransactionModel(
          id: doc.id,
          title: provider.isEmpty
              ? _t('Nạp điện thoại', 'Phone top-up')
              : '${_t('Nạp ĐT', 'Top-up')} $provider',
          subtitle: phoneNumber.isEmpty
              ? _t('Nạp tiền điện thoại', 'Phone top-up')
              : '${_t('SĐT', 'Phone')}: $phoneNumber',
          amount: _readNumericValue(data['amount']).toDouble(),
          timestamp: _readTimestamp(data['createdAt'] ?? data['timestamp']),
          type: 'phone_recharge',
          isNegative: true,
        ),
      );
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in collections[1]) {
      final Map<String, dynamic> data = doc.data();
      final String withdrawCode = _firstNonEmpty([
        data['withdrawCode'],
        data['code'],
      ]);

      transactions.add(
        _HomeTransactionModel(
          id: doc.id,
          title: _t('Rút tiền mặt', 'Cash withdrawal'),
          subtitle: withdrawCode.isEmpty
              ? _t('Rút tiền ATM', 'ATM withdrawal')
              : withdrawCode,
          amount: _readNumericValue(data['amount']).toDouble(),
          timestamp: _readTimestamp(data['createdAt'] ?? data['timestamp']),
          type: 'withdraw',
          isNegative: true,
        ),
      );
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in collections[2]) {
      final Map<String, dynamic> data = doc.data();
      final bool isNegative = _resolveTransferIsNegative(data, uid);
      final String description = _firstNonEmpty([
        data['accountName'],
        data['recipientName'],
        data['receiverName'],
        data['accountNumber'],
        data['toAccountNumber'],
      ]);

      transactions.add(
        _HomeTransactionModel(
          id: doc.id,
          title: isNegative
              ? _t('Chuyển khoản', 'Transfer')
              : _t('Nhận tiền', 'Money received'),
          subtitle: description.isEmpty
              ? _t('Giao dịch chuyển khoản', 'Transfer transaction')
              : description,
          amount: _readNumericValue(data['amount']).toDouble(),
          timestamp: _readTimestamp(data['createdAt'] ?? data['timestamp']),
          type: 'transfer',
          isNegative: isNegative,
        ),
      );
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in collections[3]) {
      final Map<String, dynamic> data = doc.data();
      final String serviceName = _firstNonEmpty([
        data['serviceName'],
        data['provider'],
        data['billType'],
      ]);
      final String billCode = _firstNonEmpty([
        data['billCode'],
        data['customerCode'],
        data['invoiceCode'],
      ]);

      transactions.add(
        _HomeTransactionModel(
          id: doc.id,
          title: serviceName.isEmpty
              ? _t('Thanh toán hóa đơn', 'Bill payment')
              : '${_t('Thanh toán', 'Payment')} $serviceName',
          subtitle: billCode.isEmpty
              ? _t('Thanh toán dịch vụ', 'Service payment')
              : billCode,
          amount: _readNumericValue(data['amount']).toDouble(),
          timestamp: _readTimestamp(data['createdAt'] ?? data['timestamp']),
          type: 'bill_payment',
          isNegative: true,
        ),
      );
    }

    transactions.sort(
      (_HomeTransactionModel a, _HomeTransactionModel b) =>
          b.timestamp.compareTo(a.timestamp),
    );

    return transactions.take(5).toList();
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
      case 'bill_payment':
        return Icons.receipt_long_rounded;
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

  // --- DỮ LIỆU BANNER (Kiểm tra kỹ đuôi file máy bro nhé) ---
  final List<String> bannerImages = [
    'assets/images/banner1.jpg', // Sửa .png -> .jpg nếu cần
    'assets/images/banner2.jpg',
    'assets/images/banner3.jpg',
    'assets/images/banner4.jpg',
  ];

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
                    Column(
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
                        StreamBuilder<UserProfileData?>(
                          stream: _profileStream,
                          initialData:
                              UserFirestoreService.instance.latestProfile,
                          builder: (context, snapshot) {
                            final UserProfileData? profile =
                                snapshot.data ??
                                UserFirestoreService.instance.latestProfile;

                            if (!snapshot.hasError &&
                                snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                profile == null) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: ShimmerBox(
                                  width: 140,
                                  height: 22,
                                  radius: 8,
                                ),
                              );
                            }

                            final String name = snapshot.hasError
                                ? _t('Không tìm thấy user', 'User not found')
                                : ((profile?.fullname.isNotEmpty == true)
                                      ? profile!.fullname
                                      : _t('Khách hàng', 'Customer'));

                            return Text(
                              name.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
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
                    _buildBalanceCard(),
                    const SizedBox(height: 8),
                    _buildActionGrid(),
                    _buildBannerCarousel(),
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
                          Text(
                            _t('Lịch sử giao dịch >', 'Transaction history >'),
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 10.5,
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
    return StreamBuilder<UserProfileData?>(
      stream: _profileStream,
      initialData: UserFirestoreService.instance.latestProfile,
      builder: (context, profileSnapshot) {
        final UserProfileData? profile =
            profileSnapshot.data ?? UserFirestoreService.instance.latestProfile;
        final String? resolvedUserId = profile?.uid;

        if (resolvedUserId == null || resolvedUserId.isEmpty) {
          return _buildHiddenBalanceText();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(resolvedUserId)
              .snapshots(),
          builder: (context, userSnapshot) {
            final bool hasVipCard = _parseHasVipCard(
              userSnapshot.data?.data()?['hasVipCard'],
            );

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(resolvedUserId)
                  .collection('cards')
                  .snapshots(),
              builder: (context, cardsSnapshot) {
                if (cardsSnapshot.hasData) {
                  double standardBalance = 0;
                  double vipBalance = 0;

                  for (final doc in cardsSnapshot.data!.docs) {
                    final Map<String, dynamic> data = doc.data();
                    final dynamic rawBalance = data['balance'];

                    double balance = 0;
                    if (rawBalance is num) {
                      balance = rawBalance.toDouble();
                    } else if (rawBalance is String) {
                      balance = double.tryParse(rawBalance) ?? 0;
                    }

                    final String docId = doc.id.toLowerCase();
                    if (docId == 'standard') {
                      standardBalance = balance;
                    } else if (docId == 'vip') {
                      vipBalance = balance;
                    }
                  }

                  _lastKnownTotalBalance = hasVipCard
                      ? standardBalance + vipBalance
                      : standardBalance;
                  _hasLoadedBalance = true;
                }

                if (cardsSnapshot.connectionState == ConnectionState.waiting &&
                    !_hasLoadedBalance) {
                  return _buildBalanceSkeleton();
                }

                if (cardsSnapshot.hasError || userSnapshot.hasError) {
                  if (_hasLoadedBalance) {
                    return _buildBalanceText(_lastKnownTotalBalance);
                  }

                  final String error =
                      (cardsSnapshot.error ?? userSnapshot.error)
                          .toString()
                          .toLowerCase();
                  final bool networkError =
                      error.contains('unavailable') ||
                      error.contains('network') ||
                      error.contains('failed-host-lookup');

                  return Text(
                    networkError
                        ? _t('Mất kết nối mạng', 'No network connection')
                        : _t('Không tải được số dư', 'Unable to load balance'),
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }

                if (!_isBalanceVisible) {
                  return _buildHiddenBalanceText();
                }

                return _buildBalanceText(_lastKnownTotalBalance);
              },
            );
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

  Widget _buildBannerCarousel() {
    if (bannerImages.isEmpty) return const SizedBox();

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
                    items: bannerImages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final imagePath = entry.value;
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
                              Image.asset(
                                imagePath,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: Colors.grey[300],
                                      child: Center(
                                        child: Text(
                                          AppTranslations.getText(
                                            context,
                                            'banner_fallback_label',
                                          ),
                                        ),
                                      ),
                                    ),
                              ),
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(bannerImages.length, (index) {
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t("Mua sắm - Giải trí", "Shopping - Entertainment"),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int crossAxisCount = constraints.maxWidth >= 420 ? 5 : 4;

              return GridView.builder(
                itemCount: shoppingServices.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.84,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final ServiceModel service = shoppingServices[index];
                  return _buildShoppingPreviewItem(service);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingPreviewItem(ServiceModel service) {
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
    const Color darkBlue = Color(0xFF1A365D);
    const Color lightBlue = Color(0xFF42A5F5);
    const Color silverGrey = Color(0xFFCBD5E1);
    const Color shoppingPurple = Color(0xFF9C27B0);
    const Color emptyGrey = Color(0xFFE5E7EB);
    const Color textPrimary = Color(0xFF1F2937);
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
            ),
            _SpendingSlice(
              labelVi: 'Thanh toán hóa đơn',
              labelEn: 'Bill payment',
              value: billValue,
              color: lightBlue,
            ),
            _SpendingSlice(
              labelVi: 'Nạp ĐT',
              labelEn: 'Top up',
              value: phoneValue,
              color: silverGrey,
            ),
            _SpendingSlice(
              labelVi: 'Mua sắm - Giải trí',
              labelEn: 'Shopping & Entertainment',
              value: shoppingValue,
              color: shoppingPurple,
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
                  ),
                ]
              : displaySlices;

          return Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFEFF4FA)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF42A5F5).withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _t('Thống kê tiêu dùng', 'Spending statistics'),
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
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
                                  if (!event.isInterestedForInteractions ||
                                      pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null) {
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
                              final _SpendingSlice slice = pieSlices[index];
                              final Color sectionColor = isTouched
                                  ? Color.lerp(slice.color, Colors.black, 0.1)!
                                  : slice.color;

                              return PieChartSectionData(
                                value: slice.value,
                                color: sectionColor,
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
                      Container(
                        width: centerSpaceRadius * 2,
                        height: centerSpaceRadius * 2,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE9EEF4)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1A365D).withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                                  currencyFormatter.format(centerAmount),
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
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: displaySlices
                      .map(
                        (_SpendingSlice slice) => _buildSpendingLegendChip(
                          color: slice.color,
                          label: _t(slice.labelVi, slice.labelEn),
                          textColor: textPrimary,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpendingLegendChip({
    required Color color,
    required String label,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EEF4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
          const SizedBox(height: 10),
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
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final _HomeTransactionModel item = transactions[index];
                    final String dateText = DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(item.timestamp);
                    final String subtitle = item.subtitle.isEmpty
                        ? dateText
                        : '${item.subtitle} • $dateText';
                    final String amount =
                        '${item.isNegative ? '-' : '+'} ${_formatCurrency(item.amount)}';

                    return _transactionItem(
                      _iconForTransactionType(item.type),
                      item.title,
                      subtitle,
                      amount,
                      item.isNegative ? Colors.red : const Color(0xFF16A34A),
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
  });

  final String labelVi;
  final String labelEn;
  final double value;
  final Color color;
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
  });

  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime timestamp;
  final String type;
  final bool isNegative;
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
