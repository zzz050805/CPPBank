import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/notification_service.dart';
import '../widget/ccp_app_bar.dart';
import 'login.dart';

class DeleteAccountOtpScreen extends StatefulWidget {
  const DeleteAccountOtpScreen({super.key});

  @override
  State<DeleteAccountOtpScreen> createState() => _DeleteAccountOtpScreenState();
}

class _DeleteAccountOtpScreenState extends State<DeleteAccountOtpScreen> {
  final Random _random = Random();
  final List<TextEditingController> _controllers =
      List<TextEditingController>.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List<FocusNode>.generate(
    6,
    (_) => FocusNode(),
  );

  Timer? _cooldownTimer;
  int _resendCooldown = 0;
  bool _isSendingOtp = false;
  String _currentOtp = '';
  bool _isDeleting = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    for (final FocusNode node in _focusNodes) {
      node.addListener(() {
        if (mounted) {
          setState(() {});
        }
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
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    for (final FocusNode node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _generateOtp() {
    final int value = _random.nextInt(1000000);
    return value.toString().padLeft(6, '0');
  }

  Future<void> _requestOtp() async {
    if (_isSendingOtp) {
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _currentOtp = _generateOtp();
    });

    await Future.delayed(const Duration(seconds: 1));
    await NotificationService().showNotification(
      title: 'CCP BANK',
      body:
          'Mã OTP của bạn là $_currentOtp. Vui lòng không chia sẻ cho bất kỳ ai.',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSendingOtp = false;
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
    if (_resendCooldown > 0 || _isSendingOtp) {
      return;
    }

    _clearOtpInputs();
    _startCooldown();
    await _requestOtp();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(
            'OTP đã được gửi qua thông báo hệ thống.',
            'OTP was sent via system notification.',
          ),
          style: GoogleFonts.poppins(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearOtpInputs() {
    for (final TextEditingController controller in _controllers) {
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

  Future<void> _handleDeleteAccount() async {
    final String otp = _enteredOtp();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Vui lòng nhập đủ 6 số OTP.',
              'Please enter the full 6-digit OTP.',
            ),
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (otp != _currentOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Mã OTP không chính xác. Vui lòng thử lại.',
              'Incorrect OTP code. Please try again.',
            ),
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
      _clearOtpInputs();
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final String? resolvedUid =
          user?.uid ?? UserFirestoreService.instance.currentUserDocId;

      if (resolvedUid == null || resolvedUid.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Không tìm thấy phiên đăng nhập hợp lệ.',
                'No valid login session found.',
              ),
              style: GoogleFonts.poppins(),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      if (user != null) {
        await Future.wait<void>([
          FirebaseFirestore.instance
              .collection('users')
              .doc(resolvedUid)
              .delete(),
          user.delete(),
        ]);
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(resolvedUid)
            .delete();
      }

      UserFirestoreService.instance.setFallbackDocId(null);
      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Tài khoản đã được xóa thành công',
              'Account deleted successfully',
            ),
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      final String message = e.code == 'requires-recent-login'
          ? _t(
              'Phiên đăng nhập đã hết hạn xác thực. Vui lòng đăng nhập lại rồi thử xóa tài khoản.',
              'Session is too old for this action. Please log in again and retry.',
            )
          : _t(
              'Không thể xóa tài khoản: ${e.message ?? e.code}',
              'Unable to delete account: ${e.message ?? e.code}',
            );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String friendlyError = e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Xóa tài khoản thất bại: $friendlyError',
              'Delete account failed: $friendlyError',
            ),
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: CCPAppBar(
        title: _t('Xác thực bảo mật', 'Security verification'),
        backgroundColor: const Color(0xFFF5F7FF),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Xác thực bảo mật', 'Security verification'),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF121826),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _t(
                        'Vui lòng nhập mã OTP vừa được gửi đến số điện thoại của bạn để xác nhận xóa tài khoản.',
                        'Please enter the OTP sent to your phone number to confirm account deletion.',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.45,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 18),
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
                          children: List<Widget>.generate(6, (int index) {
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
                                        ? const Color(0xFF000DC0)
                                        : const Color(0xFFD7DDEE),
                                    width: isFocused ? 1.2 : 0.9,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isFocused
                                          ? const Color(
                                              0xFF000DC0,
                                            ).withValues(alpha: 0.18)
                                          : Colors.black.withValues(
                                              alpha: 0.03,
                                            ),
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
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(1),
                                  ],
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (String value) {
                                    _onOtpChanged(value: value, index: index);
                                  },
                                  onSubmitted: (_) {
                                    if (!_isDeleting && index == 5) {
                                      _handleDeleteAccount();
                                    }
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
                          onPressed: (_resendCooldown == 0 && !_isSendingOtp)
                              ? _onResendPressed
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A3AFF),
                            disabledBackgroundColor: const Color(
                              0xFF4A3AFF,
                            ).withValues(alpha: 0.35),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text(
                            _resendCooldown > 0
                                ? _t(
                                    'Gửi lại mã ($_resendCooldown)s',
                                    'Resend code ($_resendCooldown)s',
                                  )
                                : (_isSendingOtp
                                      ? _t('Đang gửi...', 'Sending...')
                                      : _t('Gửi lại mã', 'Resend code')),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t(
                        'Vui lòng nhập đúng mã OTP 6 chữ số đã nhận qua thông báo hệ thống.',
                        'Please enter the exact 6-digit OTP received via system notification.',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: const Color(0xFF98A2B3),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isDeleting ? null : _handleDeleteAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.red.shade200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _t('Xác nhận', 'Confirm'),
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
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
      ),
    );
  }
}
