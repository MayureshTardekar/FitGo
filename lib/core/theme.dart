import 'package:flutter/material.dart';

/// FitGo color palette — dark navy base with red-orange-amber accents
class FitColors {
  static const inkBlack = Color(0xFF03071E);
  static const nightBordeaux = Color(0xFF370617);
  static const blackCherry = Color(0xFF6A040F);
  static const oxblood = Color(0xFF9D0208);
  static const brickEmber = Color(0xFFD00000);
  static const redOchre = Color(0xFFDC2F02);
  static const cayenneRed = Color(0xFFE85D04);
  static const deepSaffron = Color(0xFFF48C06);
  static const orange = Color(0xFFFAA307);
  static const amberFlame = Color(0xFFFFBA08);

  static const gradient = [
    inkBlack, nightBordeaux, blackCherry, oxblood,
    brickEmber, redOchre, cayenneRed, deepSaffron,
    orange, amberFlame,
  ];
}

class FitGoTheme {
  static ThemeData get darkTheme {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorSchemeSeed: FitColors.amberFlame,
    );

    return base.copyWith(
      scaffoldBackgroundColor: FitColors.inkBlack,
      colorScheme: base.colorScheme.copyWith(
        surface: const Color(0xFF0A0E24),
        surfaceContainerLowest: FitColors.inkBlack,
        surfaceContainerLow: const Color(0xFF0A0E24),
        surfaceContainer: const Color(0xFF0F132A),
        surfaceContainerHigh: const Color(0xFF141830),
        surfaceContainerHighest: const Color(0xFF1A1E34),
        outline: const Color(0xFF3A3E54),
        outlineVariant: const Color(0xFF252940),
        error: FitColors.brickEmber,
        errorContainer: const Color(0xFF410002),
      ),

      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: FitColors.inkBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF0F132A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E2240), width: 1),
        ),
      ),

      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: const Color(0xFF080C1E),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F132A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF252940)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF252940)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FitColors.amberFlame, width: 2),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF0F132A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      sliderTheme: base.sliderTheme.copyWith(
        inactiveTrackColor: const Color(0xFF252940),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1E34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF1E2240),
        thickness: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        linearTrackColor: Color(0xFF1A1E34),
      ),
    );
  }
}
