import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'login.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.phoneNumber,
    this.personalInfo = const [],
    this.requireCurrentPassword = false,
  });

  final String? phoneNumber;
  final List<String> personalInfo;
  final bool requireCurrentPassword;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isSubmitting = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);
  String? _oldPasswordError;
  String? _passwordError;
  String? _confirmPasswordError;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasDigit = false;
  bool _hasSpecial = false;
  bool _notMatchPersonalInfo = true;
  bool _differentFromOld = true;

  bool get _contextRulePassed =>
      widget.requireCurrentPassword ? _differentFromOld : _notMatchPersonalInfo;

  bool get _isPasswordValid =>
      _hasMinLength &&
      _hasUppercase &&
      _hasDigit &&
      _hasSpecial &&
      _contextRulePassed;

  bool get _isConfirmValid =>
      _confirmPasswordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text;

  bool get _canSubmit =>
      _isPasswordValid &&
      _isConfirmValid &&
      (!widget.requireCurrentPassword ||
          _oldPasswordController.text.trim().isNotEmpty) &&
      !_isSubmitting;

  @override
  void initState() {
    super.initState();
    _oldPasswordController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    _confirmPasswordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final String oldPassword = _oldPasswordController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirm = _confirmPasswordController.text.trim();

    final bool hasMinLength = password.length >= 8;
    final bool hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final bool hasDigit = RegExp(r'\d').hasMatch(password);
    final bool hasSpecial = RegExp(
      r'[!@#\$%^&*(),.?":{}|<>]',
    ).hasMatch(password);
    final bool notMatchPersonalInfo = !_containsPersonalInfo(password);
    final bool differentFromOld =
        oldPassword.isEmpty || oldPassword != password;

    String? oldPasswordError;
    if (widget.requireCurrentPassword && oldPassword.isEmpty) {
      oldPasswordError = _t(
        'Vui lòng nhập mật khẩu cũ',
        'Please enter old password',
      );
    }

    String? passwordError;
    if (password.isNotEmpty) {
      if (!hasMinLength || !hasUppercase || !hasDigit || !hasSpecial) {
        passwordError = _t(
          'Mật khẩu phải có ít nhất 8 ký tự, gồm chữ hoa, số và ký tự đặc biệt.',
          'Password must be at least 8 chars with uppercase, number and special char.',
        );
      } else if (widget.requireCurrentPassword && !differentFromOld) {
        passwordError = _t(
          'Mật khẩu mới không được trùng mật khẩu cũ.',
          'New password must be different from old password.',
        );
      } else if (!widget.requireCurrentPassword && !notMatchPersonalInfo) {
        passwordError = _t(
          'Mật khẩu không được trùng thông tin cá nhân.',
          'Password must not match personal information.',
        );
      }
    }

    String? confirmError;
    if (confirm.isNotEmpty && confirm != password) {
      confirmError = 'Mật khẩu nhập lại không khớp.';
    }

    if (!mounted) return;
    setState(() {
      _oldPasswordError = oldPasswordError;
      _hasMinLength = hasMinLength;
      _hasUppercase = hasUppercase;
      _hasDigit = hasDigit;
      _hasSpecial = hasSpecial;
      _notMatchPersonalInfo = notMatchPersonalInfo;
      _differentFromOld = differentFromOld;
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

  Future<String?> _resolveCurrentUserEmail(User user) async {
    final String? directEmail = user.email;
    if (directEmail != null && directEmail.isNotEmpty) {
      return directEmail;
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentSnapshot<Map<String, dynamic>> mainDoc = await firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final String authEmail = (mainDoc.data()?['authEmail'] ?? '').toString();
    if (authEmail.trim().isNotEmpty) {
      return authEmail.trim();
    }

    final String? fallbackDocId =
        UserFirestoreService.instance.currentUserDocId;
    if (fallbackDocId != null &&
        fallbackDocId.isNotEmpty &&
        fallbackDocId != user.uid) {
      final DocumentSnapshot<Map<String, dynamic>> fallbackDoc = await firestore
          .collection('users')
          .doc(fallbackDocId)
          .get();
      final String fallbackAuthEmail = (fallbackDoc.data()?['authEmail'] ?? '')
          .toString();
      if (fallbackAuthEmail.trim().isNotEmpty) {
        return fallbackAuthEmail.trim();
      }
    }

    return null;
  }

  bool _isConfigurationNotFound(FirebaseAuthException e) {
    final String code = e.code.toLowerCase();
    final String message = (e.message ?? '').toLowerCase();
    return code.contains('configuration-not-found') ||
        code.contains('configuration_not_found') ||
        message.contains('configuration-not-found') ||
        message.contains('configuration_not_found');
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _findUsersByPhone(
    String rawPhone,
  ) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final String raw = rawPhone.trim();
    final String normalized = raw.replaceAll(RegExp(r'\D'), '');

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> results = [];
    final Set<String> addedPaths = <String>{};

    Future<void> addByPhone(String value) async {
      if (value.isEmpty) {
        return;
      }
      final QuerySnapshot<Map<String, dynamic>> query = await firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: value)
          .get();
      for (final doc in query.docs) {
        if (addedPaths.add(doc.reference.path)) {
          results.add(doc);
        }
      }
    }

    await addByPhone(raw);
    if (normalized.isNotEmpty && normalized != raw) {
      await addByPhone(normalized);
    }

    return results;
  }

  Future<void> _syncPasswordToLinkedUserDocs({
    required String newPassword,
    String? authUid,
    String? authEmail,
    String? phoneNumber,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final Map<String, DocumentReference<Map<String, dynamic>>> refs = {};

    void addRef(DocumentReference<Map<String, dynamic>> ref) {
      refs[ref.path] = ref;
    }

    final String uid = (authUid ?? '').trim();
    final String email = (authEmail ?? '').trim();
    final String phone = (phoneNumber ?? '').trim();

    if (uid.isNotEmpty) {
      addRef(firestore.collection('users').doc(uid));
      final QuerySnapshot<Map<String, dynamic>> byUid = await firestore
          .collection('users')
          .where('authUid', isEqualTo: uid)
          .get();
      for (final doc in byUid.docs) {
        addRef(doc.reference);
      }
    }

    if (email.isNotEmpty) {
      final QuerySnapshot<Map<String, dynamic>> byEmail = await firestore
          .collection('users')
          .where('authEmail', isEqualTo: email)
          .get();
      for (final doc in byEmail.docs) {
        addRef(doc.reference);
      }
    }

    if (phone.isNotEmpty) {
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> byPhone =
          await _findUsersByPhone(phone);
      for (final doc in byPhone) {
        addRef(doc.reference);
      }
    }

    if (refs.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: _t(
          'Không tìm thấy hồ sơ người dùng để cập nhật mật khẩu.',
          'No user profile found to sync password.',
        ),
      );
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'password': newPassword,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (uid.isNotEmpty) {
      payload['authUid'] = uid;
    }
    if (email.isNotEmpty) {
      payload['authEmail'] = email;
    }

    for (final ref in refs.values) {
      await ref.set(payload, SetOptions(merge: true));
    }
  }

  Future<void> _handleSecureChangePassword() async {
    _validateForm();
    if (!_canSubmit) {
      return;
    }

    final String oldPassword = _oldPasswordController.text.trim();
    final String newPassword = _passwordController.text.trim();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final String? email = await _resolveCurrentUserEmail(user);
        if (email == null || email.isEmpty) {
          throw FirebaseAuthException(
            code: 'missing-email',
            message: _t(
              'Không thể xác định email tài khoản để xác thực lại.',
              'Cannot resolve account email for re-authentication.',
            ),
          );
        }

        final AuthCredential credential = EmailAuthProvider.credential(
          email: email,
          password: oldPassword,
        );

        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPassword);

        String linkedPhone = '';
        final DocumentSnapshot<Map<String, dynamic>> currentUserDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        linkedPhone = (currentUserDoc.data()?['phoneNumber'] ?? '').toString();

        await _syncPasswordToLinkedUserDocs(
          newPassword: newPassword,
          authUid: user.uid,
          authEmail: email,
          phoneNumber: linkedPhone,
        );

        await FirebaseAuth.instance.signOut();
      } else {
        final String? fallbackDocId =
            UserFirestoreService.instance.currentUserDocId;
        if (fallbackDocId == null || fallbackDocId.isEmpty) {
          throw FirebaseAuthException(
            code: 'missing-session',
            message: _t(
              'Không tìm thấy phiên đăng nhập. Vui lòng đăng nhập lại.',
              'No active session found. Please login again.',
            ),
          );
        }

        final DocumentSnapshot<Map<String, dynamic>> fallbackUserDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(fallbackDocId)
                .get();
        if (!fallbackUserDoc.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: _t(
              'Không tìm thấy hồ sơ tài khoản hiện tại.',
              'Current account profile was not found.',
            ),
          );
        }

        final Map<String, dynamic> fallbackData =
            fallbackUserDoc.data() ?? <String, dynamic>{};
        final String currentPassword = (fallbackData['password'] ?? '')
            .toString()
            .trim();
        if (currentPassword.isEmpty || currentPassword != oldPassword) {
          throw FirebaseAuthException(
            code: 'wrong-password',
            message: _t(
              'Mật khẩu cũ không đúng.',
              'Old password is incorrect.',
            ),
          );
        }

        await _syncPasswordToLinkedUserDocs(
          newPassword: newPassword,
          authUid: (fallbackData['authUid'] ?? '').toString().trim(),
          authEmail: (fallbackData['authEmail'] ?? '').toString().trim(),
          phoneNumber: (fallbackData['phoneNumber'] ?? '').toString().trim(),
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      String message;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = _t('Mật khẩu cũ không đúng.', 'Old password is incorrect.');
      } else if (e.code == 'missing-session') {
        message =
            e.message ??
            _t(
              'Không tìm thấy phiên đăng nhập. Vui lòng đăng nhập lại.',
              'No active session found. Please login again.',
            );
      } else if (e.code == 'weak-password') {
        message = _t(
          'Mật khẩu mới quá yếu, vui lòng đặt mật khẩu mạnh hơn.',
          'New password is too weak.',
        );
      } else {
        message =
            e.message ??
            _t('Đổi mật khẩu thất bại.', 'Failed to change password.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ??
                _t(
                  'Không thể đồng bộ dữ liệu Firestore.',
                  'Firestore sync failed.',
                ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Đã xảy ra lỗi không xác định. Vui lòng thử lại.',
              'Unexpected error occurred. Please try again.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleForgotPasswordReset() async {
    _validateForm();
    if (!_canSubmit) {
      return;
    }

    final String phone = (widget.phoneNumber ?? '').trim();
    final String newPassword = _passwordController.text.trim();

    if (phone.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Thiếu số điện thoại để đặt lại mật khẩu.',
              'Phone number is required to reset password.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> usersByPhone =
          await _findUsersByPhone(phone);
      if (usersByPhone.isEmpty) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: _t(
            'Không tìm thấy tài khoản cho số điện thoại này.',
            'No account found for this phone number.',
          ),
        );
      }

      final Map<String, dynamic> primaryData = usersByPhone.first.data();
      String authEmail = (primaryData['authEmail'] ?? '').toString().trim();
      String authUid = (primaryData['authUid'] ?? '').toString().trim();
      final String currentPassword = (primaryData['password'] ?? '')
          .toString()
          .trim();

      if (authEmail.isNotEmpty && currentPassword.isNotEmpty) {
        try {
          final UserCredential credential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(
                email: authEmail,
                password: currentPassword,
              );
          await credential.user?.updatePassword(newPassword);
          authUid = credential.user?.uid ?? authUid;
          authEmail = credential.user?.email ?? authEmail;
          await FirebaseAuth.instance.signOut();
        } on FirebaseAuthException catch (e) {
          if (!_isConfigurationNotFound(e)) {
            rethrow;
          }
        }
      }

      await _syncPasswordToLinkedUserDocs(
        newPassword: newPassword,
        authUid: authUid,
        authEmail: authEmail,
        phoneNumber: phone,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Đổi mật khẩu thành công.', 'Password changed successfully.'),
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) {
          return;
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      String message;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = _t(
          'Không thể xác thực tài khoản để đổi mật khẩu. Vui lòng thử lại.',
          'Cannot re-authenticate account for password reset. Please try again.',
        );
      } else {
        message =
            e.message ??
            _t('Đổi mật khẩu thất bại.', 'Failed to change password.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ??
                _t(
                  'Không thể cập nhật mật khẩu trong Firestore.',
                  'Failed to update password in Firestore.',
                ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Đã xảy ra lỗi không xác định. Vui lòng thử lại.',
              'Unexpected error occurred. Please try again.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (widget.requireCurrentPassword) {
      await _handleSecureChangePassword();
      return;
    }
    await _handleForgotPasswordReset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: CCPAppBar(
        title: widget.requireCurrentPassword
            ? _t('Đổi mật khẩu', 'Change password')
            : _t('Quên mật khẩu', 'Forgot password'),
        backgroundColor: const Color(0xFFF8F9FE),
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

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
                      if (widget.requireCurrentPassword) ...[
                        _buildPasswordField(
                          label: _t('Mật khẩu cũ', 'Old password'),
                          controller: _oldPasswordController,
                          isHidden: !_showOld,
                          onToggle: () => setState(() => _showOld = !_showOld),
                          errorText: _oldPasswordError,
                        ),
                        const SizedBox(height: 20),
                      ],
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
                        widget.requireCurrentPassword
                            ? 'Không trùng mật khẩu cũ'
                            : 'Không trùng thông tin cá nhân',
                        widget.requireCurrentPassword
                            ? _differentFromOld
                            : _notMatchPersonalInfo,
                      ),
                      const SizedBox(height: 20),
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
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.requireCurrentPassword
                                ? _t(
                                    'Xác nhận đổi mật khẩu',
                                    'Confirm password change',
                                  )
                                : _t('Đổi mật khẩu', 'Change password'),
                            style: const TextStyle(
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
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
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
                color: Colors.grey.shade600,
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
