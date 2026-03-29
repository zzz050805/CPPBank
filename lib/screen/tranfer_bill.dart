import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import 'main_tab_shell.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(textTheme: GoogleFonts.poppinsTextTheme()),
      home: const SuccessTransactionScreen(),
    );
  }
}

class SuccessTransactionScreen extends StatefulWidget {
  const SuccessTransactionScreen({super.key});

  @override
  State<SuccessTransactionScreen> createState() =>
      _SuccessTransactionScreenState();
}

class _SuccessTransactionScreenState extends State<SuccessTransactionScreen> {
  Timer? _redirectTimer;
  bool _redirected = false;

  static const Color primaryBlue = Color(0xFF000DC0);
  static const Color pageBackground = Color(0xFFF6F8FF);

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _redirectTimer = Timer(const Duration(seconds: 3), _goHome);
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  void _goHome() {
    if (!mounted || _redirected) {
      return;
    }
    _redirected = true;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainTabShell(initialIndex: 0)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B29CA), Color(0xFF000DC0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000DC0),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _t(
                              'Bạn đã chuyển tiền thành công',
                              'Transfer completed successfully',
                            ),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '1.000.000 VND',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _t('Một triệu đồng', 'One million dong'),
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<UserProfileData?>(
                      stream: UserFirestoreService.instance
                          .currentUserProfileStream(),
                      initialData: UserFirestoreService.instance.latestProfile,
                      builder: (context, snapshot) {
                        final UserProfileData? profile =
                            snapshot.data ??
                            UserFirestoreService.instance.latestProfile;
                        final String senderName = snapshot.hasError
                            ? _t('Không tìm thấy user', 'User not found')
                            : ((profile?.fullname.isNotEmpty == true)
                                  ? profile!.fullname
                                  : _t('Khách hàng', 'Customer'));

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              _buildInfoRow(
                                _t('Từ', 'From'),
                                '${senderName.toUpperCase()}\n****** 456',
                              ),
                              const Divider(height: 18),
                              _buildInfoRow(
                                _t('Đến', 'To'),
                                'TRAN THANH B\nMC-BANK\n312 555 867',
                              ),
                              const Divider(height: 18),
                              _buildInfoRow(
                                _t('Chuyển lúc', 'Transferred at'),
                                '12/12/2025 , 10:10:21',
                              ),
                              const Divider(height: 18),
                              _buildInfoRow(
                                _t('Phí', 'Fee'),
                                _t('Miễn phí', 'Free'),
                              ),
                              const Divider(height: 18),
                              _buildInfoRow(
                                _t('Mã giao dịch', 'Transaction ID'),
                                '3421',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<UserProfileData?>(
                      stream: UserFirestoreService.instance
                          .currentUserProfileStream(),
                      initialData: UserFirestoreService.instance.latestProfile,
                      builder: (context, snapshot) {
                        final UserProfileData? profile =
                            snapshot.data ??
                            UserFirestoreService.instance.latestProfile;
                        final String senderName = snapshot.hasError
                            ? _t('Không tìm thấy user', 'User not found')
                            : ((profile?.fullname.isNotEmpty == true)
                                  ? profile!.fullname
                                  : _t('Khách hàng', 'Customer'));

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('Nội dung', 'Content'),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF8A91A6),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${senderName.toUpperCase()} ${_t('CHUYỂN TIỀN', 'TRANSFER')}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: const Color(0xFF23283A),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _goHome,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFEFF2FB),
                          side: const BorderSide(color: Color(0xFFDDE3F1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _t('Đóng', 'Close'),
                          style: GoogleFonts.poppins(
                            color: primaryBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _goHome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _t('Gửi', 'Send'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: const Color(0xFF8A91A6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: const Color(0xFF24293A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
