import 'package:flutter/services.dart';

/// Platform-tuned haptic feedback used for selections and goal completion.
abstract final class FitGoHaptics {
  static Future<void> select() => HapticFeedback.selectionClick();

  static Future<void> impact() => HapticFeedback.lightImpact();

  static Future<void> success() => HapticFeedback.mediumImpact();

  static Future<void> warning() => HapticFeedback.heavyImpact();
}
