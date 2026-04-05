import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../widget/pin_popup.dart';
import '../widget/ccp_app_bar.dart';
import 'main_tab_shell.dart';
import 'water_bill_otp.dart';

class WaterBillPayScreen extends StatefulWidget {
  const WaterBillPayScreen({
    super.key,
    this.customerCode = 'PE13000245678',
    this.customerName = 'NGUYEN THI MAI',
    this.serviceAddress = '288 Le Loi, Quan 1, TP.HCM',
    this.usageM3 = 36,
    this.billingPeriod = '03/2026',
    this.totalAmount = 426000,
  });

  final String customerCode;
  final String customerName;
  final String serviceAddress;
  final double usageM3;
  final String billingPeriod;
  final double totalAmount;

  @override
  State<WaterBillPayScreen> createState() => _WaterBillPayScreenState();
}

class _WaterBillPayScreenState extends State<WaterBillPayScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _surface = Color(0xFFF6F7FF);

  final NumberFormat _moneyFormat = NumberFormat.decimalPattern('vi_VN');
  late final AnimationController _introController;
  late final Stream<UserProfileData?> _profileStream;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _profileStream = UserFirestoreService.instance.currentUserProfileStream();
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

  String _formatBalanceLine(double amount) {
    return '${_t('Số dư', 'Balance')}: ${_moneyFormat.format(amount)} đ';
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainTabShell(initialIndex: 0)),
      (Route<dynamic> route) => false,
    );
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
      builder:
          (
            BuildContext context,
            AsyncSnapshot<UserProfileData?> profileSnapshot,
          ) {
            final UserProfileData? profile =
                profileSnapshot.data ??
                UserFirestoreService.instance.latestProfile;
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
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                    userSnapshot,
                  ) {
                    final bool hasVipCard = _parseHasVipCard(
                      userSnapshot.data?.data()?['hasVipCard'],
                    );

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('cards')
                          .snapshots(),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                            cardsSnapshot,
                          ) {
                            if (cardsSnapshot.connectionState ==
                                    ConnectionState.waiting &&
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

                            if (cardsSnapshot.hasError ||
                                userSnapshot.hasError) {
                              return Text(
                                _t(
                                  'Không tải được số dư',
                                  'Unable to load balance',
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF7E85A1),
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            }

                            double standardBalance = 0;
                            double vipBalance = 0;

                            for (final QueryDocumentSnapshot<
                                  Map<String, dynamic>
                                >
                                doc
                                in (cardsSnapshot.data?.docs ??
                                    <
                                      QueryDocumentSnapshot<
                                        Map<String, dynamic>
                                      >
                                    >[])) {
                              final Map<String, dynamic> data = doc.data();
                              final double balance = _parseBalance(
                                data['balance'],
                              );
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
            icon: Icons.water_drop_rounded,
            title: _t('Chi tiết tiêu thụ', 'Consumption details'),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _metricBlock(
                        label: _t('LƯỢNG NƯỚC SỬ DỤNG', 'WATER USAGE'),
                        value: '${widget.usageM3.toStringAsFixed(0)} m3',
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
                      _t('BƯỚC 2/4', 'STEP 2/4'),
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
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => PinPopupWidget(
                          onSuccess: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WaterBillOtpScreen(
                                  totalAmount: widget.totalAmount,
                                  customerName: widget.customerName,
                                  customerCode: widget.customerCode,
                                ),
                              ),
                            );
                          },
                        ),
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
                    child: Text(
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
}
