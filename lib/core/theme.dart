import 'package:flutter/material.dart';

export '../ui/theme/fitgo_theme.dart' show FitGoTheme;

/// Legacy FitGo palette, kept for existing screens while Phase 2 migrates
/// each screen to the semantic tokens in `lib/ui/theme/fitgo_tokens.dart`.
///
/// New code must use `context.tokens` instead of [FitColors].
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
  static const successGreen = Color(0xFF22C55E);
  static const mintGreen = Color(0xFF34D399);
  static const aqua = Color(0xFF2DD4BF);

  static const gradient = [
    inkBlack,
    nightBordeaux,
    blackCherry,
    oxblood,
    brickEmber,
    redOchre,
    cayenneRed,
    deepSaffron,
    orange,
    amberFlame,
  ];
}
