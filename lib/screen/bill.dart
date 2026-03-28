import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'phone_recharge.dart';

class BillScreen extends StatelessWidget {
  const BillScreen({super.key});

  String _t(BuildContext context, String vi, String en) =>
      AppText.tr(context, vi, en);

  @override
  Widget build(BuildContext context) {
    final Color surface = const Color(0xFFF6F7FF);
    final Color primary = const Color(0xFF000DC0);
    final Color link = const Color(0xFF000DC0);

    return Scaffold(
      backgroundColor: surface,
      appBar: CCPAppBar(
        title: _t(context, 'Hóa đơn', 'Bills'),
        backgroundColor: surface,
        onBackPressed: () => Navigator.pop(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            color: const Color(0xFF000DC0),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(context, 'TẤT CẢ DỊCH VỤ', 'ALL SERVICES'),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: const Color(0xFF9AA0B2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  context,
                  'Quản lý hóa đơn\ncủa bạn dễ dàng.',
                  'Manage your bills\neasily.',
                ),
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: const Color(0xFF1B1B1F),
                ),
              ),
              const SizedBox(height: 16),
              _ServiceCard(
                title: _t(context, 'Tiền điện', 'Electricity'),
                subtitle: _t(
                  context,
                  'Thanh toán tiền điện tháng này',
                  "Pay this month's electricity",
                ),
                actionText: _t(context, 'THANH TOÁN NGAY  >', 'PAY NOW  >'),
                actionColor: link,
                icon: Icons.bolt,
                iconBackground: const Color(0xFF1D2A7A),
                iconForeground: const Color(0xFFFFD54F),
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _ServiceCard(
                title: _t(context, 'Tiền nước', 'Water'),
                subtitle: _t(
                  context,
                  'Thanh toán tiền nước tháng này',
                  "Pay this month's water",
                ),
                actionText: _t(context, 'KIỂM TRA DƯ NỢ  >', 'CHECK DUE  >'),
                actionColor: link,
                icon: Icons.water_drop_outlined,
                iconBackground: const Color(0xFF1D6FD1),
                iconForeground: Colors.white,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _ServiceCard(
                title: _t(context, 'Internet', 'Internet'),
                subtitle: _t(
                  context,
                  'Thanh toán tiền Internet',
                  'Pay internet fee',
                ),
                actionText: _t(context, 'GIA HẠN GÓI  >', 'RENEW  >'),
                actionColor: link,
                icon: Icons.wifi,
                iconBackground: const Color(0xFF0B5866),
                iconForeground: Colors.white,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _ServiceCard(
                title: _t(context, 'Data điện thoại', 'Mobile data'),
                subtitle: _t(context, 'Nạp Data', 'Top up data'),
                actionText: _t(context, 'NẠP NGAY', 'TOP UP NOW'),
                actionColor: link,
                icon: Icons.phone_android,
                iconBackground: const Color(0xFF111827),
                iconForeground: Colors.white,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PhoneRechargeScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary, primary.withOpacity(0.82)],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(context, 'ƯU ĐÃI ĐỘC QUYỀN', 'EXCLUSIVE OFFER'),
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _t(
                              context,
                              'Hoàn tiền 50%\ncho hóa đơn đầu\ntiên.',
                              'Get 50% cashback\non your first\nbill.',
                            ),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _t(context, 'NHẬN NGAY', 'GET NOW'),
                              style: GoogleFonts.poppins(
                                color: primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.local_offer_outlined,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.actionColor,
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String actionText;
  final Color actionColor;
  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B1B1F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF7C8196),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      actionText,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: actionColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconForeground, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
