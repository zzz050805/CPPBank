import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../effect/gentle_page_route.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'set_new_pin_screen.dart';

class VerifyCurrentPinScreen extends StatefulWidget {
  const VerifyCurrentPinScreen({
    super.key,
    required this.uid,
    required this.phoneNumber,
  });

  final String uid;
  final String phoneNumber;

  @override
  State<VerifyCurrentPinScreen> createState() => _VerifyCurrentPinScreenState();
}

class _VerifyCurrentPinScreenState extends State<VerifyCurrentPinScreen> {
  final TextEditingController _pinController = TextEditingController();

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  String _defaultPinFromId(dynamic idNumberRaw) {
    final String digits = (idNumberRaw ?? '').toString().replaceAll(
      RegExp(r'\D'),
      '',
    );
    if (digits.isEmpty) return '';
    if (digits.length >= 6) return digits.substring(digits.length - 6);
    return digits.padLeft(6, '0');
  }

  Future<void> _verifyAndContinue(String currentPin) async {
    final String enteredPin = _pinController.text.trim();
    if (enteredPin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Vui lòng nhập đủ 6 số PIN.', 'Please enter all 6 PIN digits.'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (enteredPin != currentPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Mã PIN hiện tại không đúng.', 'Current PIN is incorrect.'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      _pinController.clear();
      return;
    }

    final bool? updated = await Navigator.push<bool>(
      context,
      GentlePageRoute<bool>(
        page: SetNewPinScreen(
          uid: widget.uid,
          title: _t('Đặt mã PIN mới', 'Set new PIN'),
        ),
      ),
    );

    if (updated == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget _buildPinInput() {
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
          controller: _pinController,
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
          onCompleted: (_) {},
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
        title: _t('Nhập mã PIN hiện tại', 'Enter current PIN'),
        backgroundColor: const Color(0xFFF5F7FF),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
          final String currentPin = savedPin.isNotEmpty ? savedPin : defaultPin;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(
                      'Vui lòng nhập mã PIN Smart OTP hiện tại để tiếp tục.',
                      'Please enter your current Smart OTP PIN to continue.',
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF5E667F),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildPinInput(),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _verifyAndContinue(currentPin),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000DC0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _t('Xác nhận', 'Confirm'),
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
          );
        },
      ),
    );
  }
}
