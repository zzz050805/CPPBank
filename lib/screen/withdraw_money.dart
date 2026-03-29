import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../data/user_firestore_service.dart';

class WithdrawATMPage extends StatefulWidget {
  const WithdrawATMPage({super.key});

  @override
  State<WithdrawATMPage> createState() => _WithdrawATMPageState();
}

class _WithdrawATMPageState extends State<WithdrawATMPage> {
  // ==================== NOTE: CAU HINH RANG BUOC (TUY CHINH O DAY) ====================
  static const int _minWithdrawAmount = 50000;
  static const int _maxWithdrawAmount = 100000000;
  static const int _withdrawStep = 50000;

  static const String _msgInsufficientBalance = 'Số dư của bạn không đủ';
  static const String _msgInvalidStep =
      'Số tiền rút phải là bội số của 50.000đ';
  static const String _msgOutOfRange =
      'Số tiền rút không nằm trong hạn mức cho phép';
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
    if (rawBalance is String) return double.tryParse(rawBalance) ?? 0;
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
    return Text(
      _formatBalanceAmount(totalBalance),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  const SizedBox(height: 20),
                  Text(
                    'Số tiền tối thiểu bạn có thể rút là ${_formatIntAmount(_minWithdrawAmount)}đ • Tối đa ${_formatIntAmount(_maxWithdrawAmount)}đ/lần',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
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
    );
  }

  // --- Header với Gradient và Card thông tin ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brandColor, brandColor.withOpacity(0.8)],
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
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Rút tiền ",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.credit_card, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TÀI KHOẢN NGUỒN",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          "•••• •••• •••• ",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Divider(color: Colors.white.withOpacity(0.1)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SỐ DƯ KHẢ DỤNG",
                          style: TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            _buildAvailableBalanceValue(),
                            const Text(
                              "đ",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(
                      Icons.payments_outlined,
                      color: Colors.white.withOpacity(0.3),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Nhập số tiền muốn rút",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
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
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: "0",
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
                child: const Text(
                  "VNĐ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minHeight: 0,
                minWidth: 0,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: brandColor.withOpacity(0.2),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Chọn nhanh mệnh giá",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
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
                              color: brandColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _formatCurrency(val),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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
        onPressed: _isValid ? () {} : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2B1CA3),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: _isValid ? 8 : 0,
          shadowColor: const Color(0xFF2B1CA3).withOpacity(0.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.file_download_outlined),
            SizedBox(width: 10),
            Text(
              "Rút tiền",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityBadge() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield, size: 14, color: Colors.grey.withOpacity(0.5)),
        const SizedBox(width: 6),
        Text(
          "Giao dịch được bảo mật bởi SSL 256-bit",
          style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 11),
        ),
      ],
    );
  }
}
