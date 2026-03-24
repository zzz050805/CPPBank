import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'nfc_screen.dart'; // Đảm bảo đã có file này

class OtpScreen extends StatefulWidget {
  final String phoneNumber; 

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpValid = false;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_checkOtp);
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _checkOtp() {
    setState(() {
      _isOtpValid = _otpController.text.length == 6;
    });
  }

  // --- SỬA LẠI HÀM NÀY ĐỂ NHẢY QUA NFC ---
  void _handleNext() {
    if (_isOtpValid) {
      _showSuccessPopupAndNavigate();
    }
  }

  // --- HÀM POPUP THÀNH CÔNG VÀ CHUYỂN TRANG ---
  void _showSuccessPopupAndNavigate() {
    showDialog(
      context: context,
      barrierColor: Colors.black26, 
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) { 
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (Navigator.canPop(dialogContext)) {
            Navigator.pop(dialogContext); // Đóng popup
            // CHUYỂN QUA TRANG NFC
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NfcScreen()),
            );
          }
        });

        return Center(
          child: Container(
            width: 220,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Color(0xFF52D5BA), shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  "Xác nhận thành công!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14, 
                    fontWeight: FontWeight.w600, 
                    color: const Color(0xFF343434), 
                    decoration: TextDecoration.none
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showResendPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black26, 
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) { 
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.canPop(dialogContext)) {
            Navigator.pop(dialogContext); 
          }
        });

        return Center(
          child: Container(
            width: 220,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Color(0xFF52D5BA), shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  "Đã gửi lại mã mới!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF343434), decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF343434), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Nhập OTP",
          style: GoogleFonts.poppins(color: const Color(0xFF343434), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Nhập mã", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Mã",
                          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                          counterText: "",
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF000DC0), width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF281C9D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        onPressed: () => _showResendPopup(context),
                        child: Text("Gửi lại mã", style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12, height: 1.6),
                    children: [
                      const TextSpan(text: "Chúng tôi đã gửi mã xác thực đến số điện thoại "),
                      TextSpan(text: widget.phoneNumber, style: GoogleFonts.poppins(color: const Color(0xFF281C9D), fontWeight: FontWeight.bold)),
                      const TextSpan(text: " của bạn\n\n"),
                      const TextSpan(text: "Mã này sẽ hết hiệu lực sau 10 phút kể từ thời điểm gửi.\n\n"),
                      const TextSpan(text: "Số điện thoại này gắn liền với tài khoản bạn sử dụng về sau."),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isOtpValid ? const Color(0xFF000DC0) : const Color(0xFFF2F4FB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isOtpValid ? _handleNext : null,
                    child: Text(
                      "Xác Nhận",
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}