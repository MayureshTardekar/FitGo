import 'package:flutter/material.dart';

/// Semantic design tokens for FitGo.
///
/// Widgets should read colours from [FitGoTokensX.tokens] instead of
/// hard-coding hex values. The legacy [FitColors] palette is migrated to
/// these tokens screen by screen during Phase 2.
@immutable
class FitGoTokens extends ThemeExtension<FitGoTokens> {
  const FitGoTokens({
    required this.ember,
    required this.emberDeep,
    required this.amber,
    required this.mint,
    required this.aqua,
    required this.danger,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.shadow,
    required this.cardRadius,
    required this.sheetRadius,
    required this.inputRadius,
    required this.heroRadius,
  });

  final Color ember;
  final Color emberDeep;
  final Color amber;
  final Color mint;
  final Color aqua;
  final Color danger;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color shadow;
  final double cardRadius;
  final double sheetRadius;
  final double inputRadius;
  final double heroRadius;

  /// Light-mode palette from the upgrade plan.
  static const light = FitGoTokens(
    ember: Color(0xFFF25C2A),
    emberDeep: Color(0xFFC2410C),
    amber: Color(0xFFF59E0B),
    mint: Color(0xFF10B981),
    aqua: Color(0xFF0891B2),
    danger: Color(0xFFDC2626),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF3F1ED),
    textPrimary: Color(0xFF161A2D),
    textSecondary: Color(0xFF5F6B7A),
    border: Color(0xFFE7E5E4),
    shadow: Color(0x0F0F172A),
    cardRadius: 20,
    sheetRadius: 28,
    inputRadius: 12,
    heroRadius: 28,
  );

  /// Dark-mode palette from the upgrade plan.
  static const dark = FitGoTokens(
    ember: Color(0xFFFF7A45),
    emberDeep: Color(0xFFE85D04),
    amber: Color(0xFFFFB020),
    mint: Color(0xFF34D399),
    aqua: Color(0xFF22D3EE),
    danger: Color(0xFFF87171),
    surface: Color(0xFF111827),
    surfaceMuted: Color(0xFF1A2233),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    border: Color(0xFF273244),
    shadow: Color(0x00000000),
    cardRadius: 20,
    sheetRadius: 28,
    inputRadius: 12,
    heroRadius: 28,
  );

  @override
  FitGoTokens copyWith({
    Color? ember,
    Color? emberDeep,
    Color? amber,
    Color? mint,
    Color? aqua,
    Color? danger,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? shadow,
    double? cardRadius,
    double? sheetRadius,
    double? inputRadius,
    double? heroRadius,
  }) {
    return FitGoTokens(
      ember: ember ?? this.ember,
      emberDeep: emberDeep ?? this.emberDeep,
      amber: amber ?? this.amber,
      mint: mint ?? this.mint,
      aqua: aqua ?? this.aqua,
      danger: danger ?? this.danger,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      cardRadius: cardRadius ?? this.cardRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
      inputRadius: inputRadius ?? this.inputRadius,
      heroRadius: heroRadius ?? this.heroRadius,
    );
  }

  @override
  FitGoTokens lerp(ThemeExtension<FitGoTokens>? other, double t) {
    if (other is! FitGoTokens) return this;
    return FitGoTokens(
      ember: Color.lerp(ember, other.ember, t)!,
      emberDeep: Color.lerp(emberDeep, other.emberDeep, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      aqua: Color.lerp(aqua, other.aqua, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      cardRadius: cardRadius,
      sheetRadius: sheetRadius,
      inputRadius: inputRadius,
      heroRadius: heroRadius,
    );
  }
}

extension FitGoTokensX on BuildContext {
  FitGoTokens get tokens => Theme.of(this).extension<FitGoTokens>()!;
}

/// Spacing scale from the design language (multiples of 4).
abstract final class FitGoSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
}

/// Radius scale from the design language.
abstract final class FitGoRadii {
  static const input = 12.0;
  static const cardSmall = 16.0;
  static const card = 20.0;
  static const sheet = 24.0;
  static const hero = 28.0;
  static const pill = 999.0;
}

/// Layout breakpoints used by the adaptive shell.
abstract final class FitGoBreakpoints {
  static const wide = 900.0;
  static const contentMaxWidth = 1200.0;
}
