import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/payment_service.dart';
import '../widget/pin_popup.dart';
import '../widget/ccp_app_bar.dart';
import 'data_bill_success.dart';

class DataBillConfirmScreen extends StatefulWidget {
  const DataBillConfirmScreen({
    super.key,
    required this.phoneNumber,
    required this.planName,
    required this.planData,
    required this.planPriceText,
  });

  final String phoneNumber;
  final String planName;
  final String planData;
  final String planPriceText;

  @override
  State<DataBillConfirmScreen> createState() => _DataBillConfirmScreenState();
}

class _DataBillConfirmScreenState extends State<DataBillConfirmScreen> {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _surface = Color(0xFFF6F7FF);

  final NumberFormat _moneyFormat = NumberFormat.decimalPattern('vi_VN');
  late final Stream<UserProfileData?> _profileStream;
  bool _isSubmitting = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _profileStream = UserFirestoreService.instance.currentUserProfileStream();
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
        amount: _parseAmount(_totalText(widget.planPriceText)),
        billType: 'mobile',
        billId: widget.phoneNumber,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DataBillSuccessScreen(
            phoneNumber: widget.phoneNumber,
            planName: widget.planName,
            totalText: _totalText(widget.planPriceText),
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

  String _formatBalanceLine(double amount) {
    return '${_t('Số dư', 'Balance')}: ${_moneyFormat.format(amount)} đ';
  }

  bool _parseHasVipCard(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  double _parseBalance(dynamic rawBalance) {
    if (rawBalance is num) return rawBalance.toDouble();
    if (rawBalance is String) return double.tryParse(rawBalance) ?? 0;
    return 0;
  }

  Widget _buildLiveBalanceSubtitle() {
    return StreamBuilder<UserProfileData?>(
      stream: _profileStream,
      initialData: UserFirestoreService.instance.latestProfile,
      builder: (context, profileSnapshot) {
        final UserProfileData? profile =
            profileSnapshot.data ?? UserFirestoreService.instance.latestProfile;
        final String? uid = profile?.uid;

        if (uid == null || uid.isEmpty) {
          return Text(
            '${_t('Số dư', 'Balance')}: --',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF7E85A1),
              fontWeight: FontWeight.w500,
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            final bool hasVipCard = _parseHasVipCard(
              userSnapshot.data?.data()?['hasVipCard'],
            );

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('cards')
                  .snapshots(),
              builder: (context, cardsSnapshot) {
                if (cardsSnapshot.connectionState == ConnectionState.waiting &&
                    !cardsSnapshot.hasData) {
                  return Text(
                    '${_t('Số dư', 'Balance')}: ...',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF7E85A1),
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }

                if (cardsSnapshot.hasError || userSnapshot.hasError) {
                  return Text(
                    _t('Không tải được số dư', 'Unable to load balance'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF7E85A1),
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }

                double standardBalance = 0;
                double vipBalance = 0;

                for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                    in (cardsSnapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[])) {
                  final Map<String, dynamic> data = doc.data();
                  final double balance = _parseBalance(data['balance']);
                  final String docId = doc.id.toLowerCase();

                  if (docId == 'standard') {
                    standardBalance = balance;
                  } else if (docId == 'vip') {
                    vipBalance = balance;
                  }
                }

                final double totalBalance = hasVipCard
                    ? standardBalance + vipBalance
                    : standardBalance;

                return Text(
                  _formatBalanceLine(totalBalance),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF7E85A1),
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCcpBankPaymentTile() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0FF),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _primaryBlue.withValues(alpha: 0.9),
            width: 1.6,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_balance_rounded,
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
                    'CCP BANK',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF242842),
                    ),
                  ),
                  const SizedBox(height: 1),
                  _buildLiveBalanceSubtitle(),
                ],
              ),
            ),
            const Icon(
              Icons.check_circle_rounded,
              color: _primaryBlue,
              size: 20,
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
        onBackPressed: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    _t('BƯỚC 2/3', 'STEP 2/3'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _primaryBlue,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _t('Xác nhận thông tin', 'Confirm details'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF8E94AE),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _StepLine(activeCount: 2),
              const SizedBox(height: 18),
              Text(
                _t('Chi tiết đơn hàng', 'Order details'),
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF262B49),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEBFF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: <Widget>[
                    _rowLabelValue(
                      _t('Số điện thoại', 'Phone number'),
                      widget.phoneNumber,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0DAF8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.wifi_tethering_rounded,
                              color: _primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  widget.planName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2E3353),
                                  ),
                                ),
                                Text(
                                  widget.planData,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF8A8FAA),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            widget.planPriceText,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _rowLabelValue(
                      _t('Phí dịch vụ', 'Service fee'),
                      _t('Miễn phí', 'Free'),
                    ),
                    const SizedBox(height: 6),
                    _rowLabelValue(
                      _t('Khuyến mãi', 'Discount'),
                      '-2.000đ',
                      valueColor: Colors.redAccent,
                    ),
                    const Divider(height: 18),
                    _rowLabelValue(
                      _t('Tổng thanh toán', 'Total payment'),
                      _totalText(widget.planPriceText),
                      valueColor: _primaryBlue,
                      bold: true,
                    ),
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
              _buildCcpBankPaymentTile(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
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
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _t('THANH TOÁN NGAY', 'PAY NOW'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _t(
                    'Giao dịch được bảo mật chuẩn quốc tế PCI DSS',
                    'Transaction secured by PCI DSS',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF9BA0B8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowLabelValue(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF7D839D),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: bold ? 24 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ?? const Color(0xFF303654),
          ),
        ),
      ],
    );
  }

  String _totalText(String priceText) {
    final String rawDigits = priceText.replaceAll(RegExp(r'[^0-9]'), '');
    final int amount = int.tryParse(rawDigits) ?? 0;
    final int total = (amount - 2000).clamp(0, 999999999);
    final String formatted = total.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$formattedđ';
  }

  double _parseAmount(String amountText) {
    final String rawDigits = amountText.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(rawDigits) ?? 0;
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
