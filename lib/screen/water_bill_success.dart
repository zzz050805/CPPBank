import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'main_tab_shell.dart';

class WaterBillSuccessScreen extends StatelessWidget {
  const WaterBillSuccessScreen({
    super.key,
    required this.totalAmount,
    required this.customerName,
    required this.customerCode,
  });

  final double totalAmount;
  final String customerName;
  final String customerCode;

  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _surface = Color(0xFFF6F7FF);

  String _t(BuildContext context, String vi, String en) =>
      AppText.tr(context, vi, en);

  String _tr(BuildContext context, String key) => AppText.text(context, key);

  String _formatAmount() {
    final NumberFormat format = NumberFormat.decimalPattern('vi_VN');
    return '${format.format(totalAmount)} VND';
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainTabShell(initialIndex: 0)),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String now = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

    return Scaffold(
      backgroundColor: _surface,
      appBar: CCPAppBar(
        title: _t(context, 'Hoàn tất', 'Bill payment'),
        backgroundColor: _surface,
        onBackPressed: () => _goHome(context),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _primaryBlue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 36,
                        color: _primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t(
                        context,
                        'Thanh toán hoá đơn nước thành công',
                        'Water bill payment completed',
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C2035),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatAmount(),
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: <Widget>[
                    _infoRow(
                      context,
                      _t(context, 'Khách hàng', 'Customer'),
                      customerName,
                    ),
                    const Divider(height: 22),
                    _infoRow(
                      context,
                      _t(context, 'Mã khách hàng', 'Customer code'),
                      customerCode,
                    ),
                    const Divider(height: 22),
                    _infoRow(context, _t(context, 'Thời gian', 'Time'), now),
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
                    _tr(context, 'back_to_home').toUpperCase(),
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

  Widget _infoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF7A8099),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E243A),
            ),
          ),
        ),
      ],
    );
  }
}
