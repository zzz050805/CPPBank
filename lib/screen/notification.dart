import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/notification_firestore_service.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';

class TransactionNotificationModel {
  const TransactionNotificationModel({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.timestamp,
    required this.type,
    required this.isNegative,
  });

  final String id;
  final String title;
  final String description;
  final num amount;
  final DateTime timestamp;
  final String type;
  final bool isNegative;
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const Color _activeTabColor = Color(0xFF000DC0);

  final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  int _selectedTabIndex = 0;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  List<String> get tabs => <String>[
    _t('Giao dịch', 'Transactions'),
    _t('Ưu đãi', 'Offers'),
    _t('Thông báo', 'Notifications'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialTabIndex <= 0) {
      _selectedTabIndex = 0;
    } else if (widget.initialTabIndex >= 2) {
      _selectedTabIndex = 2;
    } else {
      _selectedTabIndex = widget.initialTabIndex;
    }
    unawaited(markAllAsRead());
  }

  @override
  void dispose() {
    unawaited(markAllAsRead());
    super.dispose();
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

  num _readAmount(dynamic value) {
    if (value is num) {
      return value;
    }

    if (value is String) {
      final String trimmed = value.trim();
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

  Future<List<TransactionNotificationModel>> fetchAllTransactions() async {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      return <TransactionNotificationModel>[];
    }

    final DocumentReference<Map<String, dynamic>> userRef = FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid);

    final List<QuerySnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait(<Future<QuerySnapshot<Map<String, dynamic>>>>[
          userRef.collection('phone_recharge').get(),
          userRef.collection('withdraw').get(),
          userRef.collection('recent_transfers').get(),
        ]);

    final QuerySnapshot<Map<String, dynamic>> topUpSnapshot = snapshots[0];
    final QuerySnapshot<Map<String, dynamic>> withdrawSnapshot = snapshots[1];
    final QuerySnapshot<Map<String, dynamic>> transferSnapshot = snapshots[2];

    final List<TransactionNotificationModel> allTransactions =
        <TransactionNotificationModel>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in topUpSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String provider = (data['provider'] ?? '').toString().trim();
      final String title = provider.isEmpty
          ? _t('Nạp tiền điện thoại', 'Phone top-up')
          : '${_t('Nạp ĐT', 'Top-up')} $provider';
      final String description = (data['phoneNumber'] ?? '').toString().trim();

      allTransactions.add(
        TransactionNotificationModel(
          id: doc.id,
          title: title,
          description: description.isEmpty
              ? _t('Không có mô tả', 'No description')
              : description,
          amount: _readAmount(data['amount']),
          timestamp: _readTimestamp(data['createdAt'] ?? data['timestamp']),
          type: 'phone_recharge',
          isNegative: true,
        ),
      );
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in withdrawSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String withdrawCode = (data['withdrawCode'] ?? data['code'] ?? '')
          .toString()
          .trim();

      allTransactions.add(
        TransactionNotificationModel(
          id: doc.id,
          title: _t('Rút tiền mặt', 'Cash withdrawal'),
          description: withdrawCode.isEmpty
              ? _t('Không có mã giao dịch', 'No transaction code')
              : withdrawCode,
          amount: _readAmount(data['amount']),
          timestamp: _readTimestamp(data['createdAt'] ?? data['timestamp']),
          type: 'withdraw',
          isNegative: true,
        ),
      );
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in transferSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String recipientName = (data['accountName'] ?? '')
          .toString()
          .trim();
      final String accountNumber = (data['accountNumber'] ?? '')
          .toString()
          .trim();
      final String description = recipientName.isNotEmpty
          ? recipientName
          : (accountNumber.isNotEmpty
                ? accountNumber
                : _t('Không có thông tin', 'No details'));

      allTransactions.add(
        TransactionNotificationModel(
          id: doc.id,
          title: _t('Chuyển khoản', 'Transfer'),
          description: description,
          amount: _readAmount(data['amount']),
          timestamp: _readTimestamp(data['timestamp']),
          type: 'transfer',
          isNegative: true,
        ),
      );
    }

    allTransactions.sort(
      (TransactionNotificationModel a, TransactionNotificationModel b) =>
          b.timestamp.compareTo(a.timestamp),
    );

    return allTransactions;
  }

  String _formatAmount(num value) {
    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value).replaceAll(',', '.');
  }

  String _formatTimestamp(DateTime timestamp) {
    return _dateTimeFormat.format(timestamp);
  }

  String _extractProviderFromTitle(String rawTitle) {
    final RegExpMatch? viMatch = RegExp(
      r'^\s*Nạp\s*ĐT\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(rawTitle);
    if (viMatch != null) {
      return (viMatch.group(1) ?? '').trim();
    }

    final RegExpMatch? enMatch = RegExp(
      r'^\s*Top-up\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(rawTitle);
    if (enMatch != null) {
      return (enMatch.group(1) ?? '').trim();
    }

    return '';
  }

  String _extractPhoneFromBody(String rawBody) {
    final RegExpMatch? phoneMatch = RegExp(r'(\d{8,15})').firstMatch(rawBody);
    return (phoneMatch?.group(1) ?? '').trim();
  }

  String _localizedNotificationTitle({
    required String type,
    required String rawTitle,
    required Map<String, dynamic> data,
  }) {
    final String normalizedType = type.trim().toLowerCase();

    if (normalizedType == 'phone_recharge') {
      final String providerFromData = (data['provider'] ?? '')
          .toString()
          .trim();
      final String providerFromTitle = _extractProviderFromTitle(rawTitle);
      final String provider = providerFromData.isNotEmpty
          ? providerFromData
          : providerFromTitle;

      return provider.isEmpty
          ? _t('Nạp tiền điện thoại', 'Phone top-up')
          : '${_t('Nạp ĐT', 'Top-up')} $provider';
    }

    if (normalizedType == 'withdraw') {
      return _t('Rút tiền mặt', 'Cash withdrawal');
    }

    if (normalizedType == 'transfer') {
      return _t('Chuyển khoản', 'Transfer');
    }

    return rawTitle.isEmpty
        ? _t('Thông báo mới', 'New notification')
        : rawTitle;
  }

  String _localizedNotificationBody({
    required String type,
    required String rawBody,
    required num amount,
    required Map<String, dynamic> data,
  }) {
    final String normalizedType = type.trim().toLowerCase();

    if (normalizedType == 'phone_recharge') {
      final String phoneFromData = (data['phoneNumber'] ?? '')
          .toString()
          .trim();
      final String phoneFromBody = _extractPhoneFromBody(rawBody);
      final String phone = phoneFromData.isNotEmpty
          ? phoneFromData
          : phoneFromBody;
      final String amountText = amount > 0
          ? '${_formatAmount(amount)} VND'
          : '';

      if (phone.isNotEmpty && amountText.isNotEmpty) {
        return '${_t('Phone', 'Phone')} $phone - $amountText';
      }
      if (phone.isNotEmpty) {
        return '${_t('Phone', 'Phone')} $phone';
      }
    }

    if (rawBody.isEmpty) {
      return _t('Không có mô tả', 'No description');
    }

    return rawBody.replaceAll('SĐT', _t('SĐT', 'Phone'));
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'phone_recharge':
        return Icons.phone_android_rounded;
      case 'withdraw':
        return Icons.atm_rounded;
      case 'transfer':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Future<void> markAllAsRead() async {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      return;
    }
    await NotificationFirestoreService.instance.markAllAsRead(uid);
  }

  Widget _buildNotificationMessagesTab() {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      return Center(
        child: Text(_t('Bạn chưa đăng nhập', 'You are not logged in')),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NotificationFirestoreService.instance
          .userNotificationsRef(uid)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (BuildContext context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${_t('Không tải được thông báo', 'Unable to load notifications')}: ${snapshot.error}',
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (docs.isEmpty) {
          return Center(
            child: Text(_t('Chưa có thông báo nào', 'No notifications yet')),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          itemCount: docs.length,
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> data = docs[index].data();
            final String rawTitle =
                (data['title'] ?? _t('Thông báo mới', 'New notification'))
                    .toString()
                    .trim();
            final String rawBody = (data['body'] ?? '').toString().trim();
            final DateTime timestamp = _readTimestamp(data['timestamp']);
            final bool isRead = data['isRead'] == true;
            final String type = (data['type'] ?? '').toString();
            final num amount = _readAmount(data['amount']);
            final String title = _localizedNotificationTitle(
              type: type,
              rawTitle: rawTitle,
              data: data,
            );
            final String body = _localizedNotificationBody(
              type: type,
              rawBody: rawBody,
              amount: amount,
              data: data,
            );

            final bool isNegative =
                type == 'phone_recharge' ||
                type == 'withdraw' ||
                type == 'transfer' ||
                type == 'bill_payment' ||
                type == 'transaction';
            final bool isSystem =
                type == 'system' || type == 'announcement' || type.isEmpty;

            final Color iconColor = isSystem
                ? const Color(0xFF0A67D8)
                : (isNegative
                      ? const Color(0xFF1E40AF)
                      : const Color(0xFF0284C7));
            final Color iconBgColor = isSystem
                ? const Color(0xFF0A67D8).withValues(alpha: 0.12)
                : (isNegative
                      ? const Color(0xFF1E40AF).withValues(alpha: 0.14)
                      : const Color(0xFF0284C7).withValues(alpha: 0.14));

            final bool hasAmount = amount > 0;
            final String amountSign = isNegative ? '-' : '+';
            final Color amountColor = isNegative
                ? const Color(0xFF1E40AF)
                : const Color(0xFF0284C7);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isRead
                          ? Colors.white
                          : const Color(0xFF0A67D8).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCE7FB)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: iconBgColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_active_rounded,
                                color: iconColor,
                              ),
                            ),
                            if (!isRead)
                              const Positioned(
                                left: -2,
                                top: -2,
                                child: SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0xFF1E40AF),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$body • ${_formatTimestamp(timestamp)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasAmount) ...[
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 92),
                            child: Text(
                              '$amountSign ${_formatAmount(amount)} VND',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: amountColor,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildTransactionTab() {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      return Center(
        child: Text(_t('Bạn chưa đăng nhập', 'You are not logged in')),
      );
    }

    return FutureBuilder<List<TransactionNotificationModel>>(
      future: fetchAllTransactions(),
      builder: (BuildContext context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${_t('Không tải được lịch sử giao dịch', 'Unable to load transaction history')}: ${snapshot.error}',
            ),
          );
        }

        final List<TransactionNotificationModel> transactions =
            snapshot.data ?? <TransactionNotificationModel>[];

        if (transactions.isEmpty) {
          return Center(
            child: Text(_t('Chưa có giao dịch nào', 'No transactions yet')),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          itemCount: transactions.length,
          itemBuilder: (BuildContext context, int index) {
            final TransactionNotificationModel item = transactions[index];
            final String sign = item.isNegative ? '-' : '+';
            final Color amountColor = item.isNegative
                ? const Color(0xFF1E40AF)
                : const Color(0xFF0284C7);
            final Color iconBgColor = item.isNegative
                ? const Color(0xFF1E40AF).withValues(alpha: 0.14)
                : const Color(0xFF0284C7).withValues(alpha: 0.14);
            final Color iconColor = item.isNegative
                ? const Color(0xFF1E40AF)
                : const Color(0xFF0284C7);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCE7FB)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconForType(item.type),
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.description} • ${_formatTimestamp(item.timestamp)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 110),
                          child: Text(
                            '$sign ${_formatAmount(item.amount)} VND',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: amountColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _t('Thông báo', 'Notifications'),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: Colors.white,
            child: Row(
              children: List.generate(tabs.length, (int index) {
                final bool isActive = _selectedTabIndex == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTabIndex = index),
                    child: SizedBox(
                      height: 44,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            tabs[index],
                            style: TextStyle(
                              color: isActive
                                  ? _activeTabColor
                                  : const Color(0xFF374151),
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: isActive ? 50 : 0,
                            height: 2.2,
                            color: _activeTabColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: <Widget>[
          _buildTransactionTab(),
          Center(child: Text(_t('Nội dung Ưu đãi', 'Offers content'))),
          _buildNotificationMessagesTab(),
        ],
      ),
    );
  }
}
