import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'electric_bill_pay.dart';
import 'main_tab_shell.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';

class ElectricBillScreen extends StatefulWidget {
  const ElectricBillScreen({super.key});

  @override
  State<ElectricBillScreen> createState() => _ElectricBillScreenState();
}

class _ElectricBillScreenState extends State<ElectricBillScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _surface = Color(0xFFF6F7FF);

  final TextEditingController _customerCodeController = TextEditingController();
  final NumberFormat _moneyFormat = NumberFormat.decimalPattern('vi_VN');
  late final AnimationController _introController;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  bool _isLookingUp = false;
  String? _lookupError;
  _ElectricBillLookupResult? _lookupResult;

  final Map<String, Map<String, dynamic>> _demoBills =
      <String, Map<String, dynamic>>{
        'PE13000456281': <String, dynamic>{
          'aliasVi': 'Nhà riêng',
          'aliasEn': 'Home',
          'customerName': 'NGUYEN VAN AN',
          'serviceAddress': '123 Duong Lang, Ha Noi',
          'billingPeriodText': '03/2026',
          'dueDate': '2026-04-10',
          'usageKwh': 365,
          'amountVnd': 854000,
        },
        'PE13000998724': <String, dynamic>{
          'aliasVi': 'Văn phòng',
          'aliasEn': 'Office',
          'customerName': 'CONG TY AN PHAT',
          'serviceAddress': '18 Le Van Luong, Ha Noi',
          'billingPeriodText': '03/2026',
          'dueDate': '2026-04-12',
          'usageKwh': 512,
          'amountVnd': 1342545,
        },
      };

  final List<_RecentBillItem> _recentBills = <_RecentBillItem>[
    const _RecentBillItem(
      titleVi: 'Nhà riêng',
      titleEn: 'Home',
      customerCode: 'PE13000456281',
      icon: Icons.home_rounded,
    ),
    const _RecentBillItem(
      titleVi: 'Văn phòng',
      titleEn: 'Office',
      customerCode: 'PE13000998724',
      icon: Icons.apartment_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _customerCodeController.dispose();
    super.dispose();
  }

  String _normalizeCode(String raw) {
    return raw.trim().toUpperCase();
  }

  String _formatVnd(num value) {
    return '${_moneyFormat.format(value)} VND';
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainTabShell(initialIndex: 0)),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _lookupBill() async {
    final String code = _normalizeCode(_customerCodeController.text);
    final RegExp codePattern = RegExp(r'^PE\d{8,13}$');

    if (!codePattern.hasMatch(code)) {
      final String message = _t(
        'Mã khách hàng chưa đúng định dạng PE + 8-13 số.',
        'Customer code must follow PE + 8-13 digits.',
      );
      setState(() {
        _lookupError = message;
        _lookupResult = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLookingUp = true;
      _lookupError = null;
      _lookupResult = null;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> query = await FirebaseFirestore
          .instance
          .collection('electric_bills')
          .where('customerCode', isEqualTo: code)
          .limit(1)
          .get();

      if (!mounted) {
        return;
      }

      final Map<String, dynamic>? sourceData = query.docs.isNotEmpty
          ? query.docs.first.data()
          : _demoBills[code];

      if (sourceData == null) {
        final String message = _t(
          'Không tìm thấy hóa đơn cho mã khách hàng này.',
          'No bill found for this customer code.',
        );
        setState(() {
          _lookupError = message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.orange),
        );
        return;
      }

      final _ElectricBillLookupResult result =
          _ElectricBillLookupResult.fromMap(code, sourceData);

      setState(() {
        _lookupResult = result;
        _lookupError = null;
      });

      _saveToRecent(code, result.displayTitleVi, result.displayTitleEn);
      _showLookupSheet(result);
    } on FirebaseException catch (e) {
      final Map<String, dynamic>? demoData = _demoBills[code];
      if (demoData != null) {
        final _ElectricBillLookupResult result =
            _ElectricBillLookupResult.fromMap(code, demoData);
        if (!mounted) {
          return;
        }
        setState(() {
          _lookupResult = result;
          _lookupError = null;
        });
        _saveToRecent(code, result.displayTitleVi, result.displayTitleEn);
        _showLookupSheet(result);
        return;
      }

      if (!mounted) {
        return;
      }
      final String message = _t(
        'Lỗi tra cứu: ${e.message ?? e.code}',
        'Lookup failed: ${e.message ?? e.code}',
      );
      setState(() {
        _lookupError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      final String message = _t(
        'Không thể tra cứu lúc này, vui lòng thử lại.',
        'Unable to lookup now, please try again.',
      );
      setState(() {
        _lookupError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLookingUp = false;
        });
      }
    }
  }

  void _saveToRecent(String code, String titleVi, String titleEn) {
    final int existingIndex = _recentBills.indexWhere(
      (_RecentBillItem item) => item.customerCode == code,
    );

    if (existingIndex >= 0) {
      _recentBills.removeAt(existingIndex);
    }

    _recentBills.insert(
      0,
      _RecentBillItem(
        titleVi: titleVi,
        titleEn: titleEn,
        customerCode: code,
        icon: Icons.electric_meter_rounded,
      ),
    );

    if (_recentBills.length > 4) {
      _recentBills.removeLast();
    }
  }

  void _showLookupSheet(_ElectricBillLookupResult result) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E5F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _t('Kết quả tra cứu', 'Lookup result'),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B1E30),
                ),
              ),
              const SizedBox(height: 12),
              _sheetRow(
                _t('Mã khách hàng', 'Customer code'),
                result.customerCode,
              ),
              _sheetRow(
                _t('Tên gợi nhớ', 'Alias'),
                _t(result.displayTitleVi, result.displayTitleEn),
              ),
              _sheetRow(
                _t('Kỳ hóa đơn', 'Billing period'),
                result.billingPeriod,
              ),
              _sheetRow(_t('Hạn thanh toán', 'Due date'), result.dueDate),
              _sheetRow(
                _t('Sản lượng', 'Usage'),
                '${result.usageKwh.toStringAsFixed(0)} kWh',
              ),
              _sheetRow(
                _t('Số tiền', 'Amount'),
                _formatVnd(result.amountVnd),
                valueColor: _primaryBlue,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(
                        builder: (_) => ElectricBillPayScreen(
                          customerCode: result.customerCode,
                          customerName: result.customerName,
                          serviceAddress: result.serviceAddress,
                          usageKwh: result.usageKwh,
                          billingPeriod: result.billingPeriod,
                          totalAmount: result.amountVnd,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _t('Tiếp tục thanh toán', 'Continue to pay'),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF767C96),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF1B1E30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reveal(int index, Widget child) {
    final double start = (index * 0.09).clamp(0, 0.75);
    final double end = (start + 0.3).clamp(0, 1).toDouble();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: CCPAppBar(
        title: 'Thanh toán hóa đơn',
        backgroundColor: _surface,
        onBackPressed: () => Navigator.maybePop(context),
        actions: [
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
                Text(
                  _t('BƯỚC 1/4', 'STEP 1/4'),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _reveal(
                1,
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _t('Hóa đơn tiền điện', 'Electricity bill'),
                        style: GoogleFonts.poppins(
                          fontSize: 37,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF191B2A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStepPills(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _reveal(
                2,
                Text(
                  _t(
                    'Vui lòng nhập mã khách hàng để tra cứu hóa đơn mới nhất.',
                    'Please enter your customer code to fetch the latest bill.',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.45,
                    color: const Color(0xFF7A7F98),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _reveal(3, _buildLookupCard()),
              if (_lookupResult != null || _lookupError != null) ...<Widget>[
                const SizedBox(height: 10),
                _reveal(4, _buildLookupFeedbackCard()),
              ],
              const SizedBox(height: 22),
              _reveal(
                5,
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _t('Hóa đơn gần đây', 'Recent bills'),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1B1E30),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: _primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        _t('Xem tất cả', 'View all'),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ..._recentBills.asMap().entries.map((
                MapEntry<int, _RecentBillItem> entry,
              ) {
                return _reveal(
                  6 + entry.key,
                  _buildRecentBillCard(entry.value),
                );
              }),
              const SizedBox(height: 18),
              _reveal(10, _buildInfoCard()),
              const SizedBox(height: 16),
              _reveal(11, _buildAutoPayBanner()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepPills() {
    return Row(
      children: <Widget>[
        _pill(isActive: true),
        const SizedBox(width: 6),
        _pill(isActive: false),
        const SizedBox(width: 6),
        _pill(isActive: false),
        const SizedBox(width: 6),
        _pill(isActive: false),
      ],
    );
  }

  Widget _pill({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: isActive ? 34 : 14,
      height: 7,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: isActive ? _primaryBlue : _primaryBlue.withValues(alpha: 0.18),
      ),
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
            _t('MÃ KHÁCH HÀNG', 'CUSTOMER CODE'),
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
            style: GoogleFonts.poppins(
              color: const Color(0xFF2A2D45),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'e.g., PE13000456281',
              hintStyle: GoogleFonts.poppins(
                color: const Color(0xFFA3A7BE),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              suffixIcon: Icon(
                Icons.electric_bolt,
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
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 49,
            child: ElevatedButton.icon(
              onPressed: _isLookingUp ? null : _lookupBill,
              icon: _isLookingUp
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                _isLookingUp
                    ? _t('Đang tra cứu...', 'Looking up...')
                    : _t('Tra cứu hóa đơn', 'Lookup bill'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              iconAlignment: IconAlignment.end,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLookupFeedbackCard() {
    final bool isSuccess = _lookupResult != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFFEAF2FF) : const Color(0xFFFFF3F1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isSuccess
              ? _primaryBlue.withValues(alpha: 0.22)
              : const Color(0xFFFFD8D2),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
            color: isSuccess ? _primaryBlue : const Color(0xFFE25A4D),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSuccess
                  ? _t(
                      'Đã tìm thấy hóa đơn: ${_formatVnd(_lookupResult!.amountVnd)}',
                      'Bill found: ${_formatVnd(_lookupResult!.amountVnd)}',
                    )
                  : (_lookupError ?? ''),
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isSuccess
                    ? const Color(0xFF233487)
                    : const Color(0xFFAF3C33),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBillCard(_RecentBillItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _customerCodeController.text = item.customerCode;
            _lookupBill();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: _primaryBlue, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _t(item.titleVi, item.titleEn),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1B1E30),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.customerCode,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF8A8FA7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _primaryBlue.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info, color: _primaryBlue, size: 13),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('Tìm mã khách hàng ở đâu?', 'Where is my customer code?'),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B1E30),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PRO TIP',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: _primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            _t(
              'Mã khách hàng gồm 11 ký tự bắt đầu bằng PE, có thể tìm thấy trên hóa đơn giấy hoặc trong app EVN.',
              'Your customer code has 11 characters and starts with PE. You can find it on your paper bill or in the EVN app.',
            ),
            style: GoogleFonts.poppins(
              fontSize: 11,
              height: 1.4,
              color: const Color(0xFF717792),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoPayBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF131A57), Color(0xFF0B0F31)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('Thanh toán tự động', 'Auto payment'),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              'Không bao giờ quên hạn. Kích hoạt thanh toán một chạm ngay.',
              'Never miss your due date. Enable one-tap auto payment now.',
            ),
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _primaryBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              _t('CÀI ĐẶT NGAY', 'SET UP NOW'),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ElectricBillLookupResult {
  const _ElectricBillLookupResult({
    required this.customerCode,
    required this.customerName,
    required this.serviceAddress,
    required this.displayTitleVi,
    required this.displayTitleEn,
    required this.billingPeriod,
    required this.dueDate,
    required this.amountVnd,
    required this.usageKwh,
  });

  final String customerCode;
  final String customerName;
  final String serviceAddress;
  final String displayTitleVi;
  final String displayTitleEn;
  final String billingPeriod;
  final String dueDate;
  final double amountVnd;
  final double usageKwh;

  static DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  static double _parseNum(dynamic raw, {double fallback = 0}) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw) ?? fallback;
    }
    return fallback;
  }

  factory _ElectricBillLookupResult.fromMap(
    String customerCode,
    Map<String, dynamic> data,
  ) {
    final DateTime now = DateTime.now();
    final DateFormat monthFmt = DateFormat('MM/yyyy');
    final DateFormat dateFmt = DateFormat('dd/MM/yyyy');
    final DateTime? dueDateRaw = _parseDate(data['dueDate']);
    final DateTime periodDate = _parseDate(data['billingPeriod']) ?? now;

    return _ElectricBillLookupResult(
      customerCode: customerCode,
      customerName: (data['customerName'] ?? data['fullName'] ?? 'KHACH HANG')
          .toString(),
      serviceAddress: (data['serviceAddress'] ?? data['address'] ?? 'Ha Noi')
          .toString(),
      displayTitleVi: (data['aliasVi'] ?? data['alias'] ?? 'Khách hàng điện')
          .toString(),
      displayTitleEn: (data['aliasEn'] ?? data['alias'] ?? 'Electric customer')
          .toString(),
      billingPeriod:
          (data['billingPeriodText']?.toString().trim().isNotEmpty ?? false)
          ? data['billingPeriodText'].toString()
          : monthFmt.format(periodDate),
      dueDate: dueDateRaw == null ? '-' : dateFmt.format(dueDateRaw),
      amountVnd: _parseNum(data['amountVnd'], fallback: 0),
      usageKwh: _parseNum(data['usageKwh'], fallback: 0),
    );
  }
}

class _RecentBillItem {
  const _RecentBillItem({
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
