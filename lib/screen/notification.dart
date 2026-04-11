import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/app_translations.dart';
import '../data/notification_firestore_service.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../widget/transaction_detail_popup.dart';

class TransactionNotificationModel {
  const TransactionNotificationModel({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.timestamp,
    required this.type,
    required this.isNegative,
    required this.data,
  });

  final String id;
  final String title;
  final String description;
  final num amount;
  final DateTime timestamp;
  final String type;
  final bool isNegative;
  final Map<String, dynamic> data;
}

class _NotificationMessageData {
  const _NotificationMessageData({
    required this.title,
    required this.body,
    required this.type,
    required this.amount,
    required this.isTransaction,
    required this.isNegative,
  });

  final String title;
  final String body;
  final String type;
  final num amount;
  final bool isTransaction;
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
          userRef.collection('bill_payment').get(),
          userRef.collection('withdraw').get(),
          userRef.collection('recent_transfers').get(),
        ]);

    final QuerySnapshot<Map<String, dynamic>> topUpSnapshot = snapshots[0];
    final QuerySnapshot<Map<String, dynamic>> billPaymentSnapshot =
        snapshots[1];
    final QuerySnapshot<Map<String, dynamic>> withdrawSnapshot = snapshots[2];
    final QuerySnapshot<Map<String, dynamic>> transferSnapshot = snapshots[3];

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
          data: <String, dynamic>{
            ...data,
            'id': doc.id,
            'title': title,
            'type': 'phone_recharge',
            'targetAccount': description,
          },
        ),
      );
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in billPaymentSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String billType = (data['billType'] ?? data['type'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final String billId = (data['customerCode'] ?? data['id'] ?? '')
          .toString()
          .trim();

      String serviceLabel;
      switch (billType) {
        case 'electric':
          serviceLabel = _t('Tiền điện', 'Electricity');
          break;
        case 'water':
          serviceLabel = _t('Tiền nước', 'Water');
          break;
        case 'internet':
          serviceLabel = _t('Internet', 'Internet');
          break;
        case 'mobile':
        case 'mobile_postpaid':
          serviceLabel = _t('Di động', 'Mobile');
          break;
        default:
          serviceLabel = _t('Hóa đơn', 'Bill');
      }

      allTransactions.add(
        TransactionNotificationModel(
          id: doc.id,
          title: '${_t('Thanh toán', 'Payment')} $serviceLabel',
          description: billId.isEmpty
              ? _t('Không có mã khách hàng', 'No customer code')
              : billId,
          amount: _readAmount(data['amount']),
          timestamp: _readTimestamp(data['createdAt'] ?? data['timestamp']),
          type: 'bill_payment',
          isNegative: true,
          data: <String, dynamic>{
            ...data,
            'id': doc.id,
            'title': '${_t('Thanh toán', 'Payment')} $serviceLabel',
            'type': 'bill_payment',
            'targetAccount': billId,
            'serviceName': serviceLabel,
          },
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
          data: <String, dynamic>{
            ...data,
            'id': doc.id,
            'title': _t('Rút tiền mặt', 'Cash withdrawal'),
            'type': 'withdraw',
            'targetAccount': withdrawCode,
            'transactionCode': withdrawCode,
          },
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
          data: <String, dynamic>{
            ...data,
            'id': doc.id,
            'title': _t('Chuyển khoản', 'Transfer'),
            'type': 'transfer',
            'targetAccount': accountNumber,
            'serviceName': recipientName,
          },
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

  String _extractPhoneFromBody(String rawBody) {
    final RegExpMatch? phoneMatch = RegExp(r'(\d{8,15})').firstMatch(rawBody);
    return (phoneMatch?.group(1) ?? '').trim();
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

  bool _isTransactionType(String normalizedType) {
    return normalizedType == 'phone_recharge' ||
        normalizedType == 'withdraw' ||
        normalizedType == 'transfer' ||
        normalizedType == 'bill_payment' ||
        normalizedType == 'shopping' ||
        normalizedType == 'transaction';
  }

  String _readLegacyTitle(Map<String, dynamic> data) {
    final String raw = (data['title'] ?? '').toString().trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return _t('Thông báo mới', 'New notification');
  }

  String _readLegacyBody(Map<String, dynamic> data) {
    final String raw = (data['body'] ?? '').toString().trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return _t('Không có mô tả', 'No description');
  }

  String _resolveNotificationType(Map<String, dynamic> data) {
    return (data['type'] ?? '').toString().trim().toLowerCase();
  }

  _NotificationMessageData _buildNotificationMessageData(
    Map<String, dynamic> data,
  ) {
    final String resolvedType = _resolveNotificationType(data);
    final num amount = _readAmount(data['amount']);
    final String amountText = amount > 0 ? _formatAmount(amount) : '0';
    final String legacyTitle = _readLegacyTitle(data);
    final String legacyBody = _readLegacyBody(data);

    if (resolvedType.isEmpty) {
      return _NotificationMessageData(
        title: legacyTitle,
        body: legacyBody,
        type: '',
        amount: amount,
        isTransaction: amount > 0,
        isNegative: data['isNegative'] == true || amount > 0,
      );
    }

    if (resolvedType == 'shopping') {
      final String serviceName = _firstNonEmpty(<dynamic>[
        data['serviceName'],
        data['provider'],
        AppTranslations.getText(context, 'unknown'),
      ]);
      return _NotificationMessageData(
        title: AppTranslations.getText(context, 'payment_successful'),
        body:
            '${AppTranslations.getText(context, 'paid_for')} $amountText VND ${AppTranslations.getText(context, 'for_service')} $serviceName',
        type: resolvedType,
        amount: amount,
        isTransaction: true,
        isNegative: true,
      );
    }

    if (resolvedType == 'phone_recharge') {
      final String target = _firstNonEmpty(<dynamic>[
        data['targetAccount'],
        data['phoneNumber'],
        _extractPhoneFromBody((data['body'] ?? '').toString()),
      ]);
      final String targetText = target.isEmpty
          ? AppTranslations.getText(context, 'unknown')
          : target;
      return _NotificationMessageData(
        title: AppTranslations.getText(context, 'success_title'),
        body:
            '${AppTranslations.getText(context, 'top_up_for')} $targetText - $amountText VND',
        type: resolvedType,
        amount: amount,
        isTransaction: true,
        isNegative: true,
      );
    }

    if (resolvedType == 'withdraw') {
      final String code = _firstNonEmpty(<dynamic>[
        data['transactionCode'],
        data['withdrawCode'],
        data['targetAccount'],
      ]);
      return _NotificationMessageData(
        title: AppTranslations.getText(context, 'withdraw_notification_title'),
        body: AppTranslations.getTextWithParams(
          context,
          'withdraw_notification_body',
          <String, String>{
            'code': code.isEmpty ? '-' : code,
            'amount': amountText,
          },
        ),
        type: resolvedType,
        amount: amount,
        isTransaction: true,
        isNegative: true,
      );
    }

    if (resolvedType == 'transfer') {
      final String receiver = _firstNonEmpty(<dynamic>[
        data['serviceName'],
        data['receiverName'],
        data['recipientName'],
        data['targetAccount'],
      ]);
      final String receiverText = receiver.isEmpty
          ? AppTranslations.getText(context, 'unknown')
          : receiver;
      return _NotificationMessageData(
        title: AppTranslations.getText(context, 'transfer_success_title'),
        body:
            '${AppTranslations.getText(context, 'transferred_to')} $receiverText - $amountText VND',
        type: resolvedType,
        amount: amount,
        isTransaction: true,
        isNegative: true,
      );
    }

    return _NotificationMessageData(
      title: legacyTitle,
      body: legacyBody,
      type: resolvedType,
      amount: amount,
      isTransaction: _isTransactionType(resolvedType) || amount > 0,
      isNegative: data['isNegative'] == true || amount > 0,
    );
  }

  String _inferTransactionType({
    required String normalizedType,
    required Map<String, dynamic> data,
  }) {
    final String fromData = _firstNonEmpty(<dynamic>[
      data['transactionType'],
      data['activityType'],
      data['paymentType'],
      data['type'],
    ]).toLowerCase();

    if (fromData.isNotEmpty && fromData != 'transaction') {
      return fromData;
    }

    if (normalizedType != 'transaction') {
      return normalizedType;
    }

    if (data['phoneNumber'] != null) {
      return 'phone_recharge';
    }
    if (data['withdrawCode'] != null) {
      return 'withdraw';
    }
    if (data['serviceId'] != null || data['serviceName'] != null) {
      return 'shopping';
    }
    return 'transfer';
  }

  Map<String, dynamic> _buildPopupDataFromNotification({
    required String id,
    required String type,
    required String title,
    required String body,
    required num amount,
    required DateTime timestamp,
    required Map<String, dynamic> data,
  }) {
    final String normalizedType = type.trim().toLowerCase();
    final String popupType = _inferTransactionType(
      normalizedType: normalizedType,
      data: data,
    );

    final String targetAccount = _firstNonEmpty(<dynamic>[
      data['targetAccount'],
      data['toAccountNumber'],
      data['accountNumber'],
      data['phoneNumber'],
      data['receiverName'],
      data['recipientName'],
      _extractPhoneFromBody(body),
    ]);

    final String transactionCode = _firstNonEmpty(<dynamic>[
      data['transactionCode'],
      data['withdrawCode'],
      data['code'],
      data['relatedId'],
      id,
    ]);

    final String serviceName = _firstNonEmpty(<dynamic>[
      data['serviceName'],
      data['provider'],
      title,
    ]);

    return <String, dynamic>{
      ...data,
      'id': id,
      'type': popupType,
      'title': title,
      'body': body,
      'amount': amount,
      'timestamp': timestamp,
      'targetAccount': targetAccount,
      'transactionCode': transactionCode,
      'serviceName': serviceName,
      'isNegative': true,
    };
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
            final DateTime timestamp = _readTimestamp(
              data['timestamp'] ?? data['createdAt'],
            );
            final bool isRead = data['isRead'] == true;
            final _NotificationMessageData messageData =
                _buildNotificationMessageData(data);
            final bool isTransaction = messageData.isTransaction;
            final Map<String, dynamic> popupData =
                _buildPopupDataFromNotification(
                  id: docs[index].id,
                  type: messageData.type,
                  title: messageData.title,
                  body: messageData.body,
                  amount: messageData.amount,
                  timestamp: timestamp,
                  data: data,
                );

            final bool isNegative = messageData.isNegative;
            final String normalizedType = messageData.type.trim().toLowerCase();
            final bool isSystem =
                normalizedType == 'system' ||
                normalizedType == 'announcement' ||
                normalizedType.isEmpty;

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

            final bool hasAmount = messageData.amount > 0;
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
                  onTap: isTransaction
                      ? () {
                          TransactionDetailPopup.show(context, popupData);
                        }
                      : null,
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
                                messageData.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${messageData.body} • ${_formatTimestamp(timestamp)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
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
                              '$amountSign ${_formatAmount(messageData.amount)} VND',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.poppins(
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
                  onTap: () {
                    TransactionDetailPopup.show(context, item.data);
                  },
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
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.description} • ${_formatTimestamp(item.timestamp)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
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
                            style: GoogleFonts.poppins(
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
          style: GoogleFonts.poppins(
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
                            style: GoogleFonts.poppins(
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
