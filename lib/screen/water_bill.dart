import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'bill_mock_data.dart';
import 'main_tab_shell.dart';
import 'water_bill_pay.dart';

class WaterBillScreen extends StatefulWidget {
  const WaterBillScreen({super.key});

  @override
  State<WaterBillScreen> createState() => _WaterBillScreenState();
}

class _WaterBillScreenState extends State<WaterBillScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _surface = Color(0xFFF6F7FF);

  final TextEditingController _customerCodeController = TextEditingController();
  late final AnimationController _introController;

  final Map<String, _WaterBillLookupResult> _demoBills =
      <String, _WaterBillLookupResult>{
        for (final MockInvoice invoice in mockInvoices.values)
          if (invoice.serviceType == 'water')
            invoice.code: _WaterBillLookupResult(
              customerName: invoice.customerName,
              serviceAddress: invoice.serviceAddress,
              billingPeriod: invoice.billingPeriodText,
              usageM3: invoice.usageValue,
              totalAmount: invoice.amountVnd.toDouble(),
            ),
      };

  final List<_RecentWaterBillItem> _recentBills = <_RecentWaterBillItem>[
    const _RecentWaterBillItem(
      titleVi: 'Nhà riêng',
      titleEn: 'Home',
      customerCode: 'WA88000123456',
      icon: Icons.home_rounded,
    ),
    const _RecentWaterBillItem(
      titleVi: 'Phòng trọ',
      titleEn: 'Rental room',
      customerCode: 'WA88000654321',
      icon: Icons.apartment_rounded,
    ),
  ];

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _customerCodeController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainTabShell(initialIndex: 0)),
      (Route<dynamic> route) => false,
    );
  }

  void _fillCode(String code) {
    setState(() {
      _customerCodeController.text = code;
      _customerCodeController.selection = TextSelection.collapsed(
        offset: code.length,
      );
    });
  }

  void _lookupWaterBill() {
    final String code = _customerCodeController.text.trim().toUpperCase();
    final RegExp codePattern = RegExp(r'^WA\d{11}$');

    if (!codePattern.hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Vui lòng nhập mã danh bộ hợp lệ (WA + 11 số).',
              'Please enter a valid customer code (WA + 11 digits).',
            ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final _WaterBillLookupResult? result = _demoBills[code];
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Chưa tìm thấy hóa đơn cho mã $code.',
              'No bill found for code $code.',
            ),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaterBillPayScreen(
          customerCode: code,
          customerName: result.customerName,
          serviceAddress: result.serviceAddress,
          usageM3: result.usageM3,
          billingPeriod: result.billingPeriod,
          totalAmount: result.totalAmount,
        ),
      ),
    );
  }

  Widget _reveal(int index, Widget child) {
    final double start = (index * 0.11).clamp(0, 0.72);
    final double end = (start + 0.32).clamp(0, 1);
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
              color: _primaryBlue.withValues(alpha: 0.14),
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

  Widget _buildLookupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEBFF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('MÃ DANH BỘ', 'CUSTOMER CODE'),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: _primaryBlue.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _customerCodeController,
            textCapitalization: TextCapitalization.characters,
            style: GoogleFonts.poppins(
              color: const Color(0xFF2A2D45),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'e.g., WA88000123456',
              hintStyle: GoogleFonts.poppins(
                color: const Color(0xFFA3A7BE),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              suffixIcon: Icon(
                Icons.water_drop_rounded,
                size: 18,
                color: _primaryBlue.withValues(alpha: 0.65),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _lookupWaterBill(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCard(_RecentWaterBillItem item) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _fillCode(item.customerCode),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEDEBFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: _primaryBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _t(item.titleVi, item.titleEn),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2F3355),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.customerCode,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF8A8FA8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _primaryBlue.withValues(alpha: 0.45),
              size: 24,
            ),
          ],
        ),
      ),
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
                      _t('BƯỚC 1/3', 'STEP 1/3'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _primaryBlue,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEBFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        color: _primaryBlue,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _reveal(1, _buildProgressLine()),
              const SizedBox(height: 22),
              _reveal(
                2,
                Text(
                  _t('Hóa đơn Tiền nước', 'Water bill'),
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF23274B),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _reveal(
                3,
                Text(
                  _t(
                    'Vui lòng nhập mã danh bộ để tra cứu hóa đơn mới nhất.',
                    'Please enter your customer code to fetch the latest bill.',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: const Color(0xFF7D829A),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _reveal(4, _buildLookupCard()),
              const SizedBox(height: 24),
              _reveal(
                5,
                Row(
                  children: <Widget>[
                    Text(
                      _t('Hóa đơn gần đây', 'Recent bills'),
                      style: GoogleFonts.poppins(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2B2F50),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _t(
                                'Đã hiển thị toàn bộ hóa đơn gần đây.',
                                'All recent bills are shown.',
                              ),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        _t('Xem tất cả', 'See all'),
                        style: GoogleFonts.poppins(
                          color: _primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _reveal(6, _buildRecentCard(_recentBills[0])),
              const SizedBox(height: 10),
              _reveal(7, _buildRecentCard(_recentBills[1])),
              const SizedBox(height: 24),
              _reveal(
                8,
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _lookupWaterBill,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      _t('TRA CỨU HÓA ĐƠN', 'LOOK UP BILL'),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
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

class _RecentWaterBillItem {
  const _RecentWaterBillItem({
    required this.titleVi,
    required this.titleEn,
    required this.customerCode,
    required this.icon,
  });

  final String titleVi;
  final String titleEn;
  final String customerCode;
  final IconData icon;
}

class _WaterBillLookupResult {
  const _WaterBillLookupResult({
    required this.customerName,
    required this.serviceAddress,
    required this.billingPeriod,
    required this.usageM3,
    required this.totalAmount,
  });

  final String customerName;
  final String serviceAddress;
  final String billingPeriod;
  final double usageM3;
  final double totalAmount;
}
