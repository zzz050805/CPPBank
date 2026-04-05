import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../core/app_translations.dart';
import '../data/user_firestore_service.dart';

class PinPopupWidget extends StatefulWidget {
  const PinPopupWidget({super.key, required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<PinPopupWidget> createState() => _PinPopupWidgetState();
}

class _PinPopupWidgetState extends State<PinPopupWidget> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  bool _isLoading = false;
  String? _errorText;

  String _tr(String key) => AppTranslations.getText(context, key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _pinFocusNode.requestFocus();
    });
  }

  String _resolveUid() {
    final String? fromService = UserFirestoreService.instance.currentUserDocId;
    if (fromService != null && fromService.isNotEmpty) {
      return fromService;
    }

    final String? fromProfile =
        UserFirestoreService.instance.latestProfile?.uid;
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }

    final String? fromAuth = FirebaseAuth.instance.currentUser?.uid;
    if (fromAuth != null && fromAuth.isNotEmpty) {
      return fromAuth;
    }

    return '';
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = (value ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  String _defaultPinFromId(dynamic rawIdNumber) {
    final String digits = (rawIdNumber ?? '').toString().replaceAll(
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

  Future<String> _loadExpectedPin(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final Map<String, dynamic> data =
        userSnapshot.data() ?? <String, dynamic>{};

    final String savedPin = _firstNonEmpty(<dynamic>[
      data['smartOTP'],
      data['pin'],
      data['smartOtpPin'],
    ]);
    if (savedPin.isNotEmpty) {
      return savedPin;
    }

    return _defaultPinFromId(data['idNumber'] ?? data['cccd']);
  }

  Future<void> _verifyPin(String enteredPin) async {
    if (_isLoading || enteredPin.length != 6) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final String uid = _resolveUid();
      if (uid.isEmpty) {
        throw Exception(_tr('no_valid_login_session'));
      }

      final String expectedPin = await _loadExpectedPin(uid);
      if (expectedPin.isEmpty) {
        throw Exception(_tr('smart_otp_not_set_up'));
      }

      if (expectedPin != enteredPin) {
        setState(() {
          _errorText = _tr('incorrect_pin_try_again');
          _isLoading = false;
        });
        _pinController.clear();
        return;
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : _tr('verification_failed_try_again');
        _isLoading = false;
      });
      _pinController.clear();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double popupHeight = MediaQuery.of(context).size.height * 0.55;
    final EdgeInsets insets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        height: popupHeight,
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F1C49).withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC7CEDF),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                _tr('transaction_authentication'),
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F1C49),
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _tr('enter_smart_otp_code'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF6A738D),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              PinCodeTextField(
                appContext: context,
                controller: _pinController,
                focusNode: _pinFocusNode,
                autoFocus: true,
                length: 6,
                autoDisposeControllers: false,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                enableActiveFill: true,
                obscuringCharacter: '●',
                obscureText: true,
                textStyle: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF152347),
                ),
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(14),
                  fieldHeight: 60,
                  fieldWidth: 48,
                  activeColor: const Color(0xFF0A2A8D),
                  selectedColor: const Color(0xFF0A2A8D),
                  inactiveColor: const Color(0xFFD6DEEE),
                  activeFillColor: const Color(0xFFF0F4FF),
                  selectedFillColor: const Color(0xFFF0F4FF),
                  inactiveFillColor: const Color(0xFFF8FAFF),
                ),
                onChanged: (_) {
                  setState(() {
                    if (_errorText != null) {
                      _errorText = null;
                    }
                  });
                },
                onCompleted: _verifyPin,
              ),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorText!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const Spacer(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pop(context);
                            },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_tr('cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading || _pinController.text.length != 6
                          ? null
                          : () {
                              _verifyPin(_pinController.text);
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_tr('confirm')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
