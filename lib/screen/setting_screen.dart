import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_preferences.dart';
import '../data/user_firestore_service.dart';
import '../effect/gentle_page_route.dart';
import '../l10n/app_text.dart';
import '../services/help_center_web_server.dart';
import 'user_info_screen.dart';
import 'search_screen.dart';
import 'home_screen.dart';
import 'chat_placeholder_screen.dart';
import 'enter_new_password.dart';
import 'login.dart';
import 'smart_otp_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key, this.showBottomNav = true});

  final bool showBottomNav;

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final int _selectedIndex = 3;
  bool _isDarkMode = false; // Chức năng Dark Mode

  String _t(String vi, String en) => AppText.tr(context, vi, en);
  String _logoutT(String vi, String en) => vi;

  String get _languageLabel {
    return AppPreferences.instance.locale.languageCode == 'en'
        ? 'English'
        : 'Tiếng Việt';
  }

  // --- HỆ THỐNG MÀU SẮC THEO THEME ---
  Color get _primaryBlue => const Color(0xFF000DC0);
  Color get _bg =>
      _isDarkMode ? const Color(0xFF0B0B0F) : const Color(0xFFF8F9FE);
  Color get _cardColor => _isDarkMode ? const Color(0xFF1A1A23) : Colors.white;
  Color get _textColor => _isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
  Color get _subTextColor => _isDarkMode ? Colors.white60 : Colors.grey;

  _MembershipRankData getMembershipRank(double totalBalance) {
    if (totalBalance > 10000000000) {
      return const _MembershipRankData(
        name: 'HẠNG KING',
        color: Color(0xFF1B0E2D),
        gradient: [Color(0xFF0C0818), Color.fromARGB(255, 214, 222, 46)],
        icon: Icons.all_inclusive,
      );
    }
    if (totalBalance > 2000000000) {
      return const _MembershipRankData(
        name: 'HẠNG ROYAL',
        color: Color(0xFFC7193E),
        gradient: [Color(0xFF880D2F), Color.fromARGB(255, 206, 206, 83)],
        icon: Icons.local_fire_department_outlined,
      );
    }
    if (totalBalance > 500000000) {
      return const _MembershipRankData(
        name: 'HẠNG KIM CƯƠNG',
        color: Color.fromARGB(255, 243, 248, 255),
        gradient: [
          Color.fromARGB(255, 100, 151, 247),
          Color.fromARGB(255, 83, 198, 255),
        ],
        icon: Icons.workspace_premium_outlined,
      );
    }
    if (totalBalance > 100000000) {
      return const _MembershipRankData(
        name: 'HẠNG BẠCH KIM',
        color: Color.fromARGB(255, 20, 161, 60),
        gradient: [Color.fromARGB(255, 88, 239, 134), Color(0xFF45C8FF)],
        icon: Icons.diamond_outlined,
      );
    }
    if (totalBalance > 50000000) {
      return const _MembershipRankData(
        name: 'HẠNG VÀNG',
        color: Color(0xFFE5B93C),
        gradient: [Color(0xFFB38719), Color(0xFFF6D365)],
        icon: Icons.emoji_events_outlined,
      );
    }
    if (totalBalance > 5000000) {
      return const _MembershipRankData(
        name: 'HẠNG BẠC',
        color: Color(0xFFA8B1C2),
        gradient: [Color(0xFF8D97AA), Color(0xFFC9D0DE)],
        icon: Icons.military_tech_outlined,
      );
    }

    return const _MembershipRankData(
      name: 'THÀNH VIÊN',
      color: Color(0xFF8D8D95),
      gradient: [Color(0xFF7A7A82), Color(0xFFACACB6)],
      icon: Icons.person_outline,
    );
  }

  Color formatRankColor(String colorCode) {
    String hex = colorCode.trim().replaceAll('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((e) => '$e$e').join();
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    final int? value = int.tryParse(hex, radix: 16);
    if (value == null) return const Color(0xFF8D8D95);
    return Color(value);
  }

  _MembershipRankData _resolveRankFromFirestore({
    required Map<String, dynamic> userData,
    required double totalBalance,
  }) {
    final _MembershipRankData autoRank = getMembershipRank(totalBalance);
    final String manualRank = (userData['manualRank'] ?? '').toString().trim();
    final String manualRankColor = (userData['manualRankColor'] ?? '')
        .toString()
        .trim();

    if (manualRank.isEmpty) {
      return autoRank;
    }

    final Color baseColor = manualRankColor.isEmpty
        ? autoRank.color
        : formatRankColor(manualRankColor);
    final HSLColor hsl = HSLColor.fromColor(baseColor);

    return _MembershipRankData(
      name: manualRank.toUpperCase(),
      color: baseColor,
      gradient: [
        hsl
            .withLightness((hsl.lightness - 0.12).clamp(0, 1).toDouble())
            .toColor(),
        hsl
            .withLightness((hsl.lightness + 0.12).clamp(0, 1).toDouble())
            .toColor(),
      ],
      icon: _resolveRankIcon(manualRank),
    );
  }

  IconData _resolveRankIcon(String rankName) {
    final String normalized = rankName.toLowerCase();
    if (normalized.contains('king') || normalized.contains('king')) {
      return Icons.all_inclusive;
    }
    if (normalized.contains('royal') || normalized.contains('royal')) {
      return Icons.local_fire_department_outlined;
    }
    if (normalized.contains('kim cương') || normalized.contains('diamond')) {
      return Icons.workspace_premium_outlined;
    }
    if (normalized.contains('bạch kim') || normalized.contains('platinum')) {
      return Icons.diamond_outlined;
    }
    if (normalized.contains('vàng') || normalized.contains('gold')) {
      return Icons.emoji_events_outlined;
    }
    if (normalized.contains('bạc') || normalized.contains('silver')) {
      return Icons.military_tech_outlined;
    }
    return Icons.person_outline;
  }

  String _localizedRankName(String rawName) {
    final String normalized = rawName.trim().toLowerCase();
    if (normalized.isEmpty) return rawName;

    if (normalized.contains('king')) {
      return _t('HẠNG KING', 'KING');
    }
    if (normalized.contains('royal')) {
      return _t('HẠNG ROYAL', 'ROYAL');
    }
    if (normalized.contains('kim cương') || normalized.contains('diamond')) {
      return _t('HẠNG KIM CƯƠNG', 'DIAMOND');
    }
    if (normalized.contains('bạch kim') || normalized.contains('platinum')) {
      return _t('HẠNG BẠCH KIM', 'PLATINUM');
    }
    if (normalized.contains('vàng') || normalized.contains('gold')) {
      return _t('HẠNG VÀNG', 'GOLD');
    }
    if (normalized.contains('bạc') || normalized.contains('silver')) {
      return _t('HẠNG BẠC', 'SILVER');
    }
    if (normalized.contains('thành viên') || normalized.contains('member')) {
      return _t('THÀNH VIÊN', 'MEMBER');
    }
    return rawName.toUpperCase();
  }

  double _readBalance(dynamic rawBalance) {
    if (rawBalance is num) return rawBalance.toDouble();
    if (rawBalance is String) {
      final String trimmed = rawBalance.trim();
      if (trimmed.isEmpty) return 0;

      final double? direct = double.tryParse(trimmed);
      if (direct != null) return direct;

      final String digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      return double.tryParse(digitsOnly) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. HEADER GRADIENT XỊN
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: _primaryBlue,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_primaryBlue, const Color(0xFF000766)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60, left: 25),
                      child: Row(
                        children: [
                          _buildAvatar(),
                          const SizedBox(width: 15),
                          _buildUserInfo(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. DANH SÁCH CÀI ĐẶT
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                        _t("GIAO DIỆN & TIỆN ÍCH", "DISPLAY & UTILITIES"),
                      ),
                      _buildSettingsGroup([
                        _buildToggleItem(
                          Icons.dark_mode_outlined,
                          _t("Chế độ tối", "Dark mode"),
                          _isDarkMode,
                          (v) {
                            setState(() => _isDarkMode = v);
                          },
                        ),
                        _buildSettingItem(
                          Icons.language_outlined,
                          _t("Ngôn ngữ", "Language"),
                          trailingText: _languageLabel,
                          onTap: _showLanguagePicker,
                        ),
                      ]),

                      const SizedBox(height: 25),
                      _sectionTitle(_t("BẢO MẬT", "SECURITY")),
                      _buildSettingsGroup([
                        _buildSettingItem(
                          Icons.key_outlined,
                          _t("Quản lý Smart OTP", "Manage Smart OTP"),
                          onTap: () {
                            final String? uid =
                                UserFirestoreService.instance.currentUserDocId;
                            if (uid == null || uid.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _t(
                                      'Không tìm thấy tài khoản để mở Smart OTP.',
                                      'Account not found to open Smart OTP.',
                                    ),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              GentlePageRoute<void>(
                                page: SmartOTPScreen(
                                  uid: uid,
                                  isManagementMode: true,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildSettingItem(
                          Icons.devices_outlined,
                          _t("Thiết bị tin cậy", "Trusted devices"),
                        ),
                        _buildSettingItem(
                          Icons.lock_outline,
                          _t("Đổi mật khẩu", "Change password"),
                          onTap: () {
                            Navigator.push(
                              context,
                              GentlePageRoute<void>(
                                page: const ResetPasswordPage(
                                  requireCurrentPassword: true,
                                ),
                              ),
                            );
                          },
                        ),
                      ]),

                      const SizedBox(height: 25),
                      _sectionTitle(_t("THÔNG TIN", "INFORMATION")),
                      _buildSettingsGroup([
                        _buildSettingItem(
                          Icons.assignment_ind_outlined,
                          _t("Thông tin cá nhân", "Personal information"),
                          onTap: () {
                            Navigator.push(
                              context,
                              GentlePageRoute<void>(
                                page: const UserInfoScreen(),
                              ),
                            );
                          },
                        ),
                        _buildSettingItem(
                          Icons.info_outline,
                          _t("Về ứng dụng", "About app"),
                          trailingText: "v2.0.4",
                        ),
                        _buildSettingItem(
                          Icons.help_outline,
                          _t("Trung tâm trợ giúp", "Help center"),
                          onTap: _openHelpCenterInBrowser,
                        ),
                      ]),

                      const SizedBox(height: 30),
                      _buildLogoutButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. BOTTOM NAV (KHỚP 100% VỚI CÁC TRANG TRƯỚC)
          if (widget.showBottomNav) _buildPillBottomNav(),
        ],
      ),
    );
  }

  // --- WIDGET PHỤ TRỢ ---

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 26,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      child: const Icon(Icons.person, color: Colors.white, size: 32),
    );
  }

  Widget _buildUserInfo() {
    final String? userId = UserFirestoreService.instance.currentUserDocId;

    if (userId == null || userId.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('KHÁCH HÀNG', 'CUSTOMER'),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          _buildRankBadge(
            const _MembershipRankData(
              name: 'THÀNH VIÊN',
              color: Color(0xFF8D8D95),
              gradient: [Color(0xFF7A7A82), Color(0xFFACACB6)],
              icon: Icons.person_outline,
            ),
          ),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, userSnapshot) {
        final Map<String, dynamic> userData =
            userSnapshot.data?.data() ?? <String, dynamic>{};
        final String fullname =
            (userData['fullname'] ?? userData['fullName'] ?? '')
                .toString()
                .trim();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('cards')
              .snapshots(includeMetadataChanges: true),
          builder: (context, cardsSnapshot) {
            double standardBalance = 0;
            double vipBalance = 0;
            bool hasCardData = false;

            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in cardsSnapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
              final String cardId = doc.id.toLowerCase();
              final double balance = _readBalance(doc.data()['balance']);
              if (cardId == 'standard') {
                standardBalance = balance;
                hasCardData = true;
              } else if (cardId == 'vip') {
                vipBalance = balance;
                hasCardData = true;
              }
            }

            final dynamic rawNormal =
                userData['balance_normal'] ??
                userData['standardBalance'] ??
                userData['balanceNormal'];
            final dynamic rawVip =
                userData['balance_vip'] ??
                userData['vipBalance'] ??
                userData['balanceVip'];
            final bool hasSplitBalance = rawNormal != null || rawVip != null;
            final double fallbackTotal = hasSplitBalance
                ? _readBalance(rawNormal) + _readBalance(rawVip)
                : _readBalance(
                    userData['balance'] ??
                        userData['totalBalance'] ??
                        userData['availableBalance'],
                  );

            final double totalBalance = hasCardData
                ? standardBalance + vipBalance
                : fallbackTotal;

            final _MembershipRankData rank = _resolveRankFromFirestore(
              userData: userData,
              totalBalance: totalBalance,
            );

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (fullname.isEmpty ? _t('Khách hàng', 'Customer') : fullname)
                      .toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                _buildRankBadge(rank),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRankBadge(_MembershipRankData rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: rank.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: rank.color.withOpacity(0.38),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(rank.icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            _localizedRankName(rank.name).toUpperCase(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: _subTextColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title, {
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: _primaryBlue, size: 22),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: _textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: TextStyle(color: _subTextColor, fontSize: 13),
            ),
          Icon(Icons.chevron_right, color: _subTextColor, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  Future<void> _openHelpCenterInBrowser() async {
    final Uri uri = await HelpCenterWebServer.instance.ensureStarted();
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở Trung tâm trợ giúp.')),
      );
    }
  }

  Future<void> _showLanguagePicker() async {
    final Locale? selected = await showModalBottomSheet<Locale>(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Tiếng Việt',
                  style: GoogleFonts.poppins(color: _textColor),
                ),
                trailing: AppPreferences.instance.locale.languageCode == 'vi'
                    ? Icon(Icons.check, color: _primaryBlue)
                    : null,
                onTap: () => Navigator.pop(context, const Locale('vi')),
              ),
              ListTile(
                title: Text(
                  'English',
                  style: GoogleFonts.poppins(color: _textColor),
                ),
                trailing: AppPreferences.instance.locale.languageCode == 'en'
                    ? Icon(Icons.check, color: _primaryBlue)
                    : null,
                onTap: () => Navigator.pop(context, const Locale('en')),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    AppPreferences.instance.setLocale(selected);
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildToggleItem(
    IconData icon,
    String title,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: _primaryBlue, size: 22),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: _textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        activeColor: _primaryBlue,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _handleLogoutTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: Text(
          _logoutT("Đăng xuất", "Log out"),
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogoutTap() async {
    final bool confirmed = await _showLogoutConfirmDialog();
    if (!confirmed || !mounted) return;

    try {
      await FirebaseAuth.instance.signOut();
      UserFirestoreService.instance.setFallbackDocId(null);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            _logoutT(
              'Đăng xuất thất bại, vui lòng thử lại.',
              'Logout failed, please try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<bool> _showLogoutConfirmDialog() async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_primaryBlue, const Color(0xFF000766)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _logoutT('Xác nhận đăng xuất', 'Confirm logout'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _logoutT(
                    'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?',
                    'Are you sure you want to log out of this account?',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _subTextColor,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _subTextColor.withOpacity(0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _logoutT('Hủy', 'Cancel'),
                          style: GoogleFonts.poppins(
                            color: _textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _logoutT('Đăng xuất', 'Log out'),
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

    return result ?? false;
  }

  // --- THANH NAV ĐỒNG BỘ ---
  Widget _buildPillBottomNav() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _pillNavItem(Icons.home, _t("Trang chính", "Home"), 0),
            _pillNavItem(Icons.search, "", 1),
            _pillNavItem(Icons.chat_bubble_outline, "", 2),
            _pillNavItem(Icons.settings, _t("Cài đặt", "Settings"), 3),
          ],
        ),
      ),
    );
  }

  Widget _pillNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else if (index == 1)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          );
        else if (index == 2)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ChatPlaceholderScreen()),
          );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : _subTextColor,
              size: 22,
            ),
            if (isSelected && label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MembershipRankData {
  const _MembershipRankData({
    required this.name,
    required this.color,
    required this.gradient,
    required this.icon,
  });

  final String name;
  final Color color;
  final List<Color> gradient;
  final IconData icon;
}
