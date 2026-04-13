import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'electric_bill_success.dart';
import '../services/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/payment_service.dart';
import '../widget/pin_popup.dart';
import '../widget/ccp_app_bar.dart';
import '../widget/custom_card_selector.dart';

class ElectricBillPayScreen extends StatefulWidget {
  const ElectricBillPayScreen({
    super.key,
    this.customerCode = 'PE13000456281',
    this.customerName = 'NGUYEN VAN AN',
    this.serviceAddress = '123 Duong Lang, Ha Noi',
    this.usageKwh = 450,
    this.billingPeriod = '10/2023',
    this.totalAmount = 1120500,
    this.sourceCardId,
  });

  final String customerCode;
  final String customerName;
  final String serviceAddress;
  final double usageKwh;
  final String billingPeriod;
  final double totalAmount;
  final String? sourceCardId;

  @override
  State<ElectricBillPayScreen> createState() => _ElectricBillPayScreenState();
}

class _ElectricBillPayScreenState extends State<ElectricBillPayScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _surface = Color(0xFFF6F7FF);

  final NumberFormat _moneyFormat = NumberFormat.decimalPattern('vi_VN');
  late final AnimationController _introController;
  bool _isSubmitting = false;
  String? _selectedSourceCardId;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _selectedSourceCardId = widget.sourceCardId;
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  String _formatVnd(double amount) {
    return '${_moneyFormat.format(amount)}d';
  }

  String _resolveUid() {
    return (UserFirestoreService.instance.currentUserDocId ??
            FirebaseAuth.instance.currentUser?.uid ??
            '')
        .trim();
  }

  Future<void> _processPayment() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await PaymentService.instance.processPayment(
        amount: widget.totalAmount,
        billType: 'electric',
        billId: widget.customerCode,
        sourceCardId: _selectedSourceCardId,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ElectricBillSuccessScreen(
            totalAmount: widget.totalAmount,
            customerName: widget.customerName,
            customerCode: widget.customerCode,
          ),
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
                    'Thanh toán thất bại. Vui lòng thử lại.',
                    'Payment failed. Please try again.',
                  )
                : message,
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _reveal(int index, Widget child) {
    final double start = (index * 0.12).clamp(0, 0.75);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: CCPAppBar(
        title: _t('Thanh toán hoá đơn', 'Payment'),
        backgroundColor: _surface,
        onBackPressed: () => Navigator.maybePop(context),
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
                      _t('BƯỚC 2/3', 'STEP 2/3'),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _primaryBlue,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _t('Xác nhận', 'Confirm'),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF9A9FB6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _reveal(1, _buildProgressLine()),
              const SizedBox(height: 14),
              _reveal(
                2,
                Text(
                  _t('Kiểm tra hóa đơn', 'Review bill'),
                  style: GoogleFonts.poppins(
                    fontSize: 43,
                    height: 1.04,
                    color: const Color(0xFF1A1E35),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _reveal(
                3,
                Text(
                  _t(
                    'Vui lòng kiểm tra kỹ thông tin khách hàng và số tiền trước khi thanh toán.',
                    'Please review customer details and amount before paying.',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.45,
                    color: const Color(0xFF7B819A),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _reveal(4, _buildReviewCard()),
              const SizedBox(height: 18),
              _reveal(
                5,
                Text(
                  _t('Phương thức thanh toán', 'Payment method'),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B1E30),
                  ),
                ),
              ),
              const SizedBox(height: 11),
              _reveal(6, _buildCcpBankPaymentTile()),
              const SizedBox(height: 20),
              _reveal(
                7,
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) =>
                                  PinPopupWidget(onSuccess: _processPayment),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _t('THANH TOÁN NGAY', 'PAY NOW'),
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
              color: _primaryBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEBFF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: <Widget>[
          _buildInfoPanel(
            icon: Icons.person_rounded,
            title: _t('Thông tin khách hàng', 'Customer information'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _t('ĐỊA CHỈ DỊCH VỤ', 'SERVICE ADDRESS'),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9EA3B9),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.customerName,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF242742),
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.serviceAddress,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF5D637F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoPanel(
            icon: Icons.bolt_rounded,
            title: _t('Chi tiết tiêu thụ', 'Consumption details'),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _metricBlock(
                        label: _t('LƯỢNG ĐIỆN TIÊU THỤ', 'ENERGY USAGE'),
                        value:
                            '${widget.usageKwh.toStringAsFixed(0)} ${_t('kWh', 'kWh')}',
                      ),
                    ),
                    Expanded(
                      child: _metricBlock(
                        label: _t('KỲ THANH TOÁN', 'BILLING PERIOD'),
                        value: widget.billingPeriod,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        _t('Tổng tiền', 'Total'),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF535B78),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatVnd(widget.totalAmount),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _primaryBlue,
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
    );
  }

  Widget _buildInfoPanel({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: _primaryBlue),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2A2E47),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _metricBlock({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: const Color(0xFF9AA0B7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF272C46),
          ),
        ),
      ],
    );
  }

  Widget _buildCcpBankPaymentTile() {
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
}
