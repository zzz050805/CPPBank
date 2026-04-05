import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../core/app_translations.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/notification_service.dart';
import '../widget/ccp_app_bar.dart';
import 'tranfer_bill.dart';

class SmartOtpTransferPinScreen extends StatefulWidget {
  const SmartOtpTransferPinScreen({
    super.key,
    required this.uid,
    required this.accountNumber,
    required this.accountName,
    required this.bankName,
    required this.bankId,
    required this.initials,
    required this.amountText,
    required this.transferContent,
  });

  final String uid;
  final String accountNumber;
  final String accountName;
  final String bankName;
  final String bankId;
  final String initials;
  final String amountText;
  final String transferContent;

  @override
  State<SmartOtpTransferPinScreen> createState() =>
      _SmartOtpTransferPinScreenState();
}

class _SmartOtpTransferPinScreenState extends State<SmartOtpTransferPinScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isVerifying = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  String _defaultPinFromId(dynamic idNumberRaw) {
    final String digits = (idNumberRaw ?? '').toString().replaceAll(
      RegExp(r'\D'),
      '',
    );
    if (digits.isEmpty) {
      return '';
    }
    if (digits.length >= 6) {
      return digits.substring(digits.length - 6);
    }
    return digits.padLeft(6, '0');
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

  String _resolveUid() {
    final String fromWidget = widget.uid.trim();
    if (fromWidget.isNotEmpty) {
      return fromWidget;
    }

    final String? fromUserService =
        UserFirestoreService.instance.currentUserDocId;
    if (fromUserService != null && fromUserService.isNotEmpty) {
      return fromUserService;
    }

    final String? fromAuth = FirebaseAuth.instance.currentUser?.uid;
    if (fromAuth != null && fromAuth.isNotEmpty) {
      return fromAuth;
    }

    return '';
  }

  double _normalizedAmount() {
    final String digits = widget.amountText.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return 0;
    }
    return double.tryParse(digits) ?? 0;
  }

  Future<void> _executeTransferTransaction() async {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      throw const _TransferFlowException(
        vi: 'Không tìm thấy phiên đăng nhập hợp lệ.',
        en: 'No valid signed-in session found.',
      );
    }

    final String accountNumber = widget.accountNumber.trim();
    if (accountNumber.isEmpty) {
      throw const _TransferFlowException(
        vi: 'Số tài khoản người nhận không được để trống.',
        en: 'Recipient account number cannot be empty.',
      );
    }

    final double amount = _normalizedAmount();
    if (amount <= 0) {
      throw const _TransferFlowException(
        vi: 'Số tiền phải lớn hơn 0.',
        en: 'Amount must be greater than 0.',
      );
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference<Map<String, dynamic>> userRef = firestore
        .collection('users')
        .doc(uid);

    await firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> userSnap = await transaction
          .get(userRef);

      if (!userSnap.exists) {
        throw const _TransferFlowException(
          vi: 'Không tìm thấy thông tin tài khoản.',
          en: 'Account information not found.',
        );
      }

      final Map<String, dynamic> userData =
          userSnap.data() ?? <String, dynamic>{};
      final bool hasVipCard = userData['hasVipCard'] == true;

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

      final double standardBalance = _toDouble(
        standardCardSnap.data()?['balance'],
      );
      final double vipBalance = _toDouble(vipCardSnap.data()?['balance']);

      final double availableBalance = hasVipCard
          ? standardBalance + vipBalance
          : standardBalance;

      if (availableBalance < amount) {
        throw const _TransferFlowException(
          vi: 'Số dư không đủ',
          en: 'Insufficient balance',
        );
      }

      double newStandardBalance = standardBalance;
      double newVipBalance = vipBalance;

      if (newStandardBalance >= amount) {
        newStandardBalance = newStandardBalance - amount;
      } else {
        final double remaining = amount - newStandardBalance;
        newStandardBalance = 0;
        if (hasVipCard) {
          newVipBalance = newVipBalance - remaining;
        }
      }

      if (standardCardSnap.exists) {
        transaction.update(standardCardRef, <String, dynamic>{
          'balance': newStandardBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(standardCardRef, <String, dynamic>{
          'balance': newStandardBalance,
          'cardType': 'Standard',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (hasVipCard) {
        if (vipCardSnap.exists) {
          transaction.update(vipCardRef, <String, dynamic>{
            'balance': newVipBalance,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(vipCardRef, <String, dynamic>{
            'balance': newVipBalance,
            'cardType': 'VIP',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      transaction.set(userRef, <String, dynamic>{
        'balance': hasVipCard
            ? newStandardBalance + newVipBalance
            : newStandardBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _verifyAndContinue(String expectedPin) async {
    final String enteredPin = _pinController.text.trim();
    final String languageCode = Localizations.localeOf(context).languageCode;

    if (enteredPin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Vui lòng nhập đủ 6 số PIN.', 'Please enter all 6 PIN digits.'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (expectedPin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Tài khoản chưa cài Smart OTP PIN.',
              'This account has not set a Smart OTP PIN yet.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (enteredPin != expectedPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Smart OTP PIN không đúng.', 'Smart OTP PIN is incorrect.'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      _pinController.clear();
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      await _executeTransferTransaction();

      final int amount = _normalizedAmount().round();
      final String receiverName = widget.accountName;
      final String notificationTitleRaw = AppTranslations.getTextByCode(
        languageCode,
        'transfer_success_title',
      );
      final String notificationTitle =
          notificationTitleRaw == 'transfer_success_title'
          ? 'Chuyển khoản thành công'
          : notificationTitleRaw;
      final String notificationBodyRaw =
          AppTranslations.getTextByCodeWithParams(
            languageCode,
            'transfer_success_body',
            <String, String>{'amount': '$amount', 'receiver': receiverName},
          );
      final String notificationBody =
          notificationBodyRaw == 'transfer_success_body'
          ? 'Đã chuyển $amount VND đến $receiverName'
          : notificationBodyRaw;

      await NotificationService().showNotification(
        title: notificationTitle,
        body: notificationBody,
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SuccessTransactionScreen()),
      );
    } on _TransferFlowException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(e.vi, e.en)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      String message = _t(
        'Có lỗi mạng hoặc hệ thống, vui lòng thử lại.',
        'Network or system error, please try again.',
      );

      if (e.code == 'permission-denied') {
        message = _t(
          'Bạn không có quyền thực hiện giao dịch này.',
          'You do not have permission for this transfer.',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Đã xảy ra lỗi không xác định, vui lòng thử lại.',
              'An unexpected error occurred. Please try again.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Widget _buildPinInput() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double gap = 5;
        final double fieldWidth = ((constraints.maxWidth - (gap * 5)) / 6)
            .clamp(40.0, 48.0);

        final PinTheme pinTheme = PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(12),
          fieldHeight: 62,
          fieldWidth: fieldWidth,
          activeColor: const Color(0xFF000DC0),
          selectedColor: const Color(0xFF000DC0),
          inactiveColor: const Color(0xFFD7DDEE),
          activeBorderWidth: 1.2,
          selectedBorderWidth: 1.1,
          inactiveBorderWidth: 0.9,
          activeFillColor: const Color(0xFFF3F6FF),
          selectedFillColor: const Color(0xFFF3F6FF),
          inactiveFillColor: const Color(0xFFF8FAFF),
        );

        return PinCodeTextField(
          appContext: context,
          length: 6,
          controller: _pinController,
          autoDisposeControllers: false,
          autoFocus: true,
          keyboardType: TextInputType.number,
          animationType: AnimationType.fade,
          enableActiveFill: true,
          pinTheme: pinTheme,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textStyle: GoogleFonts.poppins(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF272730),
          ),
          onChanged: (_) {},
          beforeTextPaste: (_) => false,
          onCompleted: (_) {},
          animationDuration: const Duration(milliseconds: 170),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: CCPAppBar(
        title: _t('Xác thực Smart OTP', 'Smart OTP verification'),
        backgroundColor: const Color(0xFFF5F7FF),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF000DC0)),
            );
          }

          final Map<String, dynamic> data =
              snapshot.data?.data() ?? <String, dynamic>{};
          final String savedPin = (data['smartOtpPin'] ?? '').toString().trim();
          final String defaultPin = _defaultPinFromId(
            data['idNumber'] ?? data['cccd'],
          );
          final String expectedPin = savedPin.isNotEmpty
              ? savedPin
              : defaultPin;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(
                      'Nhập Smart OTP PIN gồm 6 chữ số để xác nhận giao dịch.',
                      'Enter your 6-digit Smart OTP PIN to authorize this transaction.',
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF5E667F),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildPinInput(),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isVerifying
                          ? null
                          : () => _verifyAndContinue(expectedPin),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000DC0),
                        disabledBackgroundColor: const Color(0xFF8C93D9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _t('Xác nhận giao dịch', 'Confirm transaction'),
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TransferFlowException implements Exception {
  const _TransferFlowException({required this.vi, required this.en});

  final String vi;
  final String en;
}
