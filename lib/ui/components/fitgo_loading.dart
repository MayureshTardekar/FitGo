import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';
import 'fitgo_mark.dart';

/// A branded loading state shared by content areas and sheets.
class FitGoLoading extends StatelessWidget {
  const FitGoLoading({super.key, this.size = 56, this.label = 'Loading'});

  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final ringSize = size + 20;

    return Semantics(
      label: label,
      container: true,
      child: SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: ringSize,
                height: ringSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: tokens.ember,
                  backgroundColor: tokens.border.withValues(alpha: 0.55),
                ),
              ),
            ),
            ExcludeSemantics(child: FitGoMark(size: size)),
          ],
        ),
      ),
    );
  }
}
