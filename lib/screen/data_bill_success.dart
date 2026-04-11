import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'main_tab_shell.dart';

class DataBillSuccessScreen extends StatelessWidget {
  const DataBillSuccessScreen({
    super.key,
    required this.phoneNumber,
    required this.planName,
    required this.totalText,
  });

  final String phoneNumber;
  final String planName;
  final String totalText;

  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _surface = Color(0xFFF6F7FF);

  String _t(BuildContext context, String vi, String en) =>
      AppText.tr(context, vi, en);

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainTabShell(initialIndex: 0)),
      (Route<dynamic> route) => false,
    );
  }

  String _maskedPhone() {
    if (phoneNumber.length < 4) return phoneNumber;
    return '${phoneNumber.substring(0, 3)} *** ${phoneNumber.substring(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final String now = DateFormat('HH:mm, dd/MM/yyyy').format(DateTime.now());
    final String transactionCode =
        '#PAY${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    return Scaffold(
      backgroundColor: _surface,
      appBar: CCPAppBar(
        title: _t(context, 'Thanh toán hoá đơn', 'Bill payment'),
        backgroundColor: _surface,
        onBackPressed: () => _goHome(context),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: <Widget>[
              const _StepLine(activeCount: 3),
              const SizedBox(height: 20),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      _primaryBlue.withValues(alpha: 0.75),
                      _primaryBlue,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 54,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _t(context, 'Nạp data thành công', 'Top-up successful'),
                style: GoogleFonts.poppins(
                  fontSize: 31,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF252A49),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  context,
                  'Giao dịch của bạn đã được xử lý thành công. Dung lượng data đã được cộng vào tài khoản.',
                  'Your transaction has been completed successfully.',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF8288A2),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: <Widget>[
                    _row(
                      _t(context, 'Mã giao dịch', 'Transaction ID'),
                      transactionCode,
                    ),
                    const Divider(height: 18),
                    _row(
                      _t(context, 'Số điện thoại', 'Phone number'),
                      _maskedPhone(),
                    ),
                    const Divider(height: 18),
                    _row(_t(context, 'Gói cước', 'Package'), planName),
                    const Divider(height: 18),
                    _row(_t(context, 'Thời gian', 'Time'), now),
                    const Divider(height: 18),
                    _row(
                      _t(context, 'Tổng thanh toán', 'Total payment'),
                      totalText,
                      strong: true,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _goHome(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _t(context, 'QUAY VỀ TRANG CHỦ', 'BACK TO HOME'),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool strong = false}) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF7D839D),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: strong ? 24 : 13,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
              color: strong ? _primaryBlue : const Color(0xFF2F3554),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF000DC0);

    return Row(
      children: List<Widget>.generate(3, (int index) {
        final bool active = index < activeCount;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: active
                    ? primaryBlue
                    : primaryBlue.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        );
      }),
    );
  }
}
