import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'QR.dart' as qr_scan;

class QRCodeScreen extends StatelessWidget {
  const QRCodeScreen({super.key});

  static const Color primaryBlue = Color(0xFF000DC0);

  String _t(BuildContext context, String vi, String en) {
    return AppText.tr(context, vi, en);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: CCPAppBar(
        title: _t(context, 'Mã QR nhận tiền', 'Receive QR code'),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -110,
            left: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withOpacity(0.08),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFDCE4FF)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _t(
                              context,
                              'Khách hàng chuyển khoản quét mã bên dưới',
                              'Payer can scan this code to transfer',
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: const Color(0xFF27346F),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        StreamBuilder<UserProfileData?>(
                          stream: UserFirestoreService.instance
                              .currentUserProfileStream(),
                          initialData:
                              UserFirestoreService.instance.latestProfile,
                          builder: (context, snapshot) {
                            final UserProfileData? profile =
                                snapshot.data ??
                                UserFirestoreService.instance.latestProfile;
                            final String fullname = snapshot.hasError
                                ? _t(
                                    context,
                                    'Không tìm thấy user',
                                    'User not found',
                                  )
                                : ((profile?.fullname.isNotEmpty == true)
                                      ? profile!.fullname
                                      : _t(context, 'Khách hàng', 'Customer'));

                            return Text(
                              fullname.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.2,
                                color: const Color(0xFF15204A),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '123 568 567 456',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF526091),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFDCE3FF)),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              QrImageView(
                                data: 'https://example.com/pay/nguyenvana',
                                version: QrVersions.auto,
                                size: 210,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF0F1D5C),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF0F1D5C),
                                ),
                              ),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: primaryBlue,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: Text(
                            _t(context, 'Thêm số tiền', 'Add amount'),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryBlue,
                            textStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.download_rounded),
                          label: Text(_t(context, 'Lưu ảnh', 'Save image')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1A2A75),
                            side: const BorderSide(color: Color(0xFFC8D4FF)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.send_rounded),
                          label: Text(_t(context, 'Gửi', 'Send')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 86,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8ECFB))),
        ),
        child: Row(
          children: [
            Expanded(
              child: _qrTab(
                context,
                icon: Icons.qr_code_scanner_rounded,
                label: _t(context, 'Quét mã', 'Scan code'),
                isActive: false,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const qr_scan.QRScannerScreen(),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: _qrTab(
                context,
                icon: Icons.qr_code_2_rounded,
                label: _t(context, 'Mã QR nhận tiền', 'Receive QR code'),
                isActive: true,
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qrTab(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? primaryBlue : Colors.black45,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: isActive ? primaryBlue : Colors.black45,
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
