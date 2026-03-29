import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../l10n/app_text.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.phoneNumber,
    this.personalInfo = const [],
  });

  final String? phoneNumber;
  final List<String> personalInfo;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  // Controller để lấy giá trị từ TextField
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // State để ẩn/hiện mật khẩu
  bool _showNew = false;
  bool _showConfirm = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);
  String? _passwordError;
  String? _confirmPasswordError;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasDigit = false;
  bool _hasSpecial = false;
  bool _notMatchPersonalInfo = true;

  bool get _isPasswordValid =>
      _hasMinLength &&
      _hasUppercase &&
      _hasDigit &&
      _hasSpecial &&
      _notMatchPersonalInfo;

  bool get _isConfirmValid =>
      _confirmPasswordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text;

  bool get _canSubmit => _isPasswordValid && _isConfirmValid;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validateForm);
    _confirmPasswordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final String password = _passwordController.text.trim();
    final String confirm = _confirmPasswordController.text.trim();

    final bool hasMinLength = password.length >= 8;
    final bool hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final bool hasDigit = RegExp(r'\d').hasMatch(password);
    final bool hasSpecial = RegExp(
      r'[!@#\$%^&*(),.?":{}|<>]',
    ).hasMatch(password);
    final bool notMatchPersonalInfo = !_containsPersonalInfo(password);

    String? passwordError;
    if (password.isNotEmpty) {
      if (!hasMinLength || !hasUppercase || !hasDigit || !hasSpecial) {
        passwordError =
            'Mật khẩu phải có ít nhất 8 ký tự, gồm chữ hoa, số và ký tự đặc biệt.';
      } else if (!notMatchPersonalInfo) {
        passwordError = 'Mật khẩu không được trùng thông tin cá nhân.';
      }
    }

    String? confirmError;
    if (confirm.isNotEmpty && confirm != password) {
      confirmError = 'Mật khẩu nhập lại không khớp.';
    }

    if (!mounted) return;
    setState(() {
      _hasMinLength = hasMinLength;
      _hasUppercase = hasUppercase;
      _hasDigit = hasDigit;
      _hasSpecial = hasSpecial;
      _notMatchPersonalInfo = notMatchPersonalInfo;
      _passwordError = passwordError;
      _confirmPasswordError = confirmError;
    });
  }

  bool _containsPersonalInfo(String password) {
    final String normalizedPassword = password.toLowerCase();
    final List<String> candidates = [
      ...(widget.personalInfo),
      if (widget.phoneNumber != null) widget.phoneNumber!,
    ];

    for (final raw in candidates) {
      final String item = raw.trim().toLowerCase();
      if (item.isEmpty) continue;

      final String alnum = item.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (alnum.length >= 4 && normalizedPassword.contains(alnum)) {
        return true;
      }

      final List<String> parts = item.split(RegExp(r'\s+'));
      for (final part in parts) {
        final String token = part.replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (token.length >= 4 && normalizedPassword.contains(token)) {
          return true;
        }
      }
    }
    return false;
  }

  String _hashPassword(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  void _handleSubmit() {
    _validateForm();
    if (!_canSubmit) return;

    final String hashedPassword = _hashPassword(
      _passwordController.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đổi mật khẩu thành công. Mật khẩu đã được mã hóa.'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );

    // TODO: Gửi hashedPassword lên API/Firebase để cập nhật mật khẩu.
    debugPrint('hashedPassword: $hashedPassword');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Tương đương bg-background
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
            ), // Giới hạn chiều rộng
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header ---
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.chevron_left, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _t('Quên mật khẩu', 'Forgot password'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // --- Form Card ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Nhập mật khẩu mới
                      _buildPasswordField(
                        label: _t('Nhập mật khẩu mới', 'Enter new password'),
                        controller: _passwordController,
                        isHidden: !_showNew,
                        onToggle: () => setState(() => _showNew = !_showNew),
                        errorText: _passwordError,
                      ),
                      const SizedBox(height: 10),
                      _buildRuleItem('Ít nhất 8 ký tự', _hasMinLength),
                      _buildRuleItem('Có chữ hoa', _hasUppercase),
                      _buildRuleItem('Có số', _hasDigit),
                      _buildRuleItem(
                        'Có ký tự đặc biệt (@,!,#,...)',
                        _hasSpecial,
                      ),
                      _buildRuleItem(
                        'Không trùng thông tin cá nhân',
                        _notMatchPersonalInfo,
                      ),
                      const SizedBox(height: 20),
                      // Nhập lại mật khẩu mới
                      _buildPasswordField(
                        label: _t(
                          'Nhập lại mật khẩu mới',
                          'Re-enter new password',
                        ),
                        controller: _confirmPasswordController,
                        isHidden: !_showConfirm,
                        onToggle: () =>
                            setState(() => _showConfirm = !_showConfirm),
                        errorText: _confirmPasswordError,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- Submit Button ---
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _handleSubmit : null,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((
                        states,
                      ) {
                        if (states.contains(WidgetState.disabled)) {
                          return const Color(0xFFF0F0F0);
                        }
                        return const Color(0xFF3228A8);
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((
                        states,
                      ) {
                        if (states.contains(WidgetState.disabled)) {
                          return const Color(0xFFB5B5B5);
                        }
                        return Colors.white;
                      }),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      elevation: WidgetStateProperty.all<double>(0),
                    ),
                    child: Text(
                      _t('Đổi mật khẩu', 'Change password'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  // Widget con để build các ô nhập mật khẩu
  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool isHidden,
    required VoidCallback onToggle,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isHidden,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isHidden ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: Colors.grey,
              ),
              onPressed: onToggle,
            ),
            errorText: errorText,
          ),
        ),
      ],
    );
  }

  Widget _buildRuleItem(String text, bool passed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: passed ? const Color(0xFF2E7D32) : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: passed ? const Color(0xFF2E7D32) : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
