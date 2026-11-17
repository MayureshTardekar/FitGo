import 'package:flutter/material.dart';

/// FitGo brand mark used in navigation rails, headers, and loading states.
class FitGoMark extends StatelessWidget {
  const FitGoMark({super.key, this.size = 40});

  static const asset = 'assets/images/logo.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return Semantics(
      label: 'FitGo',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.3),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          cacheWidth: cacheWidth,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
