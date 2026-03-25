import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'QR_user.dart' as qr_user;

class QrScreen extends StatelessWidget {
  const QrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const QRScannerScreen();
  }
}

class QRScannerScreen extends StatelessWidget {
  const QRScannerScreen({super.key});

  static const Color primaryBlue = Color(0xFF000DC0);

  String _t(BuildContext context, String vi, String en) {
    return AppText.tr(context, vi, en);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: CCPAppBar(title: _t(context, 'Quét mã', 'Scan code')),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withOpacity(0.08),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryBlue.withOpacity(0.95),
                          const Color(0xFF275BFF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _t(
                              context,
                              'Đưa mã QR vào khung để quét nhanh',
                              'Place the QR code inside frame to scan',
                            ),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 290,
                        height: 290,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F5FF),
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            _buildCorner(top: 12, left: 12),
                            _buildCorner(top: 12, right: 12, rotateQuarter: 1),
                            _buildCorner(
                              bottom: 12,
                              left: 12,
                              rotateQuarter: 3,
                            ),
                            _buildCorner(
                              bottom: 12,
                              right: 12,
                              rotateQuarter: 2,
                            ),
                            Align(
                              child: Container(
                                width: 172,
                                height: 172,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFD8E1FF),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 104,
                                  color: Color(0xFFCAD5FF),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 18,
                              right: 18,
                              top: 138,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      primaryBlue.withOpacity(0.72),
                                      Colors.transparent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _t(context, 'Chọn ảnh QR', 'Choose QR image'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1D2E7A),
                        side: const BorderSide(color: Color(0xFFC8D4FF)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _qrTab(
              context,
              icon: Icons.qr_code_scanner_rounded,
              label: _t(context, 'Quét mã', 'Scan code'),
              isActive: true,
              onTap: () {},
            ),
            _qrTab(
              context,
              icon: Icons.qr_code_2_rounded,
              label: _t(context, 'Mã QR nhận tiền', 'Receive QR code'),
              isActive: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const qr_user.QRCodeScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner({
    double? top,
    double? left,
    double? right,
    double? bottom,
    int rotateQuarter = 0,
  }) {
    Widget corner = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: primaryBlue, width: 4),
          left: const BorderSide(color: primaryBlue, width: 4),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    if (rotateQuarter != 0) {
      corner = RotatedBox(quarterTurns: rotateQuarter, child: corner);
    }

    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: corner,
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
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? primaryBlue : Colors.black45,
              size: 27,
            ),
            const SizedBox(height: 4),
            Text(
              label,
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
