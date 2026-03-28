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
    this.backgroundColor,
  });

  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;

  static const Color _primaryBlue = Color(0xFF000DC0);

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final Color effectiveBackgroundColor =
        backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

    return AppBar(
      toolbarHeight: 60,
      backgroundColor: effectiveBackgroundColor,
      surfaceTintColor: effectiveBackgroundColor,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      centerTitle: true,
      automaticallyImplyLeading: false,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),

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
