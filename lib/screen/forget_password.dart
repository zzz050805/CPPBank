import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login.dart';

void main() {
  runApp(
    const MaterialApp(
      home: ForgotPasswordScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isPhoneValid = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validatePhone);
  }

  void _validatePhone() {
    final bool isValid = _phoneController.text.length == 10;
    if (isValid != _isPhoneValid) {
      setState(() {
        _isPhoneValid = isValid;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Định nghĩa màu sắc chủ đạo
    const Color primaryColor = Color(0xFF000DC0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Nền xám cực nhẹ
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 380),
                reverseTransitionDuration: const Duration(milliseconds: 320),
                pageBuilder: (_, animation, __) => const LoginScreen(),
                transitionsBuilder: (_, animation, __, child) {
                  final Animation<Offset> slide =
                      Tween<Offset>(
                        begin: const Offset(-0.08, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );
                  final Animation<double> fade = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  );
                  return FadeTransition(
                    opacity: fade,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
              ),
              (route) => false,
            );
          },
        ),
        title: Text(
          'Quên mật khẩu',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhập số điện thoại của bạn',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Nhập số điện thoại',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Chúng tôi đã gửi mã xác minh đến số điện thoại của bạn.',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isPhoneValid
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đã hủy liên kết với trang OTP.',
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPhoneValid
                            ? primaryColor
                            : const Color(0xFFBFC5F5),
                        disabledBackgroundColor: const Color(0xFFBFC5F5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Gửi',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
