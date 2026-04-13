import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_text.dart';
import '../services/user_firestore_service.dart';
import '../services/home_cache_service.dart';
import 'package:doan_nganhang/screen/chat_placeholder_screen.dart';
import 'package:doan_nganhang/screen/home_screen.dart';
import 'package:doan_nganhang/screen/setting_screen.dart';

import 'login.dart';
import 'search_screen.dart';
import '../widget/custom_confirm_dialog.dart';

class MainTabShell extends StatefulWidget {
  const MainTabShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainTabShell> createState() => _MainTabShellState();
}

class _MainTabShellState extends State<MainTabShell> {
  late final PageController _pageController;
  late int _currentIndex;
  late final List<Widget> _pages;
  StreamSubscription<UserProfileData?>? _profileSubscription;
  bool _isHandlingLockFlow = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _pages = <Widget>[
      const HomeScreen(showBottomNav: false),
      const SearchScreen(showBottomNav: false),
      ChatPlaceholderScreen(
        showBackButton: true,
        onBackPressed: () => _onTapTab(1),
      ),
      const SettingScreen(showBottomNav: false),
    ];
    _profileSubscription = UserFirestoreService.instance
        .currentUserProfileStream()
        .listen((_) {
          if (!mounted) {
            return;
          }
          setState(() {});
        });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
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

  Future<void> _handleAccountLocked() async {
    if (!mounted || _isHandlingLockFlow) {
      return;
    }

    _isHandlingLockFlow = true;

    await FirebaseAuth.instance.signOut();
    UserFirestoreService.instance.setFallbackDocId(null);
    await HomeCacheService.instance.clear();

    if (!mounted) {
      return;
    }

    await showCustomConfirmDialog(
      context: context,
      barrierDismissible: false,
      showCancelButton: false,
      confirmText: AppText.text(context, 'btn_understand'),
      confirmColor: const Color(0xFF000DC0),
      title: AppText.text(context, 'account_locked_title'),
      message: AppText.text(context, 'account_locked_msg'),
      onConfirm: () async {},
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  bool _isUserLocked(Map<String, dynamic> data) {
    return data['is_locked'] == true || data['isLocked'] == true;
  }

  Widget _buildShellBody() {
    return Stack(
      children: [
        PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          children: _pages
              .map((page) => _KeepAlivePage(child: page))
              .toList(growable: false),
        ),
        if (_currentIndex != 2)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home, _t('Trang chính', 'Home'), 0),
                  _buildNavItem(Icons.search, _t('Tìm kiếm', 'Search'), 1),
                  _buildNavItem(Icons.chat_bubble_outline, '', 2),
                  _buildNavItem(Icons.settings_outlined, '', 3),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRealtimeLockGuard({required Widget child}) {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      return child;
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? <String, dynamic>{};
            final bool isLocked = _isUserLocked(data);
            final String role = (data['role'] ?? 'user')
                .toString()
                .toLowerCase();

            if (isLocked && role != 'admin' && !_isHandlingLockFlow) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handleAccountLocked();
              });
            }

            return child;
          },
    );
  }

  void _onTapTab(int index) {
    if (_currentIndex == index) return;
    final int fromIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
    });

    // Jump directly for non-adjacent tabs to prevent visible pass-through.
    if ((index - fromIndex).abs() > 1) {
      _pageController.jumpToPage(index);
      return;
    }

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: _buildRealtimeLockGuard(child: _buildShellBody()),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTapTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFF000DC0),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
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

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
