import 'package:flutter/material.dart';

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.splashColor,
    this.scaleOnPress = 0.95,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final double scaleOnPress;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  double _scale = 1;

  void _setPressed(bool pressed) {
    if (!mounted) return;
    setState(() {
      _scale = pressed ? widget.scaleOnPress : 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius =
        widget.borderRadius ?? BorderRadius.circular(14);

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          splashColor: widget.splashColor ?? Theme.of(context).splashColor,
          highlightColor: Colors.transparent,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    );
  }
}
