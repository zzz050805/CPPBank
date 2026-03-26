import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../data/services/user_service.dart';
import '../effect/gentle_page_route.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'OTP_screen.dart';
import 'set_new_pin_screen.dart';
import 'verify_current_pin_screen.dart';

class SmartOTPScreen extends StatefulWidget {
  const SmartOTPScreen({
    super.key,
    required this.uid,
    this.fieldKey,
    this.fieldLabel,
    this.currentValue,
    this.isManagementMode = false,
  });

  final String uid;
  final String? fieldKey;
  final String? fieldLabel;
  final String? currentValue;
  final bool isManagementMode;

  @override
  State<SmartOTPScreen> createState() => _SmartOTPScreenState();
}

class _SmartOTPScreenState extends State<SmartOTPScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final TextEditingController _otpController = TextEditingController();
  final Random _random = Random();

  late final AnimationController _transitionController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  Timer? _timer;
  int _seconds = 30;
  bool _isSubmitting = false;
  String _demoOtp = '';

  bool get _isCatalogMode => widget.isManagementMode && widget.fieldKey == null;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  String _generateOtp() {
    final int value = _random.nextInt(1000000);
    return value.toString().padLeft(6, '0');
  }

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _transitionController,
            curve: Curves.easeOutCubic,
          ),
        );

    _transitionController.forward();
    if (!_isCatalogMode) {
      _demoOtp = _generateOtp();
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _seconds = 30);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_seconds <= 1) {
        timer.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void _resendOtp() {
    if (_seconds != 0) {
      return;
    }
    setState(() {
      _otpController.clear();
      _demoOtp = _generateOtp();
      _startCountdown();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_t('Mã OTP mới đã được gửi', 'A new OTP has been sent')}: $_demoOtp',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  Future<void> _confirmOtp() async {
    final String entered = _otpController.text.trim();
    if (entered.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Vui lòng nhập đủ 6 chữ số OTP.',
              'Please enter all 6 OTP digits.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (entered != _demoOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t('Mã Smart OTP chưa đúng.', 'Invalid Smart OTP.')} ${_t('Mã hiện tại là', 'Current code is')} $_demoOtp.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (widget.fieldKey == null || widget.fieldLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Thiếu thông tin trường cần cập nhật.',
              'Missing field update metadata.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await _showUpdateDialog();
  }

  Widget _buildVerifyOtpField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double gap = 5;
        final double fieldWidth = ((constraints.maxWidth - (gap * 5)) / 6)
            .clamp(40.0, 48.0);

        final PinTheme pinTheme = PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(12),
          fieldHeight: 62,
          fieldWidth: fieldWidth,
          activeColor: const Color(0xFF000DC0),
          selectedColor: const Color(0xFF000DC0),
          inactiveColor: const Color(0xFFD7DDEE),
          activeBorderWidth: 1.2,
          selectedBorderWidth: 1.1,
          inactiveBorderWidth: 0.9,
          activeFillColor: const Color(0xFFF3F6FF),
          selectedFillColor: const Color(0xFFF3F6FF),
          inactiveFillColor: const Color(0xFFF8FAFF),
        );

        return PinCodeTextField(
          appContext: context,
          length: 6,
          controller: _otpController,
          autoDisposeControllers: false,
          autoFocus: true,
          keyboardType: TextInputType.number,
          animationType: AnimationType.fade,
          enableActiveFill: true,
          pinTheme: pinTheme,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textStyle: GoogleFonts.poppins(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF272730),
          ),
          onChanged: (_) {},
          beforeTextPaste: (_) => false,
          onCompleted: (_) => _confirmOtp(),
          animationDuration: const Duration(milliseconds: 170),
        );
      },
    );
  }

  Future<void> _showUpdateDialog() async {
    final TextEditingController controller = TextEditingController(
      text: widget.currentValue ?? '',
    );

    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_t('Cập nhật', 'Update')} ${widget.fieldLabel ?? ''}',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B2140),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: _t('Nhập giá trị mới', 'Enter new value'),
                    hintStyle: GoogleFonts.poppins(fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF000DC0)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(
                          _t('Hủy', 'Cancel'),
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF4A5168),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000DC0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _t('Lưu', 'Save'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved != true) {
      controller.dispose();
      return;
    }

    if (!mounted) {
      controller.dispose();
      return;
    }

    final String newValue = controller.text.trim();
    controller.dispose();

    if (newValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Giá trị mới không được để trống.',
              'New value cannot be empty.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _userService.updateUserField(
        uid: widget.uid,
        fieldKey: widget.fieldKey!,
        value: newValue,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Cập nhật thành công!', 'Updated successfully!')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_t('Lưu thất bại', 'Update failed')}: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _defaultPinFromId(dynamic idNumberRaw) {
    final String digits = (idNumberRaw ?? '').toString().replaceAll(
      RegExp(r'\D'),
      '',
    );
    if (digits.isEmpty) {
      return '';
    }
    if (digits.length >= 6) {
      return digits.substring(digits.length - 6);
    }
    return digits.padLeft(6, '0');
  }

  Future<void> _openChangePinFlow({
    required String uid,
    required String phoneNumber,
  }) async {
    final bool? updated = await Navigator.push<bool>(
      context,
      GentlePageRoute<bool>(
        page: VerifyCurrentPinScreen(uid: uid, phoneNumber: phoneNumber),
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Mã Smart OTP đã được cập nhật thành công',
              'Smart OTP PIN updated successfully',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
  }

  Future<void> _openResetPinFlow({
    required String uid,
    required String phoneNumber,
  }) async {
    final bool? smsVerified = await Navigator.push<bool>(
      context,
      GentlePageRoute<bool>(
        page: OtpScreen(phoneNumber: phoneNumber, isVerifySmsOnly: true),
      ),
    );

    if (smsVerified != true || !mounted) {
      return;
    }

    final bool? updated = await Navigator.push<bool>(
      context,
      GentlePageRoute<bool>(
        page: SetNewPinScreen(
          uid: uid,
          title: _t('Đặt lại mã PIN', 'Reset PIN'),
        ),
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Mã Smart OTP đã được cập nhật thành công',
              'Smart OTP PIN updated successfully',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
  }

  Widget _buildManagementBody() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF000DC0)),
          );
        }

        final Map<String, dynamic> data =
            snapshot.data?.data() ?? <String, dynamic>{};
        final String savedPin = (data['smartOtpPin'] ?? '').toString().trim();
        final String defaultPin = _defaultPinFromId(
          data['idNumber'] ?? data['cccd'],
        );
        final String effectivePin = savedPin.isNotEmpty ? savedPin : defaultPin;
        final bool isRegistered = effectivePin.isNotEmpty;
        final String statusLabel = isRegistered
            ? _t('Đã đăng ký', 'Registered')
            : _t('Chưa đăng ký', 'Not registered');
        final Color statusColor = isRegistered
            ? const Color(0xFF2E7D32)
            : const Color(0xFFB23B3B);
        final String phoneNumber = (data['phoneNumber'] ?? '')
            .toString()
            .trim();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF000DC0),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _t('Trạng thái Smart OTP', 'Smart OTP status'),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFF18203A),
                        ),
                      ),
                    ),
                    Text(
                      statusLabel,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_t('PIN hiện tại', 'Current PIN')}: ${effectivePin.isEmpty ? _t('Chưa có', 'Not set') : '••••••'}',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF6A728B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              _menuCard(
                icon: Icons.lock_reset,
                title: _t('Đổi mã PIN', 'Change PIN'),
                subtitle: _t(
                  'Thay đổi mã PIN hiện tại',
                  'Change current PIN',
                ),
                onTap: () => _openChangePinFlow(
                  uid: widget.uid,
                  phoneNumber: phoneNumber.isEmpty ? '0*********' : phoneNumber,
                ),
              ),
              const SizedBox(height: 12),
              _menuCard(
                icon: Icons.refresh_outlined,
                title: _t('Đặt lại mã PIN', 'Reset PIN'),
                subtitle: _t(
                  'Khi quên mã PIN hiện tại',
                  'For forgotten current PIN',
                ),
                onTap: () => _openResetPinFlow(
                  uid: widget.uid,
                  phoneNumber: phoneNumber.isEmpty ? '0*********' : phoneNumber,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF1FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF000DC0), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C233C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6A728B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF7F88A6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyBody() {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(
                      'Vui lòng nhập mã Smart OTP gồm 6 chữ số để xác nhận thay đổi thông tin cá nhân.',
                      'Enter the 6-digit Smart OTP code to confirm personal info update.',
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF555D73),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '${_t('Mã Smart OTP demo', 'Demo Smart OTP')}: $_demoOtp',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7A5C00),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildVerifyOtpField(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _seconds == 0 ? _resendOtp : null,
                        child: Text(
                          _t('Gửi lại OTP', 'Resend OTP'),
                          style: GoogleFonts.poppins(
                            color: _seconds == 0
                                ? const Color(0xFF000DC0)
                                : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _seconds == 0
                            ? _t('Bạn có thể gửi lại', 'You can resend now')
                            : '$_seconds s',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF7B839C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _confirmOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000DC0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSubmitting
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
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: CCPAppBar(
        title: _isCatalogMode
            ? _t('Smart OTP', 'Smart OTP')
            : _t('Xác thực bảo mật', 'Security Verification'),
        backgroundColor: const Color(0xFFF8F9FE),
      ),
      body: _isCatalogMode ? _buildManagementBody() : _buildVerifyBody(),
    );
  }
}
