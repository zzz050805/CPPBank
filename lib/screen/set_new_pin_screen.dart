import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../services/user_service.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';

class SetNewPinScreen extends StatefulWidget {
  const SetNewPinScreen({super.key, required this.uid, required this.title});

  final String uid;
  final String title;

  @override
  State<SetNewPinScreen> createState() => _SetNewPinScreenState();
}

class _SetNewPinScreenState extends State<SetNewPinScreen> {
  final UserService _userService = UserService();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _isSubmitting = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void dispose() {
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String newPin = _newPinController.text.trim();
    final String confirmPin = _confirmPinController.text.trim();

    if (newPin.length != 6 || confirmPin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Vui lòng nhập đủ 6 số cho cả hai dòng PIN.',
              'Please enter 6 digits for both PIN fields.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (newPin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Hai mã PIN chưa khớp.', 'PIN entries do not match.'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color.fromARGB(255, 241, 70, 70),
        ),
      );
      _confirmPinController.clear();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _userService.updateSmartOtpPin(uid: widget.uid, newPin: newPin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Mã Smart OTP đã được cập nhật thành công',
              'Smart OTP PIN updated successfully',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color.fromARGB(255, 4, 110, 231),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t('Không thể cập nhật Smart OTP', 'Unable to update Smart OTP')}: $e',
          ),
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

  Widget _warningBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD666)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Lưu ý khi đặt PIN', 'PIN setup rules'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: const Color(0xFF8A6400),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              '- PIN gồm đúng 6 chữ số\n- Không chia sẻ mã PIN cho người khác\n- Nên tránh các dãy số dễ đoán như 123456',
              '- PIN must be exactly 6 digits\n- Do not share your PIN with others\n- Avoid easy combinations like 123456',
            ),
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: const Color(0xFF8A6400),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinInput({required TextEditingController controller}) {
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
          controller: controller,
          autoDisposeControllers: false,
          autoFocus: controller == _newPinController,
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
          animationDuration: const Duration(milliseconds: 170),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: CCPAppBar(
        title: widget.title,
        backgroundColor: const Color(0xFFF5F7FF),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Đặt mã PIN mới', 'Set new PIN'),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF5E667F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPinInput(controller: _newPinController),
                const SizedBox(height: 12),
                Text(
                  _t('Nhập lại mã PIN mới', 'Re-enter new PIN'),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF5E667F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPinInput(controller: _confirmPinController),
                const SizedBox(height: 12),
                _warningBox(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF000DC0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _t('Cập nhật mã PIN', 'Update PIN'),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
