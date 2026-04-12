import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/admin_firestore_setup_service.dart';
import '../data/user_firestore_service.dart';
import '../services/home_cache_service.dart';
import 'forget_password.dart';
import 'main_tab_shell.dart';
import 'register.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _adminLoginCccd = '00000000';
  static const String _adminLoginPassword = 'Admin@1234';

  final TextEditingController _cccdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoginEnabled = false;
  bool _isLoading = false;
  bool _hasNavigated = false;
  String? _cccdError;
  String? _passwordError;

  String _t(String vi, String en) => vi;

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _navigateOnce(Widget page) {
    if (!mounted || _hasNavigated) {
      return;
    }
    _hasNavigated = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (Route<dynamic> route) => false,
    );
  }

  Future<bool> _tryAdminLoginFromAdminCollection({
    required String inputAccount,
    required String inputPass,
  }) async {
    if (_digitsOnly(inputAccount) != _adminLoginCccd) {
      return false;
    }

    await AdminFirestoreSetupService.instance.ensureAdminSeed();

    final DocumentSnapshot<Map<String, dynamic>> adminSnapshot =
        await FirebaseFirestore.instance
            .collection('admin')
            .doc('settings')
            .get();
    final Map<String, dynamic> data =
        adminSnapshot.data() ?? <String, dynamic>{};

    final String storedCccd = _digitsOnly(
      (data['cccd'] ?? '').toString().trim(),
    );
    final String storedPhone = _digitsOnly(
      (data['phoneNumber'] ?? '').toString().trim(),
    );
    final String storedPassword = (data['password'] ?? _adminLoginPassword)
        .toString();

    final bool accountMatched =
        _digitsOnly(inputAccount) == storedCccd ||
        _digitsOnly(inputAccount) == storedPhone;

    if (accountMatched && inputPass == storedPassword) {
      if (!mounted) {
        return true;
      }
      _navigateOnce(const AdminDashboardScreen());
      return true;
    }

    if (!mounted) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(
            'Tài khoản hoặc mật khẩu không chính xác!',
            'Incorrect account or password!',
          ),
        ),
        backgroundColor: Colors.red,
      ),
    );
    return true;
  }

  @override
  void initState() {
    super.initState();
    _cccdController.addListener(_checkInput);
    _passwordController.addListener(_checkInput);
  }

  void _checkInput() {
    setState(() {
      _isLoginEnabled =
          _cccdController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty;

      if (_cccdController.text.isNotEmpty) {
        _cccdError = null;
      }
      if (_passwordController.text.isNotEmpty) {
        _passwordError = null;
      }
    });
  }

  Future<void> _prefetchHomeCache({
    required String docId,
    String? fallbackName,
  }) async {
    await HomeCacheService.instance.preloadForUser(
      userId: docId,
      fallbackName: fallbackName,
    );
    HomeCacheService.instance.startRealtimeSync(docId);
  }

  Future<void> _routeAfterLogin({
    required String docId,
    required Map<String, dynamic> profileData,
    required String loginAccount,
  }) async {
    final AdminUserAccessInfo accessInfo = await AdminFirestoreSetupService
        .instance
        .ensureRoleAndSeed(userId: docId, fallbackAccount: loginAccount);

    if (!mounted) {
      return;
    }

    if (accessInfo.isLocked && accessInfo.role != 'admin') {
      await FirebaseAuth.instance.signOut();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Tài khoản đang bị khóa.', 'Your account is locked.'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    unawaited(
      _prefetchHomeCache(
        docId: docId,
        fallbackName: (profileData['fullname'] ?? profileData['fullName'] ?? '')
            .toString(),
      ),
    );

    if (!mounted) {
      return;
    }

    _navigateOnce(const MainTabShell());
  }

  // --- HÀM XỬ LÝ ĐĂNG NHẬP: ĐÃ SỬA ĐỂ NHẬN CẢ SĐT VÀ CCCD ---
  void _handleLogin() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      if (_cccdController.text.isEmpty) {
        _cccdError = _t(
          'Bạn cần nhập số điện thoại/CCCD',
          'Please enter phone number/ID card',
        );
      }
      if (_passwordController.text.isEmpty) {
        _passwordError = _t('Bạn cần nhập mật khẩu', 'Please enter password');
      }
    });

    if (!_isLoginEnabled) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasNavigated = false;
    });

    bool isConfigurationNotFound(FirebaseAuthException e) {
      final String code = e.code.toLowerCase();
      final String message = (e.message ?? '').toLowerCase();
      return code.contains('configuration-not-found') ||
          code.contains('configuration_not_found') ||
          message.contains('configuration_not_found') ||
          message.contains('configuration-not-found');
    }

    bool loadingShown = false;

    void closeLoadingDialog() {
      if (!loadingShown || !mounted) return;
      final NavigatorState navigator = Navigator.of(
        context,
        rootNavigator: true,
      );
      if (navigator.canPop()) {
        navigator.pop();
      }
      loadingShown = false;
    }

    QueryDocumentSnapshot<Map<String, dynamic>>? foundLegacyDoc;
    try {
      final String inputAccount = _cccdController.text.trim();
      final String inputPass = _passwordController.text.trim();

      if (await _tryAdminLoginFromAdminCollection(
        inputAccount: inputAccount,
        inputPass: inputPass,
      )) {
        return;
      }

      final QuerySnapshot<Map<String, dynamic>> userQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .where(
                Filter.or(
                  Filter('phoneNumber', isEqualTo: inputAccount),
                  Filter('cccd', isEqualTo: inputAccount),
                ),
              )
              .limit(1)
              .get();

      if (userQuery.docs.isEmpty) {
        if (!mounted) return;
        closeLoadingDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Tài khoản hoặc mật khẩu không chính xác!',
                'Incorrect account or password!',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final QueryDocumentSnapshot<Map<String, dynamic>> legacyDoc =
          userQuery.docs.first;
      foundLegacyDoc = legacyDoc;
      final Map<String, dynamic> data = legacyDoc.data();
      final String authEmailRaw = (data['authEmail'] ?? '').toString().trim();
      final String storedLegacyPassword = (data['password'] ?? '')
          .toString()
          .trim();
      final String phone = (data['phoneNumber'] ?? inputAccount).toString();
      final String normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');
      final String generatedEmail = normalizedPhone.isEmpty
          ? 'cppbank_${legacyDoc.id}@cppbank.local'
          : 'cppbank_$normalizedPhone@cppbank.local';

      UserCredential credential;

      if (authEmailRaw.isEmpty) {
        // Always prefer Firebase Auth sign-in first to use the latest password.
        try {
          credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: generatedEmail,
            password: inputPass,
          );
          final String uid = credential.user!.uid;
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            ...data,
            'fullname': (data['fullname'] ?? data['fullName'] ?? '').toString(),
            'fullName': (data['fullName'] ?? data['fullname'] ?? '').toString(),
            'authEmail': generatedEmail,
            'email': (data['email'] ?? generatedEmail).toString(),
            'authUid': uid,
            'lastLoginAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await legacyDoc.reference.set({
            'authEmail': generatedEmail,
            'authUid': uid,
            'lastLoginAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await UserFirestoreService.instance.syncCurrentUserData(
            docIdOverride: uid,
          );
        } on FirebaseAuthException catch (e) {
          if (isConfigurationNotFound(e)) {
            if (storedLegacyPassword != inputPass) {
              if (!mounted) return;
              closeLoadingDialog();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _t(
                      'Tài khoản hoặc mật khẩu không chính xác!',
                      'Incorrect account or password!',
                    ),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            UserFirestoreService.instance.setFallbackDocId(legacyDoc.id);
            await legacyDoc.reference.set({
              'lastLoginAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            await UserFirestoreService.instance.syncCurrentUserData(
              docIdOverride: legacyDoc.id,
            );
            if (!mounted) return;
            closeLoadingDialog();
            await _routeAfterLogin(
              docId: legacyDoc.id,
              profileData: data,
              loginAccount: inputAccount,
            );
            return;
          }

          final bool shouldFallbackToLegacy =
              e.code == 'user-not-found' || e.code == 'invalid-email';

          if (!shouldFallbackToLegacy) {
            rethrow;
          }

          // Legacy fallback: authenticate with stored Firestore password then migrate.
          if (storedLegacyPassword != inputPass) {
            if (!mounted) return;
            closeLoadingDialog();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _t(
                    'Tài khoản hoặc mật khẩu không chính xác!',
                    'Incorrect account or password!',
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          try {
            credential = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                  email: generatedEmail,
                  password: inputPass,
                );
          } on FirebaseAuthException catch (createError) {
            if (isConfigurationNotFound(createError)) {
              if (storedLegacyPassword != inputPass) {
                if (!mounted) return;
                closeLoadingDialog();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _t(
                        'Tài khoản hoặc mật khẩu không chính xác!',
                        'Incorrect account or password!',
                      ),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              UserFirestoreService.instance.setFallbackDocId(legacyDoc.id);
              await legacyDoc.reference.set({
                'lastLoginAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              await UserFirestoreService.instance.syncCurrentUserData(
                docIdOverride: legacyDoc.id,
              );
              if (!mounted) return;
              closeLoadingDialog();
              await _routeAfterLogin(
                docId: legacyDoc.id,
                profileData: data,
                loginAccount: inputAccount,
              );
              return;
            }
            if (createError.code == 'email-already-in-use') {
              credential = await FirebaseAuth.instance
                  .signInWithEmailAndPassword(
                    email: generatedEmail,
                    password: inputPass,
                  );
            } else {
              rethrow;
            }
          }

          final String uid = credential.user!.uid;
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            ...data,
            'fullname': (data['fullname'] ?? data['fullName'] ?? '').toString(),
            'fullName': (data['fullName'] ?? data['fullname'] ?? '').toString(),
            'authEmail': generatedEmail,
            'email': (data['email'] ?? generatedEmail).toString(),
            'authUid': uid,
            'migratedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await legacyDoc.reference.set({
            'authEmail': generatedEmail,
            'authUid': uid,
          }, SetOptions(merge: true));
          await UserFirestoreService.instance.syncCurrentUserData(
            docIdOverride: uid,
          );
        }
      } else {
        try {
          credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: authEmailRaw,
            password: inputPass,
          );
        } on FirebaseAuthException catch (e) {
          if (isConfigurationNotFound(e)) {
            if (storedLegacyPassword != inputPass) {
              if (!mounted) return;
              closeLoadingDialog();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _t(
                      'Tài khoản hoặc mật khẩu không chính xác!',
                      'Incorrect account or password!',
                    ),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            UserFirestoreService.instance.setFallbackDocId(legacyDoc.id);
            await legacyDoc.reference.set({
              'lastLoginAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            await UserFirestoreService.instance.syncCurrentUserData(
              docIdOverride: legacyDoc.id,
            );
            if (!mounted) return;
            closeLoadingDialog();
            await _routeAfterLogin(
              docId: legacyDoc.id,
              profileData: data,
              loginAccount: inputAccount,
            );
            return;
          }
          rethrow;
        }

        final String uid = credential.user!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fullname': (data['fullname'] ?? data['fullName'] ?? '').toString(),
          'fullName': (data['fullName'] ?? data['fullname'] ?? '').toString(),
          'authEmail': authEmailRaw,
          'email': (data['email'] ?? authEmailRaw).toString(),
          'authUid': uid,
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await UserFirestoreService.instance.syncCurrentUserData(
          docIdOverride: uid,
        );
      }

      if (!mounted) return;
      closeLoadingDialog();
      final String finalDocId =
          UserFirestoreService.instance.currentUserDocId ??
          FirebaseAuth.instance.currentUser?.uid ??
          legacyDoc.id;
      await _routeAfterLogin(
        docId: finalDocId,
        profileData: data,
        loginAccount: inputAccount,
      );
    } on FirebaseAuthException catch (e) {
      if (isConfigurationNotFound(e) && foundLegacyDoc != null) {
        final Map<String, dynamic> fallbackData = foundLegacyDoc.data();
        final String fallbackStoredPassword = (fallbackData['password'] ?? '')
            .toString()
            .trim();
        final String inputPassword = _passwordController.text.trim();

        if (fallbackStoredPassword != inputPassword) {
          if (!mounted) return;
          closeLoadingDialog();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _t(
                  'Tài khoản hoặc mật khẩu không chính xác!',
                  'Incorrect account or password!',
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        UserFirestoreService.instance.setFallbackDocId(foundLegacyDoc.id);
        await foundLegacyDoc.reference.set({
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await UserFirestoreService.instance.syncCurrentUserData(
          docIdOverride: foundLegacyDoc.id,
        );

        if (!mounted) return;
        closeLoadingDialog();
        await _routeAfterLogin(
          docId: foundLegacyDoc.id,
          profileData: fallbackData,
          loginAccount: _cccdController.text.trim(),
        );
        return;
      }

      if (!mounted) return;
      closeLoadingDialog();
      final String message =
          (e.code == 'wrong-password' ||
              e.code == 'invalid-credential' ||
              e.code == 'user-not-found')
          ? _t(
              'Tài khoản hoặc mật khẩu không chính xác!',
              'Incorrect account or password!',
            )
          : '${_t('Lỗi đăng nhập', 'Login error')}: ${e.message ?? e.code}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      closeLoadingDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_t('Lỗi hệ thống', 'System error')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      closeLoadingDialog();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (BuildContext context) {
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF52D5BA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _t('Xác thực xong', 'Authenticated'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF343434),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _cccdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000DC0),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(children: []),
            ),
            const SizedBox(height: 80),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 48,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('Chào bạn!', 'Welcome!'),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF000DC0),
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _t(
                                  'Thuận tiện hơn khi vay qua App',
                                  'A more convenient way to borrow via the app',
                                ),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF343434),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 15),

                              Center(
                                child: Transform.scale(
                                  scale: 1.1,
                                  child: _buildLockIllustration(),
                                ),
                              ),
                              const SizedBox(height: 20),

                              _buildTextField(
                                _t(
                                  'Số điện thoại/CCCD',
                                  'Phone number/ID card',
                                ),
                                controller: _cccdController,
                                errorText: _cccdError,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(20),
                                ],
                              ),
                              const SizedBox(height: 16),

                              _buildTextField(
                                _t('Mật khẩu', 'Password'),
                                controller: _passwordController,
                                errorText: _passwordError,
                                isObscured: true,
                                keyboardType: TextInputType.visiblePassword,
                                textInputAction: TextInputAction.done,
                              ),

                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      _t('Quên mật khẩu ?', 'Forgot password?'),
                                      style: GoogleFonts.poppins(
                                        color: const Color.fromARGB(
                                          255,
                                          68,
                                          67,
                                          67,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              Center(
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          (_isLoginEnabled && !_isLoading)
                                          ? const Color(0xFF000DC0)
                                          : const Color(0xFFF2F4FB),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: (_isLoginEnabled && !_isLoading)
                                        ? _handleLogin
                                        : null,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            _t('ĐĂNG NHẬP', 'LOG IN'),
                                            style: GoogleFonts.poppins(
                                              color: _isLoginEnabled
                                                  ? Colors.white
                                                  : const Color(0xFF000DC0),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              Center(
                                child: IconButton(
                                  iconSize: 60,
                                  icon: const Icon(
                                    Icons.fingerprint,
                                    color: Color(0xFF5655B9),
                                  ),
                                  onPressed: () {
                                    _showSuccessPopup(context);
                                  },
                                ),
                              ),

                              const Spacer(),

                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: RichText(
                                    text: TextSpan(
                                      text: _t(
                                        'Bạn chưa có tài khoản? ',
                                        'Do not have an account? ',
                                      ),
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF343434),
                                        fontSize: 14,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _t('Đăng ký', 'Register'),
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
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hintText, {
    bool isObscured = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextEditingController? controller,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscured,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        errorStyle: GoogleFonts.poppins(color: Colors.red, fontSize: 12),
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFFCBCBCB),
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBCBCB), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF000DC0), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildLockIllustration() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFE5E2FF),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 45,
            height: 55,
            decoration: BoxDecoration(
              color: const Color(0xFF5655B9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lock_outline,
              color: Colors.white,
              size: 28,
            ),
          ),
          Positioned(
            top: 15,
            left: 35,
            child: _buildDot(const Color(0xFF281C9D), 6),
          ),
          Positioned(
            top: 30,
            right: 20,
            child: _buildDot(const Color(0xFFFF4267), 10),
          ),
          Positioned(
            bottom: 25,
            left: 15,
            child: _buildDot(const Color(0xFFFFA600), 8),
          ),
          Positioned(
            left: 10,
            top: 60,
            child: _buildDot(const Color(0xFF52D5BA), 5),
          ),
          Positioned(
            bottom: 45,
            right: 25,
            child: _buildDot(const Color(0xFF0890FE), 5),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
