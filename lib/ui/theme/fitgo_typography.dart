import 'package:flutter/material.dart';

/// FitGo typography scale.
///
/// iOS uses the system San Francisco font through Flutter's default platform
/// typography. Android keeps the platform default until a bundled brand font
/// (Inter/Manrope) is added in a later phase.
abstract final class FitGoTypography {
  static TextTheme textTheme(Color primary, Color secondary) {
    const tabular = [FontFeature.tabularFigures()];

    return TextTheme(
          displayLarge: const TextStyle(
            fontSize: 48,
            height: 54 / 48,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            fontFeatures: tabular,
          ),
          displayMedium: const TextStyle(
            fontSize: 40,
            height: 46 / 40,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            fontFeatures: tabular,
          ),
          displaySmall: const TextStyle(
            fontSize: 34,
            height: 40 / 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
            fontFeatures: tabular,
          ),
          headlineLarge: const TextStyle(
            fontSize: 28,
            height: 34 / 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
          ),
          headlineMedium: const TextStyle(
            fontSize: 22,
            height: 28 / 22,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: const TextStyle(
            fontSize: 20,
            height: 26 / 20,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            height: 26 / 20,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            height: 22 / 17,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: const TextStyle(
            fontSize: 16,
            height: 22 / 16,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(
            fontSize: 17,
            height: 24 / 17,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: const TextStyle(
            fontSize: 15,
            height: 20 / 15,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: const TextStyle(
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: const TextStyle(
            fontSize: 16,
            height: 22 / 16,
            fontWeight: FontWeight.w500,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            height: 16 / 11,
            fontWeight: FontWeight.w500,
          ),
        )
        .apply(bodyColor: primary, displayColor: primary)
        .copyWith(
          bodySmall: TextStyle(
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w400,
            color: secondary,
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            color: secondary,
          ),
        );
  }
}
