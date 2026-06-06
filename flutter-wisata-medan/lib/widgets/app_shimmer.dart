import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class AppShimmerBox extends StatefulWidget {
  const AppShimmerBox({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.color,
    this.highlightColor,
  });

  final double height;
  final double width;
  final BorderRadius borderRadius;
  final Color? color;
  final Color? highlightColor;

  @override
  State<AppShimmerBox> createState() => _AppShimmerBoxState();
}

class _AppShimmerBoxState extends State<AppShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.color ?? AppTheme.border(context).withValues(alpha: 0.46);
    final highlightColor = widget.highlightColor ??
        AppTheme.surface(context).withValues(alpha: 0.96);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.8 + (value * 2.6), -0.3),
              end: Alignment(-0.6 + (value * 2.6), 0.3),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.15, 0.5, 0.85],
            ),
          ),
        );
      },
    );
  }
}

class AppShimmerCircle extends StatelessWidget {
  const AppShimmerCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return AppShimmerBox(
      height: size,
      width: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }
}
