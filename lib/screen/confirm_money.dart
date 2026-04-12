import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/app_translations.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/card_number_service.dart';
import '../services/notification_service.dart';
import '../widget/pin_popup.dart';
import '../widget/ccp_app_bar.dart';
import 'tranfer_bill.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Thiết lập font Poppins làm mặc định toàn app
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const ConfirmTransferScreen(),
    );
  }
}

class ConfirmTransferScreen extends StatelessWidget {
  const ConfirmTransferScreen({
    super.key,
    this.amountText = '',
    this.transferContent = '',
    this.recipientAccountNumber = '',
    this.recipientAccountName = 'TRAN THANH B',
    this.recipientBankName = 'MC-BANK',
    this.recipientBankId = 'mc_bank',
  });

  final String amountText;
  final String transferContent;
  final String recipientAccountNumber;
  final String recipientAccountName;
  final String recipientBankName;
  final String recipientBankId;

  static const Color primaryBlue = Color(0xFF000DC0);
  static const Color pageBackground = Color(0xFFF6F8FF);

  String _t(BuildContext context, String vi, String en) =>
      AppText.tr(context, vi, en);

  String _formatAmount(String rawAmount) {
    final String digits = rawAmount.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '0 VND';
    }
    final int value = int.tryParse(digits) ?? 0;
    return '${NumberFormat('#,###', 'en_US').format(value)} VND';
  }

  String _safeRecipientAccount(BuildContext context) {
    final String value = recipientAccountNumber.trim();
    if (value.isEmpty) {
      return _t(context, 'Chưa nhập', 'Not provided');
    }
    return CardNumberService.formatCardNumber(value);
  }

  Widget _buildSourceAccountCard(BuildContext context) {
    return StreamBuilder<UserProfileData?>(
      stream: UserFirestoreService.instance.currentUserProfileStream(),
      initialData: UserFirestoreService.instance.latestProfile,
      builder: (context, snapshot) {
        final UserProfileData? profile =
            snapshot.data ?? UserFirestoreService.instance.latestProfile;
        final String senderName = snapshot.hasError
            ? _t(context, 'Không tìm thấy user', 'User not found')
            : ((profile?.fullname.isNotEmpty == true)
                  ? profile!.fullname
                  : _t(context, 'Khách hàng', 'Customer'));
        final String uid = (profile?.uid ?? _resolveUid()).trim();

        if (uid.isEmpty) {
          return _buildAccountCard(
            name: senderName.toUpperCase(),
            id: _t(context, 'Đang tải...', 'Loading...'),
            isSource: true,
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            String sourceCardDisplay = _t(context, 'Đang tải...', 'Loading...');
            if (userSnapshot.hasData) {
              final Map<String, dynamic> userData =
                  userSnapshot.data?.data() ?? <String, dynamic>{};
              final String raw = CardNumberService.readStoredCardNumber(
                userData,
              );
              if (raw.isNotEmpty) {
                sourceCardDisplay = CardNumberService.formatCardNumber(raw);
              }
            }

            return _buildAccountCard(
              name: senderName.toUpperCase(),
              id: sourceCardDisplay,
              isSource: true,
            );
          },
        );
      },
    );
  }

  String _safeRecipientName() {
    final String value = recipientAccountName.trim();
    if (value.isEmpty) {
      return 'TRAN THANH B';
    }
    return value.toUpperCase();
  }

  String _safeRecipientBank() {
    final String value = recipientBankName.trim();
    if (value.isEmpty) {
      return 'MC-BANK';
    }
    return value;
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

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  double _normalizedAmount(String rawAmount) {
    final String digits = rawAmount.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return 0;
    }
    return double.tryParse(digits) ?? 0;
  }

  Future<void> _processConfirmedTransfer({
    required BuildContext context,
    required String amountText,
    required String recipientAccount,
    required String recipientName,
    required String transferContent,
  }) async {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      throw _TransferConfirmationException(
        _t(
          context,
          'Không tìm thấy phiên đăng nhập hợp lệ.',
          'No valid signed-in session found.',
        ),
      );
    }

    final double amount = _normalizedAmount(amountText);
    if (amount <= 0) {
      throw _TransferConfirmationException(
        _t(
          context,
          'Số tiền phải lớn hơn 0.',
          'Amount must be greater than 0.',
        ),
      );
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference<Map<String, dynamic>> userRef = firestore
        .collection('users')
        .doc(uid);
    final DocumentReference<Map<String, dynamic>> standardCardRef = userRef
        .collection('cards')
        .doc('standard');
    final DocumentReference<Map<String, dynamic>> vipCardRef = userRef
        .collection('cards')
        .doc('vip');
    final DocumentReference<Map<String, dynamic>> notificationRef = userRef
        .collection('notifications')
        .doc();

    final int roundedAmount = amount.round();
    final String transferCode =
        'TRF${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final String languageCode = AppTranslations.currentLanguageCode(context);
    final String notificationTitleRaw = AppTranslations.getTextByCode(
      languageCode,
      'transfer_success_title',
    );
    final String notificationTitle =
        notificationTitleRaw == 'transfer_success_title'
        ? 'Chuyển khoản thành công'
        : notificationTitleRaw;
    final String notificationBodyRaw = AppTranslations.getTextByCodeWithParams(
      languageCode,
      'transfer_success_body',
      <String, String>{'amount': '$roundedAmount', 'receiver': recipientName},
    );
    final String notificationBody =
        notificationBodyRaw == 'transfer_success_body'
        ? 'Đã chuyển $roundedAmount VND đến $recipientName'
        : notificationBodyRaw;

    await firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> userSnap = await transaction
          .get(userRef);

      if (!userSnap.exists) {
        throw _TransferConfirmationException(
          _t(
            context,
            'Không tìm thấy thông tin tài khoản.',
            'Account information not found.',
          ),
        );
      }

      final Map<String, dynamic> userData =
          userSnap.data() ?? <String, dynamic>{};
      final bool hasVipCard = userData['hasVipCard'] == true;

      final DocumentSnapshot<Map<String, dynamic>> standardCardSnap =
          await transaction.get(standardCardRef);
      final DocumentSnapshot<Map<String, dynamic>> vipCardSnap =
          await transaction.get(vipCardRef);

      double standardBalance = _toDouble(standardCardSnap.data()?['balance']);
      double vipBalance = _toDouble(vipCardSnap.data()?['balance']);
      final double userBalance = _toDouble(userData['balance']);
      final double cardsBalance = hasVipCard
          ? (standardBalance + vipBalance)
          : standardBalance;
      final bool hasAnyCardBalance = cardsBalance > 0;
      final double currentBalance = hasAnyCardBalance
          ? cardsBalance
          : userBalance;

      if (currentBalance < amount) {
        throw _TransferConfirmationException(
          _t(context, 'Số dư không đủ.', 'Insufficient balance.'),
        );
      }

      double newBalance;

      if (hasAnyCardBalance) {
        if (standardBalance >= amount) {
          standardBalance -= amount;
        } else {
          final double remaining = amount - standardBalance;
          standardBalance = 0;
          if (!hasVipCard || vipBalance < remaining) {
            throw _TransferConfirmationException(
              _t(context, 'Số dư không đủ.', 'Insufficient balance.'),
            );
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

      transaction.set(userRef, <String, dynamic>{
        'balance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(notificationRef, <String, dynamic>{
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'transfer',
        'isRead': false,
        'isNegative': true,
        'relatedId': transferCode,
        'amount': roundedAmount,
        'card_number': recipientAccount,
        'cardNumber': recipientAccount,
        'toCardNumber': recipientAccount,
        'targetAccount': recipientAccount,
        'toAccountNumber': recipientAccount,
        'accountNumber': recipientAccount,
        'receiverName': recipientName,
        'recipientName': recipientName,
        'serviceName': recipientName,
        'transactionCode': transferCode,
        'transferContent': transferContent,
      });
    });

    await NotificationService().showNotification(
      title: notificationTitle,
      body: notificationBody,
    );

    if (!context.mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SuccessTransactionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayAmount = _formatAmount(amountText);
    final String displayContent = transferContent.trim().isEmpty
        ? _t(context, 'CHUYỂN TIỀN', 'TRANSFER')
        : transferContent.trim();
    final String displayRecipientAccount = _safeRecipientAccount(context);
    final String displayRecipientName = _safeRecipientName();
    final String displayRecipientBank = _safeRecipientBank();
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: CCPAppBar(
        title: _t(context, 'Xác nhận chuyển tiền', 'Confirm transfer'),
        backgroundColor: pageBackground,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(
              _t(context, 'Hủy', 'Cancel'),
              style: GoogleFonts.poppins(
                color: primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1D2BCB), Color(0xFF000DC0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000DC0),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(
                                  context,
                                  'Số tiền chuyển',
                                  'Transfer amount',
                                ),
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                displayAmount,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _t(
                                  context,
                                  'Đã nhập: $displayAmount',
                                  'Entered: $displayAmount',
                                ),
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(
                          context,
                          _t(context, 'Từ thẻ', 'From card'),
                        ),
                        const SizedBox(height: 10),
                        _buildSourceAccountCard(context),
                        const SizedBox(height: 16),
                        _buildSectionLabel(
                          context,
                          _t(context, 'Đến thẻ', 'To card'),
                        ),
                        const SizedBox(height: 10),
                        _buildAccountCard(
                          name: displayRecipientName,
                          bank: displayRecipientBank,
                          id: displayRecipientAccount,
                          isSource: false,
                        ),
                        const SizedBox(height: 16),
                        _buildSectionLabel(
                          context,
                          _t(context, 'Nội dung', 'Content'),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFBFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E7F2)),
                          ),
                          child: Text(
                            displayContent,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF23283A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F8FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE4E9F5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 17,
                                color: Color(0xFF68708A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _t(
                                    context,
                                    'Vui lòng kiểm tra kỹ thông tin trước khi xác nhận.',
                                    'Please verify details carefully before confirming.',
                                  ),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF636B83),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  final String uid = _resolveUid();
                  if (uid.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _t(
                            context,
                            'Không tìm thấy tài khoản để xác thực giao dịch.',
                            'Account not found for transaction verification.',
                          ),
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => PinPopupWidget(
                      onSuccess: () async {
                        try {
                          await _processConfirmedTransfer(
                            context: context,
                            amountText: amountText,
                            recipientAccount: recipientAccountNumber.trim(),
                            recipientName: displayRecipientName,
                            transferContent: displayContent,
                          );
                        } on _TransferConfirmationException catch (e) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.red,
                            ),
                          );
                        } catch (_) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _t(
                                  context,
                                  'Đã xảy ra lỗi không xác định, vui lòng thử lại.',
                                  'An unexpected error occurred. Please try again.',
                                ),
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _t(context, 'Xác nhận', 'Confirm'),
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

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: const Color(0xFF8B92A6),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildAccountCard({
    required String name,
    required String id,
    String? bank,
    required bool isSource,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSource ? const Color(0xFFFAFBFF) : primaryBlue,
        borderRadius: BorderRadius.circular(14),
        border: isSource ? Border.all(color: const Color(0xFFE2E7F2)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.poppins(
              color: isSource ? const Color(0xFF252A3A) : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (bank != null)
            Text(
              bank,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.account_balance,
                color: isSource ? const Color(0xFF7A8195) : Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                id,
                style: GoogleFonts.poppins(
                  color: isSource ? const Color(0xFF626A82) : Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransferConfirmationException implements Exception {
  const _TransferConfirmationException(this.message);

  final String message;
}
