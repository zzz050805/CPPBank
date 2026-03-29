import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_text.dart';
import 'success_screen.dart';

class NfcScreen extends StatefulWidget {
  const NfcScreen({super.key});

  @override
  State<NfcScreen> createState() => _NfcScreenState();
}

class _NfcScreenState extends State<NfcScreen> {
  int _scanStep = 0; // 0: Chuẩn bị, 1: Đang quét, 2: Đã xong
  int _activeDots = 0; // Số lượng chấm xanh hiển thị lúc đang quét

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _startAutoNfcScan();
  }

  void _startAutoNfcScan() async {
    // 1. Trạng thái "Chuẩn bị" (1.5s)
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // 2. Chuyển sang "Đang quét" (Chạy 10 chấm xanh)
    setState(() {
      _scanStep = 1;
    });
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _activeDots = i;
      });
    }

    // 3. Quét xong -> Hiện dấu tích xanh (Bước "Đã xong")
    setState(() {
      _scanStep = 2;
    });

    // --- THÊM ĐOẠN NÀY: Đợi 3 giây rồi tự nhảy qua trang Success ---
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.pushReplacement(
        // Dùng pushReplacement để người dùng không back lại trang quét nữa
        context,
        MaterialPageRoute(builder: (context) => const SuccessScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF343434),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _t('Quét NFC', 'NFC Scan'),
          style: GoogleFonts.poppins(
            color: const Color(0xFF343434),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/NFC.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.credit_card,
                              size: 80,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildBulletPoint(
                      _t(
                        'Đặt điện thoại lên thẻ CCCD',
                        'Place your phone on your ID card',
                      ),
                    ),
                    _buildBulletPoint(
                      _t(
                        'Giữ mặt lưng điện thoại sát vào chip ở chính giữa thẻ CCCD',
                        'Keep the back of your phone close to the chip in the center of the ID card',
                      ),
                    ),
                    _buildBulletPoint(_t('Lưu ý:', 'Notes:')),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubBulletPoint(
                            _t(
                              '* Giữ yên thiết bị trong vài giây.',
                              '* Keep the device still for a few seconds.',
                            ),
                          ),
                          _buildSubBulletPoint(
                            _t(
                              '* Đảm bảo đã bật NFC trên điện thoại.',
                              '* Make sure NFC is enabled on your phone.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- KHUNG HƯỚNG DẪN QUÉT BÊN DƯỚI ---
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.blue[200]!, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // SỬA CHỖ NÀY: Chữ tự động nhảy theo trạng thái quét
                  Text(
                    _scanStep == 0
                        ? _t(
                            'Chuẩn bị CCCD để quét',
                            'Prepare ID card for scanning',
                          )
                        : (_scanStep == 1
                              ? _t('Đang quét CCCD', 'Scanning ID card')
                              : _t('Đã xong', 'Done')),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF0084FF),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0084FF),
                        width: 3,
                      ),
                      color: Colors.blue[50],
                    ),
                    child: Icon(
                      _scanStep == 2 ? Icons.check : Icons.phone_android,
                      size: 40,
                      color: const Color(0xFF0084FF),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_scanStep == 0)
                    Text(
                      _t(
                        'Giữ phần trên của thiết bị tiếp xúc trực\ntiếp với tâm của thẻ CCCD.',
                        'Keep the top of your device in direct\ncontact with the center of the ID card.',
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF0084FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(10, (index) {
                        bool isBlue =
                            _scanStep == 2 ||
                            (_scanStep == 1 && index < _activeDots);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isBlue
                                ? const Color(0xFF0084FF)
                                : Colors.grey[300],
                          ),
                        );
                      }),
                    ),

                  if (_scanStep == 0) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEBEBEB),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          debugPrint('Scan skipped for now');
                        },
                        child: Text(
                          _t('Để sau', 'Later'),
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 10),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: Colors.grey[700],
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.grey[700],
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}
