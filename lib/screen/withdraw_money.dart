import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/app_translations.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/notification_service.dart';
import '../widget/pin_popup.dart';
import 'withdraw_receipt_screen.dart';

class WithdrawATMPage extends StatefulWidget {
  const WithdrawATMPage({super.key});

  @override
  State<WithdrawATMPage> createState() => _WithdrawATMPageState();
}

class _WithdrawReceiptData {
  const _WithdrawReceiptData({
    required this.code,
    required this.amount,
    required this.createdAt,
    required this.expiresAt,
  });

  final String code;
  final int amount;
  final DateTime createdAt;
  final DateTime expiresAt;
}

class _WithdrawFlowException implements Exception {
  const _WithdrawFlowException(this.message);

  final String message;
}

class _WithdrawATMPageState extends State<WithdrawATMPage> {
  // ==================== NOTE: CAU HINH RANG BUOC (TUY CHINH O DAY) ====================
  static const int _minWithdrawAmount = 50000;
  // Hạn mức rút tối đa mỗi giao dịch: 100 triệu.
  static const int _maxWithdrawAmount = 100000000;
  static const int _withdrawStep = 50000;
  // ================================================================================

  final TextEditingController _amountController = TextEditingController();
  final List<int> _quickAmounts = [
    50000,
    100000,
    200000,
    500000,
    1000000,
    2000000,
  ];
  int? _selectedQuickAmount;
  late final Stream<UserProfileData?> _profileStream;
  double _lastKnownTotalBalance = 0;
  bool _hasLoadedBalance = false;

  // Màu thương hiệu bạn đã cung cấp ở câu trước
  final Color brandColor = const Color(0xFF000DC0);
  final Color bgColor = const Color(0xFFF8F9FE);

  @override
  void initState() {
    super.initState();
    _profileStream = UserFirestoreService.instance.currentUserProfileStream();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  String get _msgInsufficientBalance =>
      _t('Số dư không đủ', 'Insufficient balance');

  String get _msgInvalidStep => _t(
    'Số tiền rút phải là bội số của 50.000đ',
    'Withdrawal amount must be a multiple of 50,000 VND',
  );

  String get _msgOutOfRange => _t(
    'Số tiền rút không nằm trong hạn mức cho phép',
    'Withdrawal amount is outside the allowed limit',
  );

  String _formatCurrency(int amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(amount);
  }

  void _onQuickSelect(int value) {
    setState(() {
      _selectedQuickAmount = value;
      // Định dạng số hiển thị trong ô nhập
      _amountController.text = NumberFormat('#,###', 'vi_VN').format(value);
    });
  }

  void _onAmountChanged(String value) {
    // Chỉ cần reset lựa chọn nhanh; format số thực hiện bằng inputFormatter.
    setState(() => _selectedQuickAmount = null);
  }

  int get _enteredAmount {
    return int.tryParse(_amountController.text.replaceAll(RegExp(r'\D'), '')) ??
        0;
  }

  bool get _hasInsufficientBalance {
    if (!_hasLoadedBalance) return false;
    return _enteredAmount > _lastKnownTotalBalance;
  }

  bool get _isOutOfRange {
    return _enteredAmount > 0 &&
        (_enteredAmount < _minWithdrawAmount ||
            _enteredAmount > _maxWithdrawAmount);
  }

  bool get _isInvalidStep {
    if (_enteredAmount == 0) return false;
    return _enteredAmount % _withdrawStep != 0;
  }

  String? get _amountErrorText {
    if (_hasInsufficientBalance) return _msgInsufficientBalance;
    if (_isOutOfRange) return _msgOutOfRange;
    if (_isInvalidStep) return _msgInvalidStep;
    return null;
  }

  bool get _isValid {
    return _enteredAmount >= _minWithdrawAmount &&
        _enteredAmount <= _maxWithdrawAmount &&
        !_hasInsufficientBalance &&
        !_isInvalidStep;
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

  double _readBalance(dynamic rawBalance) {
    if (rawBalance is num) return rawBalance.toDouble();
    if (rawBalance is String) {
      final String trimmed = rawBalance.trim();
      if (trimmed.isEmpty) {
        return 0;
      }

      final double? direct = double.tryParse(trimmed.replaceAll(',', '.'));
      if (direct != null) {
        return direct;
      }

      final String normalized = trimmed.replaceAll(RegExp(r'[^0-9-]'), '');
      if (normalized.isEmpty || normalized == '-') {
        return 0;
      }
      return num.tryParse(normalized)?.toDouble() ?? 0;
    }
    return 0;
  }

  String _formatBalanceAmount(double value) {
    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value).replaceAll(',', '.');
  }

  String _formatIntAmount(int value) {
    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value).replaceAll(',', '.');
  }

  String _resolveUid() {
    final String? fromService = UserFirestoreService.instance.currentUserDocId;
    if (fromService != null && fromService.isNotEmpty) {
      return fromService;
    }

    final String? fromAuth = FirebaseAuth.instance.currentUser?.uid;
    if (fromAuth != null && fromAuth.isNotEmpty) {
      return fromAuth;
    }

    return '';
  }

  String _generateWithdrawCode() {
    final Random random = Random.secure();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < 10; i++) {
      final int digit = random.nextInt(10);
      buffer.write(digit);
    }

    return 'CCP$buffer';
  }

  Future<_WithdrawReceiptData> _handleWithdraw({
    required String uid,
    required int amount,
  }) async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentReference<Map<String, dynamic>> userRef = firestore
          .collection('users')
          .doc(uid);

      final DateTime createdAt = DateTime.now();
      final DateTime expiresAt = createdAt.add(const Duration(minutes: 15));
      final String withdrawCode = _generateWithdrawCode();
      final String amountText = _formatIntAmount(amount);
      final String successTitleRaw = AppTranslations.getText(
        context,
        'withdraw_success_title',
      );
      final String successTitle = successTitleRaw == 'withdraw_success_title'
          ? 'Rút tiền thành công'
          : successTitleRaw;
      final String successBodyRaw = AppTranslations.getTextWithParams(
        context,
        'withdraw_success_body',
        <String, String>{'amount': amountText},
      );
      final String successBody = successBodyRaw == 'withdraw_success_body'
          ? 'Rút tiền mặt $amountText VND tại điểm giao dịch'
          : successBodyRaw;
      final DocumentReference<Map<String, dynamic>> withdrawRef = userRef
          .collection('withdraw')
          .doc();
      final DocumentReference<Map<String, dynamic>> notificationRef = userRef
          .collection('notifications')
          .doc();

      await firestore.runTransaction((transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> userSnap =
            await transaction.get(userRef);
        if (!userSnap.exists) {
          throw _WithdrawFlowException(
            _t('Không tìm thấy tài khoản người dùng', 'User account not found'),
          );
        }

        final Map<String, dynamic> userData =
            userSnap.data() ?? <String, dynamic>{};
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

        num standardBalance = _readBalance(standardCardSnap.data()?['balance']);
        num vipBalance = _readBalance(vipCardSnap.data()?['balance']);
        final num cardsBalance = hasVipCard
            ? (standardBalance + vipBalance)
            : standardBalance;
        final num userBalance = _readBalance(userData['balance']);

        final bool hasAnyCardBalance = cardsBalance > 0;
        final num currentBalance = hasAnyCardBalance
            ? cardsBalance
            : userBalance;

        if (currentBalance < amount) {
          throw _WithdrawFlowException(_msgInsufficientBalance);
        }

        num newBalance;
        if (hasAnyCardBalance) {
          if (standardBalance >= amount) {
            standardBalance -= amount;
          } else {
            final num remaining = amount - standardBalance;
            standardBalance = 0;
            if (!hasVipCard || vipBalance < remaining) {
              throw _WithdrawFlowException(_msgInsufficientBalance);
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

        transaction.set(withdrawRef, <String, dynamic>{
          'uid': uid,
          'amount': amount,
          'amountText': amountText,
          'currency': 'VND',
          'type': 'withdraw',
          'withdrawCode': withdrawCode,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'expiresAt': Timestamp.fromDate(expiresAt),
        });

        transaction.set(notificationRef, <String, dynamic>{
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'withdraw',
          'isNegative': true,
          'serviceName': _t('Rút tiền mặt', 'Cash withdrawal'),
          'targetAccount': withdrawCode,
          'transactionCode': withdrawCode,
          'status': 'success',
          'isRead': false,
          'relatedId': withdrawRef.id,
          'amount': amount,
        });
      });

      await NotificationService().showNotification(
        title: successTitle,
        body: successBody,
      );

      return _WithdrawReceiptData(
        code: withdrawCode,
        amount: amount,
        createdAt: createdAt,
        expiresAt: expiresAt,
      );
    } on _WithdrawFlowException catch (e) {
      if (e.message == _msgInsufficientBalance && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_msgInsufficientBalance),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    } on FirebaseException catch (e) {
      final String code = e.code.toLowerCase();
      if (code == 'unavailable' ||
          code == 'network-request-failed' ||
          code == 'deadline-exceeded') {
        debugPrint('Withdraw network error: ${e.code} - ${e.message}');
      } else {
        debugPrint('Withdraw Firebase error: ${e.code} - ${e.message}');
      }
      throw _WithdrawFlowException(
        e.message ??
            _t(
              'Đã xảy ra lỗi kết nối khi xử lý rút tiền',
              'A connection error occurred while processing the withdrawal',
            ),
      );
    } catch (e) {
      debugPrint('Withdraw unexpected error: $e');
      rethrow;
    }
  }

  Widget _buildAvailableBalanceValue() {
    return StreamBuilder<UserProfileData?>(
      stream: _profileStream,
      initialData: UserFirestoreService.instance.latestProfile,
      builder: (context, profileSnapshot) {
        final UserProfileData? profile =
            profileSnapshot.data ?? UserFirestoreService.instance.latestProfile;
        final String? resolvedUserId = profile?.uid;

        if (resolvedUserId == null || resolvedUserId.isEmpty) {
          return _buildBalanceNumber(_lastKnownTotalBalance);
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
                    final String docId = doc.id.toLowerCase();
                    final double balance = _readBalance(doc.data()['balance']);
                    if (docId == 'standard') {
                      standardBalance = balance;
                    } else if (docId == 'vip') {
                      vipBalance = balance;
                    }
                  }

                  final double updatedTotal = hasVipCard
                      ? standardBalance + vipBalance
                      : standardBalance;

                  if (updatedTotal != _lastKnownTotalBalance ||
                      !_hasLoadedBalance) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        _lastKnownTotalBalance = updatedTotal;
                        _hasLoadedBalance = true;
                      });
                    });
                  }
                }

                if (cardsSnapshot.connectionState == ConnectionState.waiting &&
                    !_hasLoadedBalance) {
                  return const Text(
                    '...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }

                if ((cardsSnapshot.hasError || userSnapshot.hasError) &&
                    !_hasLoadedBalance) {
                  return _buildBalanceNumber(0);
                }

                return _buildBalanceNumber(_lastKnownTotalBalance);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceNumber(double totalBalance) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatBalanceAmount(totalBalance),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'VND',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData poppinsTheme = Theme.of(context).copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
    );

    return Theme(
      data: poppinsTheme,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildAmountInput(),
                    const SizedBox(height: 16),
                    _buildQuickSelectGrid(),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF3FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD6E0FF)),
                      ),
                      child: Text(
                        _t(
                          'Hạn mức rút: ${_formatIntAmount(_minWithdrawAmount)}đ - ${_formatIntAmount(_maxWithdrawAmount)}đ / lần',
                          'Withdrawal limit: ${_formatIntAmount(_minWithdrawAmount)} VND - ${_formatIntAmount(_maxWithdrawAmount)} VND / transaction',
                        ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF405086),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                    const SizedBox(height: 20),
                    _buildSecurityBadge(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Header với Gradient và Card thông tin ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2239E2),
            brandColor,
            const Color(0xFF031A90),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _t('Rút tiền', 'Withdraw'),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 30),
          // Thẻ tài khoản (Glassmorphism)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.credit_card, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('TÀI KHOẢN NGUỒN', 'SOURCE ACCOUNT'),
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '•••• •••• ••••',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Divider(color: Colors.white.withValues(alpha: 0.13)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('SỐ DƯ KHẢ DỤNG', 'AVAILABLE BALANCE'),
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildAvailableBalanceValue(),
                      ],
                    ),
                    Icon(
                      Icons.payments_outlined,
                      color: Colors.white.withValues(alpha: 0.34),
                      size: 40,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Ô nhập số tiền ---
  Widget _buildAmountInput() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Nhập số tiền muốn rút', 'Enter withdrawal amount'),
            style: GoogleFonts.poppins(
              color: const Color(0xFF727C96),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              TextInputFormatter.withFunction((oldValue, newValue) {
                final String digits = newValue.text.replaceAll(
                  RegExp(r'\D'),
                  '',
                );
                if (digits.isEmpty) {
                  return const TextEditingValue(text: '');
                }

                final int? parsed = int.tryParse(digits);
                if (parsed == null) return oldValue;

                final String formatted = NumberFormat(
                  '#,###',
                  'vi_VN',
                ).format(parsed);
                return TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }),
            ],
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E2745),
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: GoogleFonts.poppins(
                color: const Color(0xFFB2B8CA),
                fontWeight: FontWeight.w600,
              ),
              errorText: _amountErrorText,
              suffixIcon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _t('VNĐ', 'VND'),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7F879E),
                    fontSize: 12,
                  ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minHeight: 0,
                minWidth: 0,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: brandColor.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: brandColor, width: 2),
              ),
            ),
            onChanged: _onAmountChanged,
          ),
        ],
      ),
    );
  }

  // --- Grid chọn nhanh ---
  Widget _buildQuickSelectGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Chọn nhanh mệnh giá', 'Quick amount selection'),
            style: GoogleFonts.poppins(
              color: const Color(0xFF727C96),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _quickAmounts.length,
            itemBuilder: (context, index) {
              final val = _quickAmounts[index];
              final isSelected = _selectedQuickAmount == val;
              return GestureDetector(
                onTap: () => _onQuickSelect(val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? brandColor : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: brandColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _formatCurrency(val),
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Nút Rút tiền ---
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isValid ? _onSubmitWithdraw : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2B1CA3),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: _isValid ? 8 : 0,
          shadowColor: const Color(0xFF2B1CA3).withValues(alpha: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.file_download_outlined),
            const SizedBox(width: 10),
            Text(
              _t('Rút tiền', 'Withdraw'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmitWithdraw() async {
    final String digits = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final int amount = digits.isEmpty ? 0 : int.parse(digits);
    if (!_isValid || amount <= 0) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PinPopupWidget(
        onSuccess: () async {
          final String uid = _resolveUid();
          if (uid.isEmpty) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _t(
                    'Không tìm thấy phiên đăng nhập hợp lệ',
                    'No valid login session found',
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          try {
            final _WithdrawReceiptData receipt = await _handleWithdraw(
              uid: uid,
              amount: amount,
            );

            if (!mounted) {
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WithdrawReceiptScreen(
                  amount: receipt.amount,
                  withdrawCode: receipt.code,
                  createdAt: receipt.createdAt,
                  expiresAt: receipt.expiresAt,
                ),
              ),
            );
          } on _WithdrawFlowException catch (e) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message), backgroundColor: Colors.red),
            );
          } catch (_) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _t(
                    'Đã xảy ra lỗi, vui lòng thử lại',
                    'An error occurred, please try again',
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSecurityBadge() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield, size: 14, color: Colors.grey.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text(
          _t(
            'Giao dịch được bảo mật bởi SSL 256-bit',
            'Transactions are secured by 256-bit SSL',
          ),
          style: GoogleFonts.poppins(
            color: Colors.grey.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
