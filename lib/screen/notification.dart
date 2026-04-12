import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/notification_firestore_service.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../shoppingservice/shopping_store_screen.dart';
import '../widget/ccp_app_bar.dart';
import '../widget/transaction_detail_popup.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const Color _activeTabColor = Color(0xFF000DC0);
  final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  String _t(String vi, String en) => AppText.tr(context, vi, en);

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

  DateTime _readTimestamp(dynamic rawTimestamp) {
    if (rawTimestamp is Timestamp) {
      return rawTimestamp.toDate();
    }
    if (rawTimestamp is DateTime) {
      return rawTimestamp;
    }
    if (rawTimestamp is int) {
      if (rawTimestamp.abs() < 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(rawTimestamp * 1000);
      }
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

      final String digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9.-]'), '');
      if (digitsOnly.isEmpty) {
        return 0;
      }
      return num.tryParse(digitsOnly) ?? 0;
    }

    return 0;
  }

  String _formatAmount(num value) {
    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value).replaceAll(',', '.');
  }

  bool _isPromotionNotification(Map<String, dynamic> data) {
    final String type = (data['type'] ?? '').toString().trim().toLowerCase();
    final String category = (data['category'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    return type == 'uu_dai' ||
        type == 'promotion' ||
        type == 'shopping_discount' ||
        category == 'promotion';
  }

  String _resolveTransactionType(Map<String, dynamic> data) {
    final String explicit = (data['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (explicit == 'phone_recharge' ||
        explicit == 'withdraw' ||
        explicit == 'transfer' ||
        explicit == 'bill_payment' ||
        explicit == 'shopping') {
      return explicit;
    }

    if (data['phoneNumber'] != null) {
      return 'phone_recharge';
    }
    if (data['withdrawCode'] != null) {
      return 'withdraw';
    }
    if (data['toCardNumber'] != null ||
        data['card_number'] != null ||
        data['cardNumber'] != null ||
        data['toAccountNumber'] != null ||
        data['accountNumber'] != null) {
      return 'transfer';
    }
    if (data['billType'] != null || data['customerCode'] != null) {
      return 'bill_payment';
    }

    return 'transaction';
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

  String _resolveNotificationTitle(Map<String, dynamic> data) {
    final String fallback =
        (data['title'] ?? _t('Thông báo mới', 'New notification'))
            .toString()
            .trim();

    final String titleKey = (data['titleKey'] ?? '').toString().trim();
    final String serviceTypeKey = (data['serviceTypeKey'] ?? '').toString();
    final String billType = (data['billType'] ?? data['serviceType'] ?? '')
        .toString();

    final bool isBillPaymentNotification =
        (data['type'] ?? '').toString().trim().toLowerCase() == 'payment' &&
        billType.trim().isNotEmpty;
    final bool needsSpecificTitle =
        titleKey == 'payment_success_specific' || isBillPaymentNotification;
    if (!needsSpecificTitle) {
      return fallback;
    }

    final String resolvedServiceKey = serviceTypeKey.trim().isNotEmpty
        ? serviceTypeKey
        : _billTypeToTextKey(billType);
    final String serviceName = AppText.text(context, resolvedServiceKey);
    return AppText.paymentSuccessSpecificTitle(
      context,
      serviceName: serviceName,
    );
  }

  IconData _iconForNotification({
    required bool isPromotion,
    required bool hasAmount,
  }) {
    if (isPromotion) {
      return Icons.local_offer_rounded;
    }
    if (hasAmount) {
      return Icons.receipt_long_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  Map<String, dynamic> _buildPopupData({
    required String id,
    required Map<String, dynamic> data,
    required String title,
    required String body,
    required DateTime timestamp,
  }) {
    final num amount = _readAmount(data['amount']);

    final String targetAccount =
        (data['targetAccount'] ??
                data['toCardNumber'] ??
                data['card_number'] ??
                data['cardNumber'] ??
                data['toAccountNumber'] ??
                data['accountNumber'] ??
                data['phoneNumber'] ??
                '')
            .toString()
            .trim();

    final String transactionCode =
        (data['transactionCode'] ??
                data['withdrawCode'] ??
                data['code'] ??
                data['relatedId'] ??
                id)
            .toString()
            .trim();

    return <String, dynamic>{
      ...data,
      'id': id,
      'type': _resolveTransactionType(data),
      'title': title,
      'body': body,
      'amount': amount,
      'timestamp': timestamp,
      'targetAccount': targetAccount,
      'transactionCode': transactionCode,
      'serviceName': (data['serviceName'] ?? '').toString().trim(),
      'isNegative': data['isNegative'] == true || amount > 0,
    };
  }

  Future<void> _markAsRead(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (doc.data()['isRead'] == true) {
      return;
    }
    await doc.reference.set(<String, dynamic>{
      'isRead': true,
    }, SetOptions(merge: true));
  }

  Future<void> _openOffer(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final Map<String, dynamic> data = doc.data();
    final String serviceId = (data['serviceId'] ?? '').toString().trim();

    if (serviceId.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Không tìm thấy dịch vụ ưu đãi', 'Promotion service not found'),
          ),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: RouteSettings(
          arguments: <String, dynamic>{
            'isFromNotification': true,
            'targetServiceId': serviceId,
          },
        ),
        builder: (_) => ShoppingStoreScreen(
          isFromNotification: true,
          targetServiceId: serviceId,
        ),
      ),
    );

    await _markAsRead(doc);
  }

  Widget _buildRealtimeNotificationList({required bool promotionsOnly}) {
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
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
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

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs =
                snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                allDocs
                    .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                      final bool isPromotion = _isPromotionNotification(
                        doc.data(),
                      );
                      return promotionsOnly ? isPromotion : !isPromotion;
                    })
                    .toList(growable: false);

            if (docs.isEmpty) {
              return Center(
                child: Text(
                  promotionsOnly
                      ? _t('Chưa có ưu đãi mới', 'No new promotions')
                      : _t('Chưa có giao dịch mới', 'No new transactions'),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: docs.length,
              itemBuilder: (BuildContext context, int index) {
                final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                    docs[index];
                final Map<String, dynamic> data = doc.data();
                final DateTime timestamp = _readTimestamp(
                  data['timestamp'] ?? data['createdAt'],
                );
                final bool isRead = data['isRead'] == true;

                final String title = _resolveNotificationTitle(data);
                final String body =
                    (data['body'] ?? _t('Không có mô tả', 'No description'))
                        .toString()
                        .trim();
                final num amount = _readAmount(data['amount']);
                final bool hasAmount = amount > 0 && !promotionsOnly;
                final bool isNegative = data['isNegative'] == true || hasAmount;
                final Color amountColor = isNegative
                    ? const Color(0xFF1E40AF)
                    : const Color(0xFF0284C7);

                final Color iconColor = promotionsOnly
                    ? const Color(0xFF7C3AED)
                    : (isNegative
                          ? const Color(0xFF1E40AF)
                          : const Color(0xFF0284C7));
                final Color iconBgColor = promotionsOnly
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.13)
                    : (isNegative
                          ? const Color(0xFF1E40AF).withValues(alpha: 0.14)
                          : const Color(0xFF0284C7).withValues(alpha: 0.14));

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        if (promotionsOnly) {
                          await _openOffer(doc);
                          return;
                        }

                        final Map<String, dynamic> popupData = _buildPopupData(
                          id: doc.id,
                          data: data,
                          title: title,
                          body: body,
                          timestamp: timestamp,
                        );
                        TransactionDetailPopup.show(context, popupData);
                        await _markAsRead(doc);
                      },
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
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _iconForNotification(
                                      isPromotion: promotionsOnly,
                                      hasAmount: hasAmount,
                                    ),
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
                                children: <Widget>[
                                  Text(
                                    title,
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
                                    '$body • ${_dateTimeFormat.format(timestamp)}',
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
                            if (hasAmount) ...<Widget>[
                              const SizedBox(width: 10),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 104,
                                ),
                                child: Text(
                                  '- ${_formatAmount(amount)} VND',
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

  @override
  Widget build(BuildContext context) {
    final int initialTabIndex = widget.initialTabIndex <= 0 ? 0 : 1;

    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: CCPAppBar(
          title: _t('Thông báo', 'Notifications'),
          onBackPressed: () => Navigator.of(context).pop(),
          backgroundColor: Colors.white,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: Container(
              color: Colors.white,
              child: TabBar(
                indicatorColor: _activeTabColor,
                indicatorWeight: 2.4,
                labelColor: _activeTabColor,
                unselectedLabelColor: const Color(0xFF374151),
                labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: <Widget>[
                  Tab(text: _t('Giao dịch', 'Transactions')),
                  Tab(text: _t('Ưu đãi', 'Offers')),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _buildRealtimeNotificationList(promotionsOnly: false),
            _buildRealtimeNotificationList(promotionsOnly: true),
          ],
        ),
      ),
    );
  }
}
