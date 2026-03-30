import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'main_tab_shell.dart';
import 'water_bill_success.dart';

class WaterBillOtpScreen extends StatefulWidget {
  const WaterBillOtpScreen({
    super.key,
    required this.totalAmount,
    required this.customerName,
    required this.customerCode,
    this.maskedPhone = '******889',
  });

  final double totalAmount;
  final String customerName;
  final String customerCode;
  final String maskedPhone;

  @override
  State<WaterBillOtpScreen> createState() => _WaterBillOtpScreenState();
}

class _WaterBillOtpScreenState extends State<WaterBillOtpScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _surface = Color(0xFFF6F7FF);

  final NumberFormat _moneyFormat = NumberFormat.decimalPattern('vi_VN');
  late final AnimationController _introController;

  final List<TextEditingController> _otpControllers =
      List<TextEditingController>.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List<FocusNode>.generate(
    6,
    (_) => FocusNode(),
  );

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    for (final TextEditingController controller in _otpControllers) {
      controller.dispose();
    }
    for (final FocusNode node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainTabShell(initialIndex: 0)),
      (Route<dynamic> route) => false,
    );
  }

  String _formatAmount(double amount) {
    return '${_moneyFormat.format(amount)} VND';
  }

  String _enteredOtp() {
    return _otpControllers
        .map((TextEditingController controller) => controller.text)
        .join();
  }

  void _onOtpChanged({required String value, required int index}) {
    if (value.isNotEmpty && index < _otpFocusNodes.length - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  void _onConfirm() {
    if (_enteredOtp().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Vui lòng nhập đủ 6 số OTP.', 'Please enter all 6 OTP digits.'),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WaterBillSuccessScreen(
          totalAmount: widget.totalAmount,
          customerName: widget.customerName,
          customerCode: widget.customerCode,
        ),
      ),
    );
  }

  Widget _reveal(int index, Widget child) {
    final double start = (index * 0.11).clamp(0, 0.72);
    final double end = (start + 0.3).clamp(0, 1);
    final CurvedAnimation animation = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildProgressLine() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: _primaryBlue,
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: _primaryBlue,
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: _primaryBlue,
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpRow() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = 8;
        final double fieldWidth =
            ((constraints.maxWidth - (gap * 5)) / 6).clamp(44.0, 52.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List<Widget>.generate(6, (int index) {
            return SizedBox(
              width: fieldWidth,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7E3FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      autofocus: index == 0,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _primaryBlue,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      cursorColor: _primaryBlue,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLength: 1,
                      onChanged: (String value) =>
                          _onOtpChanged(value: value, index: index),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: CCPAppBar(
        title: _t('Thanh toán hoá đơn', 'Bill payment'),
        backgroundColor: _surface,
        onBackPressed: () => Navigator.maybePop(context),
        actions: <Widget>[
          IconButton(
            onPressed: _goHome,
            icon: const Icon(Icons.home_rounded),
            color: _primaryBlue,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _reveal(
                0,
                Row(
                  children: <Widget>[
                    Text(
                      _t('XÁC THỰC OTP', 'OTP VERIFICATION'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _primaryBlue,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _t('Bước 3/4', 'Step 3/4'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF8E94AE),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _reveal(1, _buildProgressLine()),
              const SizedBox(height: 24),
              _reveal(
                2,
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF2FF),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: _primaryBlue,
                      size: 44,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _reveal(
                3,
                Center(
                  child: Text(
                    _t('Xác thực giao dịch', 'Transaction verification'),
                    style: GoogleFonts.poppins(
                      fontSize: 37,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1E35),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _reveal(
                4,
                Center(
                  child: Text(
                    _t(
                      'Vui lòng nhập mã SmartOTP 6 chữ số',
                      'Please enter the 6-digit OTP sent to ${widget.maskedPhone}',
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF7B819A),
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _reveal(5, _buildOtpRow()),
              const SizedBox(height: 12),
              _reveal(
                6,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEBFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.water_drop_rounded,
                          color: _primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _t('HÓA ĐƠN NƯỚC', 'WATER BILL'),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF8D92AA),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatAmount(widget.totalAmount),
                              style: GoogleFonts.poppins(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF27306E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _reveal(
                7,
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      _t('XÁC NHẬN', 'CONFIRM'),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
