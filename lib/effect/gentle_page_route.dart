import 'package:flutter/material.dart';

class GentlePageRoute<T> extends PageRouteBuilder<T> {
  GentlePageRoute({required Widget page, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final Animation<double> fade = Tween<double>(
            begin: 0,
            end: 1,
          ).animate(curved);
          final Animation<double> scale = Tween<double>(
            begin: 0.97,
            end: 1,
          ).animate(curved);

          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
      );
}
