import 'package:flutter/material.dart';

/// Platform-appropriate scroll physics: bouncing on Apple platforms,
/// platform default elsewhere.
class FitGoScrollBehavior extends MaterialScrollBehavior {
  const FitGoScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      _ => super.getScrollPhysics(context),
    };
  }
}
