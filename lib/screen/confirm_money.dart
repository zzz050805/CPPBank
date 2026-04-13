import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/card_number_service.dart';
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
        // Thi?t l?p font Poppins làm m?c d?nh toàn app
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
    this.recipientAccountName = '',
    this.recipientBankName = '',
    this.recipientBankId = '',
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
      return _t(context, 'Chua nh?p', 'Not provided');
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
            ? _t(context, 'Không t́m th?y user', 'User not found')
            : ((profile?.fullname.isNotEmpty == true)
                  ? profile!.fullname
                  : _t(context, 'Khách hàng', 'Customer'));
        final String uid = (profile?.uid ?? _resolveUid()).trim();

        if (uid.isEmpty) {
          return _buildAccountCard(
            name: senderName.toUpperCase(),
            id: _t(context, 'Đang t?i...', 'Loading...'),
            isSource: true,
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            String sourceCardDisplay = _t(context, 'Đang t?i...', 'Loading...');
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
    return value;
  }

  String _safeRecipientBank() {
    final String value = recipientBankName.trim();
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
          'Không t́m th?y phiên dang nh?p h?p l?.',
          'No valid signed-in session found.',
        ),
      );
    }

    final double amount = _normalizedAmount(amountText);
    if (amount <= 0) {
      throw _TransferConfirmationException(
        _t(
          context,
          'S? ti?n ph?i l?n hon 0.',
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
    final DocumentReference<Map<String, dynamic>> transactionRef = userRef
        .collection('transactions')
        .doc();

    final int roundedAmount = amount.round();
    final String transferCode =
        'TRF${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final String transferAmountText = _formatAmount(roundedAmount.toString());
    final Map<String, String> bodyParams = <String, String>{
      'amount': transferAmountText,
      'name': recipientName,
      'receiverName': recipientName,
    };
    final DateTime transferCompletedAt = DateTime.now();
    final String accountNotFoundMessage = _t(
      context,
      'Không t́m th?y thông tin tài kho?n.',
      'Account information not found.',
    );
    final String insufficientBalanceMessage = _t(
      context,
      'S? du không d?.',
      'Insufficient balance.',
    );

    await firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> userSnap = await transaction
          .get(userRef);

      if (!userSnap.exists) {
        throw _TransferConfirmationException(accountNotFoundMessage);
      }

      final Map<String, dynamic> userData =
          userSnap.data() ?? <String, dynamic>{};
      final bool hasVipCard = userData['hasVipCard'] == true;

      final DocumentSnapshot<Map<String, dynamic>> standardCardSnap =
          await transaction.get(standardCardRef);
      final DocumentSnapshot<Map<String, dynamic>> vipCardSnap =
          await transaction.get(vipCardRef);

      final Map<String, dynamic> standardCardData =
          standardCardSnap.data() ?? <String, dynamic>{};
      final Map<String, dynamic> vipCardData =
          vipCardSnap.data() ?? <String, dynamic>{};

      final Map<String, Map<String, dynamic>> cardsById =
          <String, Map<String, dynamic>>{
            'standard': standardCardData,
            'vip': vipCardData,
          };

      final bool standardAvailable = UserFirestoreService.instance
          .isCardAvailableForTransactions(
            cardId: 'standard',
            cardData: standardCardData,
            userData: userData,
          );
      final bool vipAvailable =
          hasVipCard &&
          UserFirestoreService.instance.isCardAvailableForTransactions(
            cardId: 'vip',
            cardData: vipCardData,
            userData: userData,
          );

      double standardBalance = _toDouble(standardCardData['balance']);
      double vipBalance = _toDouble(vipCardData['balance']);

      final double currentBalance = UserFirestoreService.instance
          .calculateAvailableBalanceFromMaps(
            userData: userData,
            cardsById: cardsById,
          );

      if (currentBalance < amount) {
        throw _TransferConfirmationException(insufficientBalanceMessage);
      }

      double remaining = amount;
      double standardDeduction = 0;
      double vipDeduction = 0;

      if (standardAvailable) {
        standardDeduction = remaining <= standardBalance
            ? remaining
            : standardBalance;
        remaining -= standardDeduction;
      }

      if (remaining > 0 && vipAvailable) {
        vipDeduction = remaining <= vipBalance ? remaining : vipBalance;
        remaining -= vipDeduction;
      }

      if (remaining > 0) {
        throw _TransferConfirmationException(insufficientBalanceMessage);
      }

      if (standardDeduction > 0) {
        transaction.set(standardCardRef, <String, dynamic>{
          'balance': FieldValue.increment(-standardDeduction),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (vipDeduction > 0) {
        transaction.set(vipCardRef, <String, dynamic>{
          'balance': FieldValue.increment(-vipDeduction),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      transaction.set(userRef, <String, dynamic>{
        'balance': FieldValue.increment(-amount),
        'availableBalance': FieldValue.increment(-amount),
        'totalBalance': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(notificationRef, <String, dynamic>{
        'titleKey': 'notify_transfer_title',
        'bodyKey': 'notify_transfer_body',
        'bodyParams': bodyParams,
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
        'receiver_name': recipientName,
        'receiverName': recipientName,
        'recipientName': recipientName,
        'serviceName': recipientName,
        'transactionCode': transferCode,
        'transferContent': transferContent,
      });

      transaction.set(transactionRef, <String, dynamic>{
        'type': 'transfer',
        'amount': roundedAmount,
        'status': 'success',
        'timestamp': FieldValue.serverTimestamp(),
        'timestamp_client': Timestamp.fromDate(transferCompletedAt),
        'createdAt': FieldValue.serverTimestamp(),
        'createdAt_client': Timestamp.fromDate(transferCompletedAt),
        'transactionCode': transferCode,
        'recipientName': recipientName,
        'toCardNumber': recipientAccount,
        'isNegative': true,
      });
    });

    if (!context.mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SuccessTransactionScreen(
          receiverName: recipientName,
          receiverCardNumber: recipientAccount,
          bankName: recipientBankName,
          transactionCode: transferCode,
          transferContent: transferContent,
          transferAmount: roundedAmount,
          transferredAt: transferCompletedAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayAmount = _formatAmount(amountText);
    final String displayContent = transferContent.trim().isEmpty
        ? _t(context, 'CHUY?N TI?N', 'TRANSFER')
        : transferContent.trim();
    final String displayRecipientAccount = _safeRecipientAccount(context);
    final String displayRecipientName = _safeRecipientName().trim().isEmpty
        ? _t(context, 'Không xác d?nh', 'Unknown')
        : _safeRecipientName();
    final String displayRecipientBank = _safeRecipientBank().trim().isEmpty
        ? _t(context, 'Không xác d?nh', 'Unknown')
        : _safeRecipientBank();
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: CCPAppBar(
        title: _t(context, 'Xác nh?n chuy?n ti?n', 'Confirm transfer'),
        backgroundColor: pageBackground,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(
              _t(context, 'H?y', 'Cancel'),
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
                                  'S? ti?n chuy?n',
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
                                  'Đă nh?p: $displayAmount',
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
                          _t(context, 'T? th?', 'From card'),
                        ),
                        const SizedBox(height: 10),
                        _buildSourceAccountCard(context),
                        const SizedBox(height: 16),
                        _buildSectionLabel(
                          context,
                          _t(context, 'Đ?n th?', 'To card'),
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
                          _t(context, 'N?i dung', 'Content'),
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
                                    'Vui ḷng ki?m tra k? thông tin tru?c khi xác nh?n.',
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
                            'Không t́m th?y tài kho?n d? xác th?c giao d?ch.',
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
                                  'Đă x?y ra l?i không xác d?nh, vui ḷng th? l?i.',
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
                  _t(context, 'Xác nh?n', 'Confirm'),
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
