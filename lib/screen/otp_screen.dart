import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';

import 'nfc_screen.dart';

/// Service mock gọi API OTP.
class OtpService {
  Future<String> fetchOtp() async {
    await Future.delayed(const Duration(seconds: 2));
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10).toString()).join();
  }
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

/// Giữ tương thích với các màn cũ đang dùng OTPScreen.
class OTPScreen extends OtpScreen {
  const OTPScreen({super.key, required super.phoneNumber});
}

class _OtpScreenState extends State<OtpScreen> {
  static const Color primaryBlue = Color(0xFF000DC0);
  static const Color primaryPurple = Color(0xFF4A3AFF);

  final OtpService _otpService = OtpService();
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String _currentOtp = '';
  bool _isLoadingOtp = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  Timer? _smsHideTimer;
  bool _showSmsNotification = false;
  String _smsMessage = '';

  @override
  void initState() {
    super.initState();
    for (final focusNode in _focusNodes) {
      focusNode.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _requestOtp();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _smsHideTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (_isLoadingOtp) return;
    setState(() => _isLoadingOtp = true);

    final otp = await _otpService.fetchOtp();
    if (!mounted) return;

    setState(() {
      _currentOtp = otp;
      _isLoadingOtp = false;
    });
    _showMockSms(otp);
  }

  void _showMockSms(String otp) {
    _smsHideTimer?.cancel();
    setState(() {
      _smsMessage =
          'Mã Otp của bạn là: $otp. Vui lòng không cung cấp mã này cho người dùng nào khác không liên quan!';
      _showSmsNotification = true;
    });

    _smsHideTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _showSmsNotification = false);
    });
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 30);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _onResendPressed() async {
    if (_resendCooldown > 0 || _isLoadingOtp) return;
    await _requestOtp();
    if (!mounted) return;
    _clearOtpInputs();
    _startCooldown();
  }

  void _clearOtpInputs() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
  }

  String _enteredOtp() {
    return _controllers.map((controller) => controller.text).join();
  }

  Future<void> _onNextPressed() async {
    final entered = _enteredOtp();
    if (entered.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ 6 chữ số OTP.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (entered == _currentOtp) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NFCScanningScreen()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mã OTP không chính xác. Vui lòng thử lại.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _clearOtpInputs();
  }

  void _onOtpChanged({required String value, required int index}) {
    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isNotEmpty && index == _focusNodes.length - 1) {
      FocusScope.of(context).unfocus();
    }
  }

  void _onOtpBackspace({required String value, required int index}) {
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: primaryBlue,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nhập OTP',
          style: GoogleFonts.poppins(
            color: primaryBlue,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 90, 16, 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nhập mã',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2F2F36),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 6 ô OTP nằm ngang, focus đổi viền xanh, có bóng nhẹ.
                    Row(
                      children: List.generate(6, (index) {
                        final bool isFocused = _focusNodes[index].hasFocus;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: index == 5 ? 0 : 8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isFocused
                                      ? primaryBlue
                                      : const Color(0xFFD9DCE6),
                                  width: isFocused ? 1.8 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isFocused
                                        ? primaryBlue.withOpacity(0.14)
                                        : Colors.black.withOpacity(0.04),
                                    blurRadius: isFocused ? 12 : 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                autofocus: index == 0,
                                keyboardType: TextInputType.number,
                                textInputAction: index == 5
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                  color: const Color(0xFF272730),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(1),
                                ],
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  counterText: '',
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (value) {
                                  _onOtpChanged(value: value, index: index);
                                  _onOtpBackspace(value: value, index: index);
                                },
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),

                    // Nút gửi lại mã nằm ngay dưới 6 ô.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: (_resendCooldown == 0 && !_isLoadingOtp)
                              ? _onResendPressed
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            disabledBackgroundColor: primaryPurple.withOpacity(
                              0.35,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text(
                            _resendCooldown > 0
                                ? 'Gửi lại mã ($_resendCooldown)s'
                                : (_isLoadingOtp
                                      ? 'Đang gửi...'
                                      : 'Gửi lại mã'),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF6A6A75),
                          fontSize: 18,
                          height: 1.42,
                        ),
                        children: [
                          const TextSpan(
                            text:
                                'Chúng tôi đã gửi mã xác thực đến số điện thoại ',
                          ),
                          TextSpan(
                            text: widget.phoneNumber,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF252531),
                            ),
                          ),
                          const TextSpan(text: ' của bạn'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Mã này sẽ hết hiệu lực sau 10 phút kể từ thời điểm gửi.',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6A6A75),
                        fontSize: 18,
                        height: 1.42,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Số điện thoại này gắn liền với tài khoản bạn sử dụng về sau.',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6A6A75),
                        fontSize: 18,
                        height: 1.42,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _onNextPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Tiếp theo',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Mock SMS Notification: xuất hiện từ phía trên màn hình.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            left: 16,
            right: 16,
            top: _showSmsNotification ? topPadding + 8 : -120,
            child: IgnorePointer(
              ignoring: !_showSmsNotification,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _showSmsNotification ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CCP BANK',
                        style: GoogleFonts.poppins(
                          color: primaryBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _smsMessage,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF2E2E36),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lớp trung gian để đúng tên màn hình bước NFC theo yêu cầu.
class NFCScanningScreen extends StatelessWidget {
  const NFCScanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NfcScreen();
  }
}
