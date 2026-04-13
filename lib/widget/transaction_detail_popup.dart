import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/app_translations.dart';
import '../services/card_number_service.dart';

class TransactionDetailPopup {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _accentBlue = Color(0xFFEAF2FF);
  static const Color _silverBorder = Color(0xFFE2E8F0);
  static const Color _statusGreen = Color(0xFF15803D);
  static const Color _statusGreenBg = Color(0xFFE9F9EE);
  static const Color _expenseRed = Color(0xFFDC2626);

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> transactionData,
  ) {
    String tr(String key) => AppTranslations.getText(context, key);
    final TextTheme textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    final DateTime timestamp = _readTimestamp(
      transactionData['timestamp'] ??
          transactionData['createdAt'] ??
          transactionData['updatedAt'],
    );
    final double amount = _readAmount(transactionData);
    final String title = _firstNonEmpty(<dynamic>[
      transactionData['title'],
      transactionData['serviceName'],
      transactionData['transactionName'],
      transactionData['provider'],
      tr('transaction_details'),
    ]);
    final String targetInfo = _firstNonEmpty(<dynamic>[
      transactionData['target_account'],
      transactionData['targetAccount'],
      transactionData['toCardNumber'],
      transactionData['card_number'],
      transactionData['cardNumber'],
      transactionData['toAccountNumber'],
      transactionData['accountNumber'],
      transactionData['receiver'],
      transactionData['recipientName'],
      transactionData['phoneNumber'],
      transactionData['phone'],
      tr('unknown'),
    ]);
    final String displayTargetInfo =
        CardNumberService.formatCardNumber(targetInfo).isEmpty
        ? targetInfo
        : CardNumberService.formatCardNumber(targetInfo);
    final String transactionCode = _buildTransactionCode(
      transactionData,
      timestamp,
    );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (BuildContext modalContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Align(
                        child: Container(
                          width: 46,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: _accentBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: _silverBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            _iconForType(
                              (transactionData['type'] ?? '').toString(),
                            ),
                            color: _primaryBlue,
                            size: 42,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          textStyle: textTheme.titleLarge,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusGreenBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _statusGreen.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: _statusGreen,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tr('success'),
                                style: GoogleFonts.poppins(
                                  textStyle: textTheme.labelMedium,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _statusGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '- ${_formatCurrency(amount)} VND',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          textStyle: textTheme.headlineSmall,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: _expenseRed,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _DottedDivider(),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _silverBorder),
                        ),
                        child: Column(
                          children: [
                            _detailRow(
                              context: modalContext,
                              icon: Icons.schedule_rounded,
                              label: tr('time'),
                              value: DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(timestamp),
                            ),
                            const SizedBox(height: 10),
                            const _DottedDivider(),
                            const SizedBox(height: 10),
                            _detailRow(
                              context: modalContext,
                              icon: Icons.tag_rounded,
                              label: tr('transaction_id'),
                              value: transactionCode,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _silverBorder),
                        ),
                        child: Column(
                          children: [
                            _detailRow(
                              context: modalContext,
                              icon: Icons.account_balance_wallet_rounded,
                              label: tr('source_account'),
                              value: tr('main_account'),
                            ),
                            const SizedBox(height: 10),
                            const _DottedDivider(),
                            const SizedBox(height: 10),
                            _detailRow(
                              context: modalContext,
                              icon: Icons.credit_card_rounded,
                              label: tr('destination_account_or_phone'),
                              value: displayTargetInfo,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(modalContext).pop(),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: _primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            tr('close'),
                            style: GoogleFonts.poppins(
                              textStyle: textTheme.titleMedium,
                              fontSize: 18,
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
            ),
          ),
        );
      },
    );
  }

  static Widget _detailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    final TextTheme textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF7F8FA8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    textStyle: textTheme.bodyMedium,
                    fontSize: 13.5,
                    color: const Color(0xFF4B5563),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              textStyle: textTheme.bodyMedium,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'withdraw':
        return Icons.atm_rounded;
      case 'transfer':
        return Icons.swap_horiz_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'phone_topup':
      case 'phone_recharge':
      default:
        return Icons.phone_android_rounded;
    }
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = (value ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  static DateTime _readTimestamp(dynamic rawTimestamp) {
    if (rawTimestamp is DateTime) {
      return rawTimestamp;
    }

    if (rawTimestamp != null) {
      try {
        final dynamic converted = rawTimestamp.toDate();
        if (converted is DateTime) {
          return converted;
        }
      } catch (_) {}
    }

    if (rawTimestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    }

    if (rawTimestamp is String) {
      final DateTime? parsed = DateTime.tryParse(rawTimestamp);
      if (parsed != null) {
        return parsed;
      }
    }

    return DateTime.now();
  }

  static double _readAmount(Map<String, dynamic> data) {
    final dynamic raw =
        data['amount'] ??
        data['amountVnd'] ??
        data['totalAmount'] ??
        data['amountText'];

    if (raw is num) {
      return raw.toDouble().abs();
    }

    final String text = (raw ?? '').toString();
    if (text.trim().isEmpty) {
      return 0;
    }

    final String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(digits)?.abs() ?? 0;
  }

  static String _formatCurrency(double amount) {
    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(amount).replaceAll(',', '.');
  }

  static String _buildTransactionCode(
    Map<String, dynamic> data,
    DateTime timestamp,
  ) {
    final String fromData = _firstNonEmpty(<dynamic>[
      data['transactionCode'],
      data['withdrawCode'],
      data['code'],
      data['id'],
      data['docId'],
    ]);
    if (fromData.isNotEmpty) {
      return fromData;
    }

    final String datePart = DateFormat('ddMM').format(timestamp);
    final int randomPart = Random().nextInt(9000) + 1000;
    return 'FT$datePart$randomPart';
  }
}

class _DottedDivider extends StatelessWidget {
  const _DottedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double dotSize = 3;
        const double dotGap = 6;
        final int dotCount = (constraints.maxWidth / (dotSize + dotGap))
            .floor();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List<Widget>.generate(dotCount, (int index) {
            return Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
