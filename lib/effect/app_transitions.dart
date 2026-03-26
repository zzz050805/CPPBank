import 'package:flutter/material.dart';

class GentlePageTransitionsBuilder extends PageTransitionsBuilder {
  const GentlePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 420);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == '/') {
      return child;
    }

    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutQuart,
      reverseCurve: Curves.easeInOutQuart,
    );

    final Animation<double> fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(curved);
    final Animation<double> scale = Tween<double>(
      begin: 0.96,
      end: 1,
    ).animate(curved);

    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: scale, child: child),
    );
  }
}
