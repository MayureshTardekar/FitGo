import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';

/// Pulsing placeholder used while a data-backed section loads.
class FitGoSkeleton extends StatefulWidget {
  const FitGoSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = FitGoRadii.input,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<FitGoSkeleton> createState() => _FitGoSkeletonState();
}

class _FitGoSkeletonState extends State<FitGoSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.45,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }

    return FadeTransition(
      opacity: reduceMotion ? const AlwaysStoppedAnimation(0.7) : _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: tokens.surfaceMuted,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A skeleton card matching the standard list layout.
class FitGoSkeletonCard extends StatelessWidget {
  const FitGoSkeletonCard({super.key, this.height = 104});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(FitGoSpacing.lg),
      decoration: BoxDecoration(
        color: context.tokens.surface,
        borderRadius: BorderRadius.circular(context.tokens.cardRadius),
        border: Border.all(color: context.tokens.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FitGoSkeleton(width: 120, height: 14),
          SizedBox(height: FitGoSpacing.sm),
          FitGoSkeleton(width: 190, height: 22),
          Spacer(),
          FitGoSkeleton(height: 8),
        ],
      ),
    );
  }
}
