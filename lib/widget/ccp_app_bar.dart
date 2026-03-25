import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App Bar chuẩn dùng chung cho toàn bộ ứng dụng CCPBank.
class CCPAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CCPAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.onBackPressed,
  });

  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;

  static const Color _primaryBlue = Color(0xFF000DC0);

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 60,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              color: _primaryBlue,
              onPressed: onBackPressed ?? () => Navigator.maybePop(context),
            )
          : null,
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
      actions: actions,
    );
  }
}
