import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'home_screen.dart';
import 'register.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _cccdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoginEnabled = false;
  String? _cccdError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _cccdController.addListener(_checkInput);
    _passwordController.addListener(_checkInput);
  }

  void _checkInput() {
    setState(() {
      _isLoginEnabled = _cccdController.text.isNotEmpty && _passwordController.text.isNotEmpty;
      
      if (_cccdController.text.isNotEmpty) {
        _cccdError = null;
      }
      if (_passwordController.text.isNotEmpty) {
        _passwordError = null;
      }
    });
  }

  // --- HÀM XỬ LÝ ĐĂNG NHẬP: ĐÃ SỬA ĐỂ NHẬN CẢ SĐT VÀ CCCD ---
  void _handleLogin() async {
    setState(() {
      if (_cccdController.text.isEmpty) {
        _cccdError = "Bạn cần nhập số điện thoại/CCCD";
      }
      if (_passwordController.text.isEmpty) {
        _passwordError = "Bạn cần nhập mật khẩu";
      }
    });

    if (_isLoginEnabled) {
      try {
        // Hiện loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
        );

        String inputAccount = _cccdController.text.trim();
        String inputPass = _passwordController.text.trim();

        // TRUY VẤN: Tìm user có pass đúng VÀ (SĐT khớp HOẶC CCCD khớp)
        var userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('password', isEqualTo: inputPass)
            .where(Filter.or(
              Filter('phoneNumber', isEqualTo: inputAccount),
              Filter('cccd', isEqualTo: inputAccount),
            ))
            .get();

        if (!mounted) return;
        Navigator.pop(context); // Tắt loading

        if (userQuery.docs.isNotEmpty) {
          // Lấy tên thật từ bản ghi đầu tiên tìm thấy
          String realName = userQuery.docs.first.get('fullName');

          // Vào trang Home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(fullName: realName),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Tài khoản hoặc mật khẩu không chính xác!"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        print("Lỗi: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi hệ thống: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black26, 
      builder: (BuildContext context) {
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF52D5BA), 
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Xác thực xong",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF343434),
                        decoration: TextDecoration.none, 
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _cccdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000DC0),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  const Text(
                    "9:09",
                    style: TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.w600, 
                        fontSize: 14),
                  ),
                  const Spacer(),
                  const Icon(Icons.signal_cellular_4_bar, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  const Icon(Icons.wifi, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  const Icon(Icons.battery_full, color: Colors.white, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 80), 
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 48, 
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Chào bạn!",
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF000DC0),
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Thuận tiện hơn khi vay qua App",
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF343434),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 15),
                              
                              Center(
                                child: Transform.scale(
                                  scale: 1.1, 
                                  child: _buildLockIllustration(),
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              _buildTextField(
                                "Số điện thoại/CCCD",
                                controller: _cccdController,
                                errorText: _cccdError,
                                keyboardType: TextInputType.text, 
                                textInputAction: TextInputAction.next, 
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(20),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              _buildTextField(
                                "Mật khẩu",
                                controller: _passwordController,
                                errorText: _passwordError,
                                isObscured: true,
                                keyboardType: TextInputType.visiblePassword, 
                                textInputAction: TextInputAction.done, 
                              ),
                              
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "Quên mật khẩu ?",
                                  style: GoogleFonts.poppins(
                                    color: const Color.fromARGB(255, 68, 67, 67),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              Center(
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isLoginEnabled ? const Color(0xFF000DC0) : const Color(0xFFF2F4FB),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: _handleLogin, 
                                    child: Text(
                                      "ĐĂNG NHẬP",
                                      style: GoogleFonts.poppins(
                                        color: _isLoginEnabled ? Colors.white : const Color(0xFF000DC0),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              Center(
                                child: IconButton(
                                  iconSize: 60,
                                  icon: const Icon(
                                    Icons.fingerprint,
                                    color: Color(0xFF5655B9),
                                  ),
                                  onPressed: () {
                                    _showSuccessPopup(context);
                                  },
                                ),
                              ),
                              
                              const Spacer(), 
                              
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                    );
                                  },
                                  child: RichText(
                                    text: TextSpan(
                                      text: "Bạn chưa có tài khoản? ",
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF343434),
                                        fontSize: 14,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: "Đăng ký",
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF000DC0),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hintText, {
    bool isObscured = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextEditingController? controller,
    List<TextInputFormatter>? inputFormatters,
    String? errorText, 
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscured,
      keyboardType: keyboardType,   
      textInputAction: textInputAction, 
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText, 
        errorStyle: GoogleFonts.poppins(color: Colors.red, fontSize: 12),
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFFCBCBCB),
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBCBCB), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF000DC0), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildLockIllustration() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFE5E2FF), 
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 45,
            height: 55,
            decoration: BoxDecoration(
              color: const Color(0xFF5655B9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_outline, color: Colors.white, size: 28),
          ),
          Positioned(top: 15, left: 35, child: _buildDot(const Color(0xFF281C9D), 6)),
          Positioned(top: 30, right: 20, child: _buildDot(const Color(0xFFFF4267), 10)),
          Positioned(bottom: 25, left: 15, child: _buildDot(const Color(0xFFFFA600), 8)),
          Positioned(left: 10, top: 60, child: _buildDot(const Color(0xFF52D5BA), 5)),
          Positioned(bottom: 45, right: 25, child: _buildDot(const Color(0xFF0890FE), 5)),
        ],
      ),
    );
  }

  Widget _buildDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}