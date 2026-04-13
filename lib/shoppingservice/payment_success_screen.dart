import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:doan_nganhang/screen/home_screen.dart';

import '../core/app_translations.dart';
import 'service_model.dart';

class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({
    super.key,
    required this.service,
    required this.amount,
    required this.targetAccount,
    this.transactionCode,
    this.paidAt,
    this.sourceAccount,
  });

  final ServiceModel service;
  final int amount;
  final String targetAccount;
  final String? transactionCode;
  final DateTime? paidAt;
  final String? sourceAccount;

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _silverBorder = Color(0xFFD9E2EC);
  static const Color _silverText = Color(0xFF6B7280);
  static const Color _successGreen = Color(0xFF16A34A);

  late final DateTime _paidAt;
  late final String _transactionCode;

  @override
  void initState() {
    super.initState();
    _paidAt = widget.paidAt ?? DateTime.now();

    final String code = (widget.transactionCode ?? '').trim();
    if (code.isNotEmpty) {
      _transactionCode = code;
      return;
    }

    final int suffix = 100000000 + Random().nextInt(900000000);
    _transactionCode = 'CPP$suffix';
  }

  String _tr(String key) => AppTranslations.getText(context, key);

  String _languageCode() => AppTranslations.currentLanguageCode(context);

  String _trWithParams(String key, Map<String, String> params) {
    return AppTranslations.getTextByCodeWithParams(
      _languageCode(),
      key,
      params,
    );
  }

  String _formatAmount(int value) {
    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value).replaceAll(',', '.');
  }

  Widget _receiptRow({
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _silverText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: emphasize ? 15 : 14,
                fontWeight: FontWeight.w700,
                color: _primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String serviceName = widget.service.localizedName(_languageCode());
    final String sourceAccount = (widget.sourceAccount ?? '').trim().isEmpty
        ? _tr('payment_source_account')
        : widget.sourceAccount!.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _successGreen.withValues(alpha: 0.10),
                          boxShadow: [
                            BoxShadow(
                              color: _successGreen.withValues(alpha: 0.18),
                              blurRadius: 26,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              size: 50,
                              color: _successGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _tr('payment_success_screen_title'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: _primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _trWithParams(
                          'payment_success_for_service',
                          <String, String>{'service': serviceName},
                        ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _silverText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '- ${_formatAmount(widget.amount)} VND',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: _primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _silverBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _silverBorder),
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      widget.service.logoPath,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) {
                                        return const Icon(
                                          Icons.storefront_rounded,
                                          size: 16,
                                          color: _primaryBlue,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    serviceName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const _ReceiptDashedDivider(),
                            const SizedBox(height: 14),
                            _receiptRow(
                              label: _tr('recipient_account'),
                              value: widget.targetAccount,
                            ),
                            _receiptRow(
                              label: _tr('transaction_id'),
                              value: _transactionCode,
                            ),
                            _receiptRow(
                              label: _tr('time'),
                              value: DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(_paidAt),
                            ),
                            _receiptRow(
                              label: _tr('source_account'),
                              value: sourceAccount,
                              emphasize: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (Route<dynamic> route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    _tr('back_to_home'),
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

class _ReceiptDashedDivider extends StatelessWidget {
  const _ReceiptDashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double segmentWidth = 7;
        const double gap = 5;
        final int count = (constraints.maxWidth / (segmentWidth + gap)).floor();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List<Widget>.generate(count, (_) {
            return Container(
              width: segmentWidth,
              height: 1.4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        );
      },
    );
  }
}
