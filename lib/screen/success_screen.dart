import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../l10n/app_text.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  late ConfettiController _confettiController;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    // Bắn pháo hoa giấy trong 3 giây
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hình heo đất & người
                Container(
                  width: double.infinity,
                  height: 280,
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Image.asset(
                    'assets/images/SCF.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 100,
                      color: Color(0xFF281C9D),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  _t(
                    'Tạo tài khoản thành công',
                    'Account created successfully',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF281C9D),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _t(
                    'Bạn đã tạo tài khoản thành công!\nVui lòng đăng nhập tiếp để sử dụng',
                    'Your account has been created successfully!\nPlease log in to continue.',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF281C9D),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      // Quay về trang đầu tiên (Login)
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: Text(
                      _t('ĐĂNG NHẬP', 'LOG IN'),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Hiệu ứng pháo hoa giấy
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2, // Rơi xuống
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 25,
            gravity: 0.15,
            colors: const [
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.green,
              Color(0xFF281C9D),
            ],
          ),
        ],
      ),
    );
  }
}
