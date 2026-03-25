import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_preferences.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import 'search_screen.dart';
import 'home_screen.dart';
import 'chat_placeholder_screen.dart';
import 'login.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  int _selectedIndex = 3;
  bool _isDarkMode = false; // Chức năng Dark Mode

  String _t(String vi, String en) => AppText.tr(context, vi, en);

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
                        ),
                        _buildSettingItem(
                          Icons.devices_outlined,
                          _t("Thiết bị tin cậy", "Trusted devices"),
                        ),
                        _buildSettingItem(
                          Icons.lock_outline,
                          _t("Đổi mật khẩu", "Change password"),
                        ),
                      ]),

                      const SizedBox(height: 25),
                      _sectionTitle(_t("THÔNG TIN", "INFORMATION")),
                      _buildSettingsGroup([
                        _buildSettingItem(
                          Icons.info_outline,
                          _t("Về ứng dụng", "About app"),
                          trailingText: "v2.0.4",
                        ),
                        _buildSettingItem(
                          Icons.help_outline,
                          _t("Trung tâm trợ giúp", "Help center"),
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
          _buildPillBottomNav(),
        ],
      ),
    );
  }

  // --- WIDGET PHỤ TRỢ ---

  Widget _buildAvatar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.white24,
        shape: BoxShape.circle,
      ),
      child: const CircleAvatar(
        radius: 35,
        backgroundImage: NetworkImage(
          'https://i.pravatar.cc/150?img=68',
        ), // Avatar mẫu
      ),
    );
  }

  Widget _buildUserInfo() {
    return StreamBuilder<UserProfileData?>(
      stream: UserFirestoreService.instance.currentUserProfileStream(),
      builder: (context, snapshot) {
        final String fullname = snapshot.hasError
            ? _t('Không tìm thấy user', 'User not found')
            : (snapshot.data?.fullname ?? '...');
        final String email = snapshot.hasError
            ? _t('Không tìm thấy user', 'User not found')
            : (snapshot.data?.email ?? '...');

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fullname.toUpperCase(),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _t("HẠNG VÀNG", "GOLD"),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
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
          _t("Đăng xuất", "Log out"),
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
            _t(
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
                  _t('Xác nhận đăng xuất', 'Confirm logout'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
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
                          _t('Hủy', 'Cancel'),
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
                          _t('Đăng xuất', 'Log out'),
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
        if (index == 0)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        else if (index == 1)
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
