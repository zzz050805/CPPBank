import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_translations.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/notification_service.dart';
import '../widget/pin_popup.dart';

class ConfirmTopUpScreen extends StatefulWidget {
  final String selectedAmount;
  final String selectedProvider;
  final String selectedPhoneNumber;

  const ConfirmTopUpScreen({
    super.key,
    required this.selectedAmount,
    required this.selectedProvider,
    required this.selectedPhoneNumber,
  });

  @override
  State<ConfirmTopUpScreen> createState() => _ConfirmTopUpScreenState();
}

class _ConfirmTopUpScreenState extends State<ConfirmTopUpScreen> {
  static const String _otherAmountKey = '__other_amount__';
  bool _isSubmitting = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  String _amountDisplay() {
    if (widget.selectedAmount == _otherAmountKey) {
      return _t('Số khác', 'Other');
    }
    return '${widget.selectedAmount} VND';
  }

  int _parseAmountValue(String rawAmount) {
    final String digitsOnly = rawAmount.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return 0;
    }
    return int.tryParse(digitsOnly) ?? 0;
  }

  num _readNumericBalance(dynamic rawBalance) {
    if (rawBalance is num) {
      return rawBalance;
    }

    if (rawBalance is String) {
      final String trimmed = rawBalance.trim();
      if (trimmed.isEmpty) {
        return 0;
      }

      final num? direct = num.tryParse(trimmed);
      if (direct != null) {
        return direct;
      }

      final String digits = trimmed.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) {
        return 0;
      }
      return num.tryParse(digits) ?? 0;
    }

    return 0;
  }

  bool _parseHasVipCard(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  String _resolveTransactionUid() {
    final String? fromAuth = FirebaseAuth.instance.currentUser?.uid;
    if (fromAuth != null && fromAuth.isNotEmpty) {
      return fromAuth;
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

    return '';
  }

  Future<void> _handleConfirmRecharge() async {
    if (_isSubmitting) {
      return;
    }

    // ignore: avoid_print
    print('--- BẮT ĐẦU GIAO DỊCH ---');

    final int amount = _parseAmountValue(widget.selectedAmount);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Số tiền nạp không hợp lệ.', 'Invalid top-up amount.'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    // ignore: avoid_print
    print('User UID: ${user?.uid}');
    // ignore: avoid_print
    print(
      'Fallback UID: ${UserFirestoreService.instance.currentUserDocId ?? UserFirestoreService.instance.latestProfile?.uid}',
    );

    final String uid = _resolveTransactionUid();
    // ignore: avoid_print
    print('Resolved UID dùng để giao dịch: $uid');
    // ignore: avoid_print
    print('Firebase projectId hiện tại: ${Firebase.app().options.projectId}');

    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Lỗi: Chưa đăng nhập', 'Error: Not logged in')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference<Map<String, dynamic>> userRef = firestore
        .collection('users')
        .doc(uid);
    final DocumentReference<Map<String, dynamic>> rechargeRef = userRef
        .collection('phone_recharge')
        .doc();
    final DocumentReference<Map<String, dynamic>> notificationRef = userRef
        .collection('notifications')
        .doc();

    try {
      // ignore: avoid_print
      print('Đang tìm document user: users/$uid');
      final bool ensured = await UserFirestoreService.instance
          .ensureUserDataExists(userId: uid);
      // ignore: avoid_print
      print('ensureUserDataExists(users/$uid) => $ensured');
      // ignore: avoid_print
      print('Số tiền cần trừ: $amount');

      // Bắt buộc await để transaction hoàn tất trước khi điều hướng màn hình.
      await firestore.runTransaction((transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> userDoc = await transaction
            .get(userRef);

        if (!userDoc.exists) {
          throw Exception('Không tìm thấy document user: users/$uid');
        }

        // ignore: avoid_print
        print('Số dư hiện tại trên Firestore: ${userDoc.data()?['balance']}');

        final Map<String, dynamic> userData =
            userDoc.data() ?? <String, dynamic>{};
        final bool hasVipCard = _parseHasVipCard(userData['hasVipCard']);
        final DocumentReference<Map<String, dynamic>> standardCardRef = userRef
            .collection('cards')
            .doc('standard');
        final DocumentReference<Map<String, dynamic>> vipCardRef = userRef
            .collection('cards')
            .doc('vip');

        final DocumentSnapshot<Map<String, dynamic>> standardCardSnap =
            await transaction.get(standardCardRef);
        final DocumentSnapshot<Map<String, dynamic>> vipCardSnap =
            await transaction.get(vipCardRef);

        num standardBalance = _readNumericBalance(
          standardCardSnap.data()?['balance'],
        );
        num vipBalance = _readNumericBalance(vipCardSnap.data()?['balance']);
        final num cardsBalance = hasVipCard
            ? (standardBalance + vipBalance)
            : standardBalance;
        final num userBalance = _readNumericBalance(userData['balance']);

        final bool hasAnyCardBalance = cardsBalance > 0;
        final num currentBalance = hasAnyCardBalance
            ? cardsBalance
            : userBalance;

        if (currentBalance < amount) {
          throw Exception('Số dư không đủ');
        }

        num newBalance;

        if (hasAnyCardBalance) {
          if (standardBalance >= amount) {
            standardBalance -= amount;
          } else {
            final num remaining = amount - standardBalance;
            standardBalance = 0;

            if (!hasVipCard || vipBalance < remaining) {
              throw Exception('Số dư không đủ');
            }
            vipBalance -= remaining;
          }

          newBalance = hasVipCard
              ? (standardBalance + vipBalance)
              : standardBalance;

          transaction.set(standardCardRef, <String, dynamic>{
            'balance': standardBalance,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          if (hasVipCard) {
            transaction.set(vipCardRef, <String, dynamic>{
              'balance': vipBalance,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        } else {
          newBalance = userBalance - amount;
        }

        // ignore: avoid_print
        print('Đang trừ tiền...');
        transaction.set(userRef, <String, dynamic>{
          'balance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // ignore: avoid_print
        print('Đang chuẩn bị ghi vào: users/$uid/phone_recharge/ID_TU_DONG');
        // ignore: avoid_print
        print('Đường dẫn thực tế: users/$uid/phone_recharge/${rechargeRef.id}');
        transaction.set(rechargeRef, <String, dynamic>{
          'uid': uid,
          'phoneNumber': widget.selectedPhoneNumber.trim(),
          'provider': widget.selectedProvider.trim(),
          'amount': amount,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'success',
          'type': 'topup',
        });

        transaction.set(notificationRef, <String, dynamic>{
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'phone_recharge',
          'isNegative': true,
          'serviceName': widget.selectedProvider.trim(),
          'targetAccount': widget.selectedPhoneNumber.trim(),
          'transactionCode': rechargeRef.id,
          'status': 'success',
          'isRead': false,
          'relatedId': rechargeRef.id,
          'amount': amount,
        });
      });

      final DocumentSnapshot<Map<String, dynamic>> savedRecharge =
          await rechargeRef.get();
      // ignore: avoid_print
      print('Sau commit, document tồn tại: ${savedRecharge.exists}');
      if (!savedRecharge.exists) {
        throw Exception('Không lưu được hóa đơn nạp tiền');
      }

      await NotificationService().showNotification(
        title: AppTranslations.getText(context, 'success_title'),
        body:
            '${AppTranslations.getText(context, 'top_up_for')} ${widget.selectedProvider.trim()} - $amount VND',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TopUpReceiptScreen(
            transactionId: rechargeRef.id,
            phoneNumber: widget.selectedPhoneNumber.trim(),
            provider: widget.selectedProvider.trim(),
            amount: amount,
            createdAt: DateTime.now(),
            status: 'success',
            type: 'topup',
          ),
        ),
      );
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ LỖI THỰC TẾ: $e');
      debugPrint(stackTrace.toString());
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_t('Lỗi giao dịch', 'Transaction error')),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t('Đóng', 'Close')),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF000DC0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _t('Nạp tiền điện thoại', 'Phone Top-Up'),
          style: GoogleFonts.poppins(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header hiển thị số tiền
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF000DC0), Color(0xFF00088C)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _amountDisplay(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.selectedAmount == _otherAmountKey
                      ? _t(
                          'Vui lòng nhập số tiền mong muốn',
                          'Please enter your desired amount',
                        )
                      : _t('Số tiền bạn đã chọn', 'Selected amount'),
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDDE5FF)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _t(
                              'Vui lòng kiểm tra kỹ thông tin trước khi xác nhận giao dịch.',
                              'Please verify details carefully before confirming.',
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: const Color(0xFF2C3A75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Mục Trích từ
                  Text(
                    _t('Trích từ', 'From account'),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6D7693),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFD8DEEE)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF0FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: primaryColor,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _t('Tài khoản nguồn', 'Source account'),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF6E7490),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF222222),
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(text: "STK: "),
                              TextSpan(
                                text: "123 568 567 456",
                                style: GoogleFonts.poppins(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        StreamBuilder<UserProfileData?>(
                          stream: UserFirestoreService.instance
                              .currentUserProfileStream(),
                          initialData:
                              UserFirestoreService.instance.latestProfile,
                          builder: (context, snapshot) {
                            final UserProfileData? profile =
                                snapshot.data ??
                                UserFirestoreService.instance.latestProfile;
                            final String senderName = snapshot.hasError
                                ? _t('Không tìm thấy user', 'User not found')
                                : ((profile?.fullname.isNotEmpty == true)
                                      ? profile!.fullname
                                      : _t('Khách hàng', 'Customer'));

                            return Text(
                              senderName.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Mục Thông tin chi tiết
                  Text(
                    _t('Thông tin chi tiết', 'Details'),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6D7693),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFD8DEEE)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          _t('Loại dịch vụ', 'Service type'),
                          _t('Nạp ĐTDD', 'Mobile top-up'),
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          _t('Nhà cung cấp', 'Provider'),
                          widget.selectedProvider,
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          _t('Số điện thoại', 'Phone number'),
                          widget.selectedPhoneNumber,
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          _t('Mệnh giá (VND)', 'Amount (VND)'),
                          _amountDisplay(),
                          isBlue: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Nút Xác nhận
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => PinPopupWidget(
                                  onSuccess: _handleConfirmRecharge,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _t('Xác nhận', 'Confirm'),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget con để vẽ từng dòng thông tin
  Widget _buildInfoRow(String label, String value, {bool isBlue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: const Color(0xFF1F263D),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: isBlue ? const Color(0xFF0046A6) : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TopUpReceiptScreen extends StatelessWidget {
  const TopUpReceiptScreen({
    super.key,
    required this.transactionId,
    required this.phoneNumber,
    required this.provider,
    required this.amount,
    required this.createdAt,
    required this.status,
    required this.type,
  });

  final String transactionId;
  final String phoneNumber;
  final String provider;
  final int amount;
  final DateTime createdAt;
  final String status;
  final String type;

  String _t(BuildContext context, String vi, String en) {
    return AppText.tr(context, vi, en);
  }

  String _formatAmountWithDots(int value) {
    final String raw = value.toString();
    final StringBuffer buffer = StringBuffer();
    int count = 0;

    for (int i = raw.length - 1; i >= 0; i--) {
      buffer.write(raw[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join();
  }

  String _formatDateTime(DateTime dateTime) {
    final String twoDigitMonth = dateTime.month.toString().padLeft(2, '0');
    final String twoDigitDay = dateTime.day.toString().padLeft(2, '0');
    final String twoDigitHour = dateTime.hour.toString().padLeft(2, '0');
    final String twoDigitMinute = dateTime.minute.toString().padLeft(2, '0');
    return '$twoDigitDay/$twoDigitMonth/${dateTime.year} $twoDigitHour:$twoDigitMinute';
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: const Color(0xFF6D7693),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: const Color(0xFF1E2747),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF000DC0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _t(context, 'Biên lai nạp tiền', 'Top-up receipt'),
          style: GoogleFonts.poppins(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF000DC0), Color(0xFF00088C)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _t(context, 'Giao dịch thành công', 'Transaction successful'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatAmountWithDots(amount)} VND',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD8DEEE)),
                ),
                child: Column(
                  children: [
                    _buildInfoTile(
                      _t(context, 'Mã giao dịch', 'Transaction ID'),
                      transactionId,
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _t(context, 'Số điện thoại', 'Phone number'),
                      phoneNumber,
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _t(context, 'Nhà mạng', 'Provider'),
                      provider,
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _t(context, 'Số tiền', 'Amount'),
                      '${_formatAmountWithDots(amount)} VND',
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _t(context, 'Thời gian', 'Created at'),
                      _formatDateTime(createdAt),
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(_t(context, 'Trạng thái', 'Status'), status),
                    const Divider(height: 1),
                    _buildInfoTile(_t(context, 'Loại', 'Type'), type),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _t(context, 'Về trang chủ', 'Back to home'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
