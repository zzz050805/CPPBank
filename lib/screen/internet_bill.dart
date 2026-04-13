import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/app_text.dart';
import '../services/payment_service.dart';
import '../services/user_firestore_service.dart';
import '../widget/ccp_app_bar.dart';
import '../widget/custom_card_selector.dart';
import '../widget/pin_popup.dart';
import 'bill_mock_data.dart';
import 'main_tab_shell.dart';

class InternetBillScreen extends StatefulWidget {
  const InternetBillScreen({super.key, this.sourceCardId});

  final String? sourceCardId;

  @override
  State<InternetBillScreen> createState() => _InternetBillScreenState();
}

class _InternetBillScreenState extends State<InternetBillScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _surface = Color(0xFFF6F7FF);

  final TextEditingController _customerCodeController = TextEditingController();
  late final AnimationController _introController;

  bool _isLookingUp = false;
  final String _selectedServiceType = 'internet';
  String? _lookupError;
  _InternetBillLookupResult? _lookupResult;

  final Map<String, _InternetBillLookupResult> _demoBills =
      <String, _InternetBillLookupResult>{
        for (final MockInvoice invoice in mockInvoices.values)
          if (invoice.serviceType == 'internet')
            invoice.code: _InternetBillLookupResult(
              customerCode: invoice.code,
              serviceType: invoice.serviceType,
              aliasVi: invoice.aliasVi,
              aliasEn: invoice.aliasEn,
              customerName: invoice.customerName,
              provider: invoice.provider,
              serviceAddress: invoice.serviceAddress,
              billingPeriod: invoice.billingPeriodText,
              dueDate: invoice.dueDateIso,
              usageValue: invoice.usageValue,
              usageUnit: invoice.usageUnit,
              amountVnd: invoice.amountVnd.toDouble(),
            ),
      };

  final List<_RecentInternetBillItem> _recentBills = <_RecentInternetBillItem>[
    const _RecentInternetBillItem(
      titleVi: 'FPT Telecom',
      titleEn: 'FPT Telecom',
      customerCode: 'INFPT223344',
      serviceType: 'internet',
      icon: Icons.wifi_rounded,
    ),
    const _RecentInternetBillItem(
      titleVi: 'VNPT',
      titleEn: 'VNPT',
      customerCode: 'INVNPT998877',
      serviceType: 'internet',
      icon: Icons.router_rounded,
    ),
    const _RecentInternetBillItem(
      titleVi: 'Viettel',
      titleEn: 'Viettel',
      customerCode: 'INVT225588',
      serviceType: 'internet',
      icon: Icons.network_wifi_rounded,
    ),
  ];

  String _t(String vi, String en) => AppText.tr(context, vi, en);
  String _tr(String key) => AppText.text(context, key);

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

  String _serviceLabel(String serviceType) {
    return _tr('internet_service');
  }

  String _normalizeCode(String raw) {
    return raw.trim().toUpperCase();
  }

  RegExp _patternForSelectedService() {
    return RegExp(r'^IN[A-Z0-9]{6,12}$');
  }

  String _validationMessage() {
    return _t(
      'Mã khách hàng chưa đúng định dạng IN + ký tự/số.',
      'Customer code must follow IN + alphanumeric characters.',
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

  List<_RecentInternetBillItem> get _filteredRecentBills {
    return _recentBills
        .where(
          (_RecentInternetBillItem item) =>
              item.serviceType == _selectedServiceType,
        )
        .toList(growable: false);
  }

  Future<void> _lookupBill() async {
    final String code = _normalizeCode(_customerCodeController.text);
    final RegExp codePattern = _patternForSelectedService();

    if (!codePattern.hasMatch(code)) {
      final String message = _validationMessage();
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
          .collection('internet_bills')
          .where('customerCode', isEqualTo: code)
          .limit(1)
          .get();

      if (!mounted) {
        return;
      }

      _InternetBillLookupResult? result;
      final _InternetBillLookupResult? mockResult = _demoBills[code];
      if (mockResult != null) {
        result = mockResult;
      }

      final Map<String, dynamic>? sourceData = query.docs.isNotEmpty
          ? query.docs.first.data()
          : null;

      if (result == null && sourceData != null) {
        result = _InternetBillLookupResult.fromMap(
          code,
          sourceData,
          _selectedServiceType,
        );
      }

      if (result == null) {
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

      setState(() {
        _lookupResult = result;
        _lookupError = null;
      });

      _saveToRecent(result);
      _openConfirmationScreen(result);
    } on FirebaseException catch (e) {
      final _InternetBillLookupResult? demoResult = _demoBills[code];
      if (demoResult != null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _lookupResult = demoResult;
          _lookupError = null;
        });
        _saveToRecent(demoResult);
        _openConfirmationScreen(demoResult);
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

  void _saveToRecent(_InternetBillLookupResult result) {
    final int existingIndex = _recentBills.indexWhere(
      (_RecentInternetBillItem item) =>
          item.customerCode == result.customerCode,
    );

    if (existingIndex >= 0) {
      _recentBills.removeAt(existingIndex);
    }

    _recentBills.insert(
      0,
      _RecentInternetBillItem(
        titleVi: result.aliasVi,
        titleEn: result.aliasEn,
        customerCode: result.customerCode,
        serviceType: 'internet',
        icon: Icons.wifi_rounded,
      ),
    );

    if (_recentBills.length > 6) {
      _recentBills.removeLast();
    }
  }

  void _openConfirmationScreen(_InternetBillLookupResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InternetBillConfirmationScreen(
          lookupResult: result,
          serviceLabel: _serviceLabel(result.serviceType),
          sourceCardId: widget.sourceCardId,
        ),
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
            'MÃ KHÁCH HÀNG',
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
              hintText: 'e.g., INFPT223344',
              hintStyle: GoogleFonts.poppins(
                color: const Color(0xFFA3A7BE),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              suffixIcon: Icon(
                Icons.wifi_rounded,
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
            onSubmitted: (_) => _lookupBill(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _isLookingUp ? null : _lookupBill,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                elevation: 0,
              ),
              child: _isLookingUp
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    )
                  : Text(
                      _t('Tra cứu hóa đơn', 'Lookup bill'),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          if (_lookupError != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _lookupError!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.redAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (_lookupResult != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _t('Đã sẵn sàng thanh toán.', 'Ready to pay.'),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF2B2F50),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentCard(_RecentInternetBillItem item) {
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
      ),
      body: Stack(
        children: <Widget>[
          SafeArea(
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
                          child: Icon(
                            Icons.wifi_rounded,
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
                      _serviceLabel(_selectedServiceType),
                      style: GoogleFonts.poppins(
                        fontSize: 39,
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
                        'Nhập mã khách hàng để tra cứu và thanh toán ngay trên CCP BANK.',
                        'Enter customer code to lookup and pay instantly on CCP BANK.',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: const Color(0xFF7D829A),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _reveal(4, _buildLookupCard()),
                  const SizedBox(height: 24),
                  _reveal(
                    5,
                    Text(
                      _t('Hóa đơn gần đây', 'Recent bills'),
                      style: GoogleFonts.poppins(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2B2F50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._filteredRecentBills.map(_buildRecentCard),
                  if (_filteredRecentBills.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _t(
                          'Chưa có mã gần đây cho nhóm dịch vụ này.',
                          'No recent codes for this service group.',
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF868BA4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InternetBillSuccessScreen extends StatelessWidget {
  const InternetBillSuccessScreen({super.key, required this.receipt});

  final InternetBillReceipt receipt;

  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _surface = Color(0xFFF6F7FF);

  String _t(BuildContext context, String vi, String en) =>
      AppText.tr(context, vi, en);

  String _tr(BuildContext context, String key) => AppText.text(context, key);

  String _formatAmount(BuildContext context, double amount) {
    final NumberFormat format = NumberFormat.decimalPattern('vi_VN');
    return '${format.format(amount)} ${_t(context, 'đ', 'VND')}';
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainTabShell(initialIndex: 0)),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String paidTime = DateFormat(
      'dd/MM/yyyy HH:mm:ss',
    ).format(receipt.paidAt);

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
                        'Thanh toán hoá đơn internet thành công',
                        'Internet bill payment completed',
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
                      _formatAmount(context, receipt.amountVnd),
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
                    _row(
                      context,
                      _tr(context, 'service'),
                      receipt.serviceLabel,
                    ),
                    const Divider(height: 22),
                    _row(
                      context,
                      _t(context, 'Nhà cung cấp', 'Provider'),
                      receipt.provider,
                    ),
                    const Divider(height: 22),
                    _row(
                      context,
                      _t(context, 'Mã khách hàng', 'Customer code'),
                      receipt.customerCode,
                    ),
                    const Divider(height: 22),
                    _row(
                      context,
                      _t(context, 'Khách hàng', 'Customer'),
                      receipt.customerName,
                    ),
                    const Divider(height: 22),
                    _row(
                      context,
                      _tr(context, 'transaction_id'),
                      receipt.transactionCode,
                    ),
                    const Divider(height: 22),
                    _row(context, _tr(context, 'time'), paidTime),
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

  Widget _row(BuildContext context, String label, String value) {
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

class _RecentInternetBillItem {
  const _RecentInternetBillItem({
    required this.titleVi,
    required this.titleEn,
    required this.customerCode,
    required this.serviceType,
    required this.icon,
  });

  final String titleVi;
  final String titleEn;
  final String customerCode;
  final String serviceType;
  final IconData icon;
}

class _InternetBillLookupResult {
  const _InternetBillLookupResult({
    required this.customerCode,
    required this.serviceType,
    required this.aliasVi,
    required this.aliasEn,
    required this.customerName,
    required this.provider,
    required this.serviceAddress,
    required this.billingPeriod,
    required this.dueDate,
    required this.usageValue,
    required this.usageUnit,
    required this.amountVnd,
  });

  final String customerCode;
  final String serviceType;
  final String aliasVi;
  final String aliasEn;
  final String customerName;
  final String provider;
  final String serviceAddress;
  final String billingPeriod;
  final String dueDate;
  final double usageValue;
  final String usageUnit;
  final double amountVnd;

  factory _InternetBillLookupResult.fromMap(
    String customerCode,
    Map<String, dynamic> source,
    String fallbackServiceType,
  ) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    return _InternetBillLookupResult(
      customerCode: customerCode,
      serviceType: (source['serviceType'] as String?) ?? fallbackServiceType,
      aliasVi: (source['aliasVi'] as String?) ?? 'Internet',
      aliasEn: (source['aliasEn'] as String?) ?? 'Internet',
      customerName: (source['customerName'] as String?) ?? '',
      provider: (source['provider'] as String?) ?? '',
      serviceAddress: (source['serviceAddress'] as String?) ?? '',
      billingPeriod:
          (source['billingPeriodText'] as String?) ??
          (source['billingPeriod'] as String?) ??
          '',
      dueDate:
          (source['dueDate'] as String?) ??
          (source['dueDateIso'] as String?) ??
          '',
      usageValue: toDouble(source['usageValue']),
      usageUnit: (source['usageUnit'] as String?) ?? 'Mbps',
      amountVnd: toDouble(
        source['amountVnd'] ?? source['totalAmount'] ?? source['amount'],
      ),
    );
  }
}

class InternetBillReceipt {
  const InternetBillReceipt({
    required this.transactionCode,
    required this.paidAt,
    required this.customerCode,
    required this.customerName,
    required this.provider,
    required this.serviceLabel,
    required this.amountVnd,
  });

  final String transactionCode;
  final DateTime paidAt;
  final String customerCode;
  final String customerName;
  final String provider;
  final String serviceLabel;
  final double amountVnd;
}

class InternetBillConfirmationScreen extends StatefulWidget {
  const InternetBillConfirmationScreen({
    super.key,
    required this.lookupResult,
    required this.serviceLabel,
    this.sourceCardId,
  });

  final _InternetBillLookupResult lookupResult;
  final String serviceLabel;
  final String? sourceCardId;

  @override
  State<InternetBillConfirmationScreen> createState() =>
      _InternetBillConfirmationScreenState();
}

class _InternetBillConfirmationScreenState
    extends State<InternetBillConfirmationScreen> {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _surface = Color(0xFFF6F7FF);

  final NumberFormat _moneyFormat = NumberFormat.decimalPattern('vi_VN');
  bool _isPaying = false;
  String? _selectedSourceCardId;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _selectedSourceCardId = widget.sourceCardId;
  }

  String _formatVnd(double amount) {
    return '${_moneyFormat.format(amount)} VND';
  }

  String _resolveUid() {
    return (UserFirestoreService.instance.currentUserDocId ??
            FirebaseAuth.instance.currentUser?.uid ??
            '')
        .trim();
  }

  Widget _buildPaymentMethodSelector() {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0FF),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _primaryBlue.withValues(alpha: 0.9),
            width: 1.6,
          ),
        ),
        child: Text(
          AppText.text(context, 'card_unavailable'),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF5F6682),
          ),
        ),
      );
    }

    return CustomCardSelector(
      uid: uid,
      selectedCardId: _selectedSourceCardId,
      backgroundColor: const Color(0xFFEAF0FF),
      textColor: const Color(0xFF242842),
      onChanged: (CustomCardSelection selection) {
        if (!mounted || _selectedSourceCardId == selection.id) {
          return;
        }
        setState(() {
          _selectedSourceCardId = selection.id;
        });
      },
    );
  }

  Future<void> _confirmAndPay() async {
    if (_isPaying) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PinPopupWidget(
        onSuccess: () async {
          if (!mounted || _isPaying) {
            return;
          }

          setState(() {
            _isPaying = true;
          });

          try {
            final PaymentProcessResult paymentResult = await PaymentService
                .instance
                .processPayment(
                  amount: widget.lookupResult.amountVnd,
                  billType: 'internet',
                  billId: widget.lookupResult.customerCode,
                  sourceCardId: _selectedSourceCardId,
                );

            if (!mounted) {
              return;
            }

            final InternetBillReceipt receipt = InternetBillReceipt(
              transactionCode: paymentResult.transactionId,
              paidAt: paymentResult.processedAt,
              customerCode: widget.lookupResult.customerCode,
              customerName: widget.lookupResult.customerName,
              provider: widget.lookupResult.provider,
              serviceLabel: widget.serviceLabel,
              amountVnd: paymentResult.amount,
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => InternetBillSuccessScreen(receipt: receipt),
              ),
            );
          } catch (e) {
            if (!mounted) {
              return;
            }

            final String message = e
                .toString()
                .replaceFirst('Exception: ', '')
                .replaceFirst('PaymentServiceException: ', '')
                .trim();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  message.isEmpty
                      ? _t(
                          'Thanh toán thất bại, vui lòng thử lại.',
                          'Payment failed, please try again.',
                        )
                      : message,
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          } finally {
            if (mounted) {
              setState(() {
                _isPaying = false;
              });
            }
          }
        },
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
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
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF1E243A),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: CCPAppBar(
        title: _t('Xác nhận hóa đơn Internet', 'Internet bill confirmation'),
        backgroundColor: _surface,
        onBackPressed: () => Navigator.maybePop(context),
      ),
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _t('BƯỚC 2/3', 'STEP 2/3'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: _primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
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
                            color: _primaryBlue.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t(
                      'Xác nhận thông tin thanh toán',
                      'Confirm payment details',
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF23274B),
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
                        _row(
                          _t('Tên khách hàng', 'Customer name'),
                          widget.lookupResult.customerName,
                        ),
                        const Divider(height: 22),
                        _row(
                          AppText.customerCode(context),
                          widget.lookupResult.customerCode,
                        ),
                        const Divider(height: 22),
                        _row(_t('Dịch vụ', 'Service'), widget.serviceLabel),
                        const Divider(height: 22),
                        _row(
                          AppText.provider(context),
                          widget.lookupResult.provider,
                        ),
                        const Divider(height: 22),
                        _row(
                          _t('Số tiền', 'Amount'),
                          _formatVnd(widget.lookupResult.amountVnd),
                          valueColor: _primaryBlue,
                        ),
                        const Divider(height: 22),
                        _row(_t('Phí', 'Fee'), _formatVnd(0)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _t('Phương thức thanh toán', 'Payment method'),
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1B1E30),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentMethodSelector(),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isPaying ? null : _confirmAndPay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _t('Thanh toán', 'Pay now'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isPaying)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: Center(
                  child: Container(
                    width: 170,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.8),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _t(
                            'Đang xử lý thanh toán...',
                            'Processing payment...',
                          ),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2A2F4E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
