import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'data_bill.dart';
import 'electric_bill.dart';
import 'internet_bill.dart';
import 'water_bill.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  String _t(BuildContext context, String vi, String en) =>
      AppText.tr(context, vi, en);

  @override
  Widget build(BuildContext context) {
    final Color surface = const Color(0xFFF6F7FF);
    final Color link = const Color(0xFF000DC0);

    return Scaffold(
      backgroundColor: surface,
      appBar: CCPAppBar(
        title: _t(context, 'Hóa đơn', 'Bills'),
        backgroundColor: surface,
        onBackPressed: () => Navigator.pop(context),
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ElectricBillScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (BuildContext context) =>
                          const WaterBillScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (BuildContext context) =>
                          const InternetBillScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
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
                      builder: (context) => const DataBillScreen(),
                    ),
                  );
                },
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
          constraints: const BoxConstraints(minHeight: 116),
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B1B1F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF7C8196),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      actionText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: actionColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: iconForeground, size: 34),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
