import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';

/// Simple FitGo brand mark used in navigation rails and headers.
class FitGoMark extends StatelessWidget {
  const FitGoMark({super.key, this.size = 40, this.showBackground = true});

  final double size;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final icon = Icon(
      Icons.local_fire_department_rounded,
      size: size * 0.58,
      color: Colors.white,
    );

    if (!showBackground) {
      return Icon(
        Icons.local_fire_department_rounded,
        size: size,
        color: tokens.ember,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.ember, tokens.amber],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(child: icon),
    );
  }
}
