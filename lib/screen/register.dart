import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_text.dart';
import 'register_password_screen.dart'; // Đă d?i sang trang Password

// --- FORMATTER ÉP VI?T HOA TOÀN B? CH? ---
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// --- FORMATTER T? Đ?NG THÊM D?U "/" VÀ RÀNG BU?C NGÀY THÁNG ---
class DateTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text.length > newValue.text.length) return newValue;
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.length > 8) cleanText = cleanText.substring(0, 8);
    if (cleanText.length >= 2) {
      int day = int.parse(cleanText.substring(0, 2));
      if (day > 31 || day == 0) return oldValue;
    }
    if (cleanText.length >= 4) {
      int month = int.parse(cleanText.substring(2, 4));
      if (month > 12 || month == 0) return oldValue;
    }
    String formattedText = '';
    for (int i = 0; i < cleanText.length; i++) {
      formattedText += cleanText[i];
      if ((i == 1 || i == 3) && i != cleanText.length - 1) formattedText += '/';
    }
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cccdController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String? _nameError;
  String? _phoneError;
  String? _cccdError;
  String? _dateError;
  String? _addressError;

  bool _isAgreed = false;
  bool _isFormValid = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateForm);
    _phoneController.addListener(_validateForm);
    _cccdController.addListener(_validateForm);
    _dateController.addListener(_validateForm);
    _addressController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cccdController.dispose();
    _dateController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _isFormValid =
          _nameController.text.isNotEmpty &&
          _phoneController.text.length == 10 &&
          _cccdController.text.length == 12 &&
          _dateController.text.length == 10 &&
          _addressController.text.isNotEmpty &&
          _isAgreed;

      if (_nameController.text.isNotEmpty) _nameError = null;
      if (_phoneController.text.length == 10) _phoneError = null;
      if (_cccdController.text.length == 12) _cccdError = null;
      if (_dateController.text.length == 10) _dateError = null;
      if (_addressController.text.isNotEmpty) _addressError = null;
    });
  }

  // --- S?A HÀM X? LƯ: CHUY?N SANG TRANG PASSWORD VÀ TRUY?N D? LI?U ---
  void _handleRegister() {
    setState(() {
      if (_nameController.text.isEmpty) {
        _nameError = _t(
          'B?n c?n nh?p h? và tên',
          'Please enter your full name',
        );
      }
      if (_phoneController.text.length < 10) {
        _phoneError = _t(
          'S? di?n tho?i ph?i d? 10 s?',
          'Phone number must have 10 digits',
        );
      }
      if (_cccdController.text.length < 12) {
        _cccdError = _t(
          'S? CCCD ph?i d? 12 s?',
          'ID card number must have 12 digits',
        );
      }
      if (_dateController.text.length < 10) {
        _dateError = _t(
          'Nh?p d? d?nh d?ng DD/MM/YYYY',
          'Please use DD/MM/YYYY format',
        );
      }
      if (_addressController.text.isEmpty) {
        _addressError = _t(
          'B?n c?n nh?p d?a ch? thu?ng trú',
          'Please enter your permanent address',
        );
      }

      if (!_isAgreed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Vui ḷng d?ng ư v?i Đi?u kho?n',
                'Please agree to the Terms and Conditions',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    if (_isFormValid) {
      // ĐĂ S?A: Chuy?n hu?ng và truy?n d? li?u sang RegisterPasswordScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegisterPasswordScreen(
            fullName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            cccd: _cccdController.text.trim(),
            issueDate: _dateController.text.trim(),
            address: _addressController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          _t('Đang kư', 'Register'),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
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
                physics:
                    (_nameError == null &&
                        _phoneError == null &&
                        _cccdError == null &&
                        _dateError == null &&
                        _addressError == null)
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Đang kư ngay!', 'Register now!'),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF000DC0),
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _t(
                        'Đ? tr? thành thành viên c?a CCPBank',
                        'Become a CCPBank member',
                      ),
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 25),

                    Center(
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF2F4FB),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/Logo2.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.broken_image,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildTextField(
                      controller: _nameController,
                      hintText: _t('H? & Tên c?a b?n', 'Your full name'),
                      icon: Icons.person_outline,
                      errorText: _nameError,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                    ),

                    _buildTextField(
                      controller: _phoneController,
                      hintText: _t('S? di?n tho?i (+84)', 'Phone number (+84)'),
                      icon: Icons.phone_android_outlined,
                      errorText: _phoneError,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),

                    _buildTextField(
                      controller: _cccdController,
                      hintText: _t('S? CCCD', 'ID card number'),
                      icon: Icons.credit_card_outlined,
                      errorText: _cccdError,
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),

                    _buildTextField(
                      controller: _dateController,
                      hintText: _t(
                        'Ngày c?p (DD/MM/YYYY)',
                        'Issue date (DD/MM/YYYY)',
                      ),
                      icon: Icons.calendar_month_outlined,
                      errorText: _dateError,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      inputFormatters: [DateTextFormatter()],
                    ),

                    _buildTextField(
                      controller: _addressController,
                      hintText: _t('Đ?a ch? thu?ng trú', 'Permanent address'),
                      icon: Icons.location_on_outlined,
                      errorText: _addressError,
                    ),

                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _isAgreed,
                            activeColor: const Color(0xFF000DC0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (value) {
                              setState(() => _isAgreed = value ?? false);
                              _validateForm();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(
                                  text: _t(
                                    'B?ng vi?c t?o tài kho?n, b?n d?ng ư v?i các\n',
                                    'By creating an account, you agree to the\n',
                                  ),
                                ),
                                TextSpan(
                                  text: _t(
                                    'Đi?u kho?n và Đi?u ki?n',
                                    'Terms and Conditions',
                                  ),
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF000DC0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: _t(
                                    ' c?a chúng tôi.',
                                    ' of our service.',
                                  ),
                                ),
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
                          backgroundColor: _isFormValid
                              ? const Color(0xFF000DC0)
                              : const Color(0xFFF2F4FB),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _handleRegister,
                        child: Text(
                          _t('TI?P THEO', 'NEXT'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _isFormValid
                                ? Colors.white
                                : const Color(0xFF000DC0),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: _t(
                                  'B?n dă có tài kho?n! ',
                                  'Already have an account? ',
                                ),
                              ),
                              TextSpan(
                                text: _t('Đang nh?p', 'Log in'),
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? errorText,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (errorText == null)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF343434),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: errorText != null ? Colors.red : Colors.grey[500],
              size: 20,
            ),
            hintText: hintText,
            errorText: errorText,
            errorStyle: GoogleFonts.poppins(color: Colors.red, fontSize: 12),
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey[400],
              fontSize: 13,
            ),
            counterText: "",
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 17,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF2F4FB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF000DC0),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
