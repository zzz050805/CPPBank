import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/user_firestore_service.dart';
import 'otp_screen.dart';

class RegisterPasswordScreen extends StatefulWidget {
  // --- THÊM: KHAI BÁO CÁC BIẾN ĐỂ NHẬN DỮ LIỆU TỪ TRANG TRƯỚC ---
  final String fullName;
  final String phoneNumber;
  final String cccd;
  final String issueDate;
  final String address;

  const RegisterPasswordScreen({
    super.key,
    required this.fullName,
    required this.phoneNumber,
    required this.cccd,
    required this.issueDate,
    required this.address,
  });

  @override
  State<RegisterPasswordScreen> createState() => _RegisterPasswordScreenState();
}

class _RegisterPasswordScreenState extends State<RegisterPasswordScreen> {
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _rePassController = TextEditingController();

  bool _isObscure = true;
  bool _isReObscure = true;
  bool _isAgreed = false;

  String _strengthText = "";
  Color _strengthColor = Colors.red;
  bool _isValid = false;

  bool _isConfigurationNotFound(FirebaseAuthException e) {
    final String message = (e.message ?? '').toLowerCase();
    return e.code == 'configuration-not-found' ||
        e.code == 'internal-error' ||
        message.contains('configuration_not_found');
  }

  @override
  void initState() {
    super.initState();
    _passController.addListener(_checkPasswordStrength);
    _rePassController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _passController.dispose();
    _rePassController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    String pass = _passController.text;

    bool hasUppercase = pass.contains(RegExp(r'[A-Z]'));
    bool hasSpecial = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    int specialCount = RegExp(
      r'[!@#$%^&*(),.?":{}|<>]',
    ).allMatches(pass).length;

    setState(() {
      if (pass.isEmpty) {
        _strengthText = "";
        _isValid = false;
      } else if (pass.length > 8 && hasUppercase && hasSpecial) {
        _isValid = true;

        if (pass.length > 15 && specialCount >= 2) {
          _strengthText = "Mạnh";
          _strengthColor = Colors.green;
        } else if (pass.length > 15) {
          _strengthText = "Trung bình";
          _strengthColor = Colors.orange;
        } else {
          _strengthText = "Yếu";
          _strengthColor = Colors.red;
        }
      } else {
        _strengthText = "Mật khẩu chưa hợp lệ";
        _strengthColor = Colors.red;
        _isValid = false;
      }
    });
  }

  // --- SỬA HÀM LƯU DỮ LIỆU: GỘP TẤT CẢ THÔNG TIN ---
  void _handleFinalRegister() async {
    if (_passController.text != _rePassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mật khẩu nhập lại không khớp!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF000DC0)),
        ),
      );

      final String normalizedPhone = widget.phoneNumber.replaceAll(
        RegExp(r'\D'),
        '',
      );
      final String authEmail = 'cppbank_$normalizedPhone@cppbank.local';
      String? uid;
      bool usedAuthFallback = false;

      try {
        final UserCredential credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: authEmail,
              password: _passController.text,
            );
        uid = credential.user?.uid;
      } on FirebaseAuthException catch (e) {
        if (_isConfigurationNotFound(e)) {
          usedAuthFallback = true;

          final QuerySnapshot<Map<String, dynamic>> existingDocQuery =
              await FirebaseFirestore.instance
                  .collection('users')
                  .where('phoneNumber', isEqualTo: widget.phoneNumber)
                  .limit(1)
                  .get();

          if (existingDocQuery.docs.isNotEmpty) {
            uid = existingDocQuery.docs.first.id;
          } else {
            uid = FirebaseFirestore.instance.collection('users').doc().id;
          }
        } else {
          rethrow;
        }
      }

      if (uid == null || uid.isEmpty) {
        throw Exception('Không tạo được định danh tài khoản.');
      }

      // Lưu dữ liệu user và khởi tạo cấu trúc Firestore chuẩn cho tài khoản mới.
      await UserFirestoreService.instance.initUserData(
        userId: uid,
        userData: {
          'fullname': widget.fullName,
          'fullName': widget.fullName,
          'authEmail': authEmail,
          'email': authEmail,
          'phoneNumber': widget.phoneNumber,
          'cccd': widget.cccd,
          'issueDate': widget.issueDate,
          'address': widget.address,
          // Giữ tương thích luồng đăng nhập legacy đang kiểm tra password từ Firestore.
          'password': _passController.text,
          'authUid': usedAuthFallback ? null : uid,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      if (usedAuthFallback) {
        UserFirestoreService.instance.setFallbackDocId(uid);
      }

      if (!mounted) return;
      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPScreen(phoneNumber: widget.phoneNumber),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Lỗi lưu dữ liệu: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canRegister =
        _isValid &&
        _isAgreed &&
        _passController.text == _rePassController.text &&
        _passController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF000DC0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Đăng ký",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Đăng ký ngay!",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF000DC0),
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "Để trở thành thành viên của CCPBank",
                      style: GoogleFonts.poppins(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Image.asset(
                        'assets/images/Logo2.png',
                        height: 180,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.shield_moon_outlined,
                          size: 100,
                          color: Color(0xFFF2F4FB),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildPassField(
                      controller: _passController,
                      hint: "Tạo mật khẩu",
                      isObscure: _isObscure,
                      onToggle: () => setState(() => _isObscure = !_isObscure),
                    ),

                    if (_passController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 6,
                          left: 4,
                          right: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isValid
                                  ? "Mật khẩu hợp lệ"
                                  : "Mật khẩu chưa hợp lệ",
                              style: GoogleFonts.poppins(
                                color: _isValid ? Colors.green : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _strengthText,
                              style: GoogleFonts.poppins(
                                color: _strengthColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    _buildPassField(
                      controller: _rePassController,
                      hint: "Nhập lại mật khẩu",
                      isObscure: _isReObscure,
                      onToggle: () =>
                          setState(() => _isReObscure = !_isReObscure),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      "Lưu ý:\n• Ít nhất 8 ký tự\n• Có chữ hoa, số, ký tự đặc biệt (@,!,#,...)\n• Không trùng thông tin cá nhân",
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _isAgreed,
                            activeColor: const Color(0xFF000DC0),
                            onChanged: (v) => setState(() => _isAgreed = v!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      "Bằng việc tạo tài khoản, bạn đồng ý với các ",
                                ),
                                TextSpan(
                                  text: "Điều khoản và Điều kiện",
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF000DC0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(text: " của chúng tôi."),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canRegister
                              ? const Color(0xFF000DC0)
                              : const Color(0xFFF2F4FB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: canRegister ? _handleFinalRegister : null,
                        child: Text(
                          "ĐĂNG KÝ",
                          style: GoogleFonts.poppins(
                            color: canRegister
                                ? Colors.white
                                : const Color(0xFF000DC0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassField({
    required TextEditingController controller,
    required String hint,
    required bool isObscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2F4FB), width: 1.5),
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: Icon(
              isObscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}
