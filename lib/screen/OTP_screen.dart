import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';

import '../services/user_service.dart';
import '../l10n/app_text.dart';
import '../services/notification_service.dart';
import '../widget/ccp_app_bar.dart';
import 'nfc_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.isResetSmartOtp = false,
    this.isVerifySmsOnly = false,
    this.resetSmartOtpUid,
    this.newSmartOtpPin,
  });

  final String phoneNumber;
  final bool isResetSmartOtp;
  final bool isVerifySmsOnly;
  final String? resetSmartOtpUid;
  final String? newSmartOtpPin;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

/// Gi? tuong thích v?i các màn cu dang dùng OTPScreen.
class OTPScreen extends OtpScreen {
  const OTPScreen({super.key, required super.phoneNumber});
}

class _OtpScreenState extends State<OtpScreen> {
  static const Color primaryBlue = Color(0xFF000DC0);
  static const Color primaryPurple = Color(0xFF4A3AFF);

  final UserService _userService = UserService();
  final Random _random = Random();
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String _currentOtp = '';
  bool _isLoadingOtp = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  bool get _isSmartOtpSmsFlow =>
      widget.isVerifySmsOnly || widget.isResetSmartOtp;

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

    final String otp = _generateOtp();
    _currentOtp = otp;
    await Future.delayed(const Duration(seconds: 1));
    await NotificationService().showNotification(
      title: 'CCP BANK',
      body:
          'Mă OTP c?a b?n là $otp. Vui ḷng không chia s? cho b?t k? ai.',
    );

    if (!mounted) return;
    setState(() {
      _isLoadingOtp = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(
            'OTP dă du?c g?i qua thông báo h? th?ng.',
            'OTP was sent via system notification.',
          ),
          style: GoogleFonts.poppins(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _generateOtp() {
    final int value = _random.nextInt(1000000);
    return value.toString().padLeft(6, '0');
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

  void _onOtpChanged({required String value, required int index}) {
    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _onNextPressed() async {
    final entered = _enteredOtp();
    if (entered.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Vui ḷng nh?p d?y d? 6 ch? s? OTP.',
              'Please enter all 6 OTP digits.',
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (entered == _currentOtp) {
      if (widget.isVerifySmsOnly) {
        Navigator.pop(context, true);
        return;
      }

      if (widget.isResetSmartOtp) {
        final String? uid = widget.resetSmartOtpUid;
        final String? newPin = widget.newSmartOtpPin;
        if (uid == null ||
            uid.isEmpty ||
            newPin == null ||
            newPin.length != 6) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _t(
                  'Thi?u d? li?u c?p nh?t Smart OTP PIN.',
                  'Missing Smart OTP PIN update data.',
                ),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        try {
          await _userService.updateSmartOtpPin(uid: uid, newPin: newPin);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _t(
                  'Mă Smart OTP dă du?c c?p nh?t thành công',
                  'Smart OTP PIN updated successfully',
                ),
              ),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_t('Không th? c?p nh?t Smart OTP', 'Unable to update Smart OTP')}: $e',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NFCScanningScreen()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(
            'Mă OTP không chính xác. Vui ḷng th? l?i.',
            'Incorrect OTP code. Please try again.',
          ),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _clearOtpInputs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: CCPAppBar(
        title: _isSmartOtpSmsFlow
            ? _t('Nh?p SMS OTP', 'Enter SMS OTP')
            : _t('Nh?p OTP', 'Enter OTP'),
        backgroundColor: const Color(0xFFF3F4F8),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 90, 16, 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSmartOtpSmsFlow
                      ? _t('Nh?p mă SMS OTP', 'Enter SMS OTP code')
                      : _t('Nh?p mă', 'Enter code'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2F2F36),
                  ),
                ),
                const SizedBox(height: 14),

                LayoutBuilder(
                  builder: (context, constraints) {
                    const double gap = 5;
                    final double fieldWidth =
                        ((constraints.maxWidth - (gap * 5)) / 6).clamp(
                          40.0,
                          48.0,
                        );

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        final bool isFocused = _focusNodes[index].hasFocus;
                        return SizedBox(
                          width: fieldWidth,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 62,
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? const Color(0xFFF3F6FF)
                                  : const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isFocused
                                    ? primaryBlue
                                    : const Color(0xFFD7DDEE),
                                width: isFocused ? 1.2 : 0.9,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isFocused
                                      ? primaryBlue.withValues(alpha: 0.18)
                                      : Colors.black.withValues(alpha: 0.03),
                                  blurRadius: isFocused ? 16 : 10,
                                  offset: const Offset(0, 4),
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
                                fontSize: 23,
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
                              },
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 14),

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
                        disabledBackgroundColor: primaryPurple.withValues(
                          alpha: 0.35,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        _resendCooldown > 0
                            ? _t(
                                'G?i l?i mă ($_resendCooldown)s',
                                'Resend code ($_resendCooldown)s',
                              )
                            : (_isLoadingOtp
                                  ? _t('Đang g?i...', 'Sending...')
                                  : _t('G?i l?i mă', 'Resend code')),
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
                      TextSpan(
                        text: _isSmartOtpSmsFlow
                            ? _t(
                                'Chúng tôi dă g?i mă xác th?c SMS OTP d?n s? di?n tho?i ',
                                'We have sent an SMS OTP verification code to phone number ',
                              )
                            : _t(
                                'Chúng tôi dă g?i mă xác th?c d?n s? di?n tho?i ',
                                'We have sent a verification code to phone number ',
                              ),
                      ),
                      TextSpan(
                        text: widget.phoneNumber,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF252531),
                        ),
                      ),
                      TextSpan(text: _t(' c?a b?n', '.')),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _t(
                    'Mă này s? h?t hi?u l?c sau 10 phút k? t? th?i di?m g?i.',
                    'This code will expire 10 minutes after it is sent.',
                  ),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF6A6A75),
                    fontSize: 18,
                    height: 1.42,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isSmartOtpSmsFlow
                      ? _t(
                          'S? di?n tho?i này dang du?c dùng d? xác th?c thay d?i Smart OTP.',
                          'This phone number is used to verify Smart OTP changes.',
                        )
                      : _t(
                          'S? di?n tho?i này g?n li?n v?i tài kho?n b?n s? d?ng v? sau.',
                          'This phone number will be linked to your account for future use.',
                        ),
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
                      _isSmartOtpSmsFlow
                          ? _t('Xác nh?n', 'Confirm')
                          : _t('Ti?p theo', 'Next'),
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
    );
  }
}

/// L?p trung gian d? dúng tên màn h́nh bu?c NFC theo yêu c?u.
class NFCScanningScreen extends StatelessWidget {
  const NFCScanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NfcScreen();
  }
}
