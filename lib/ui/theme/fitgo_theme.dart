import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fitgo_tokens.dart';
import 'fitgo_typography.dart';

/// Single source of truth for FitGo's light and dark themes.
abstract final class FitGoTheme {
  static ThemeData get light => _build(
    brightness: Brightness.light,
    scheme: _lightScheme,
    tokens: FitGoTokens.light,
    scaffoldBackground: const Color(0xFFFAF9F6),
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scheme: _darkScheme,
    tokens: FitGoTokens.dark,
    scaffoldBackground: const Color(0xFF0B0F1A),
  );

  // Backwards-compatible aliases used by app.dart.
  static ThemeData get lightTheme => light;
  static ThemeData get darkTheme => dark;

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFF25C2A),
    onPrimary: Color(0xFF3D1406),
    primaryContainer: Color(0xFFFFE8DF),
    onPrimaryContainer: Color(0xFF7A250C),
    secondary: Color(0xFFF59E0B),
    onSecondary: Color(0xFF1C1917),
    secondaryContainer: Color(0xFFFFF1D6),
    onSecondaryContainer: Color(0xFF7C4A03),
    tertiary: Color(0xFF0E7490),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFCFFAFE),
    onTertiaryContainer: Color(0xFF155E75),
    error: Color(0xFFDC2626),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF161A2D),
    onSurfaceVariant: Color(0xFF667085),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAF9F6),
    surfaceContainer: Color(0xFFF3F1ED),
    surfaceContainerHigh: Color(0xFFECE9E4),
    surfaceContainerHighest: Color(0xFFE5E1DA),
    outline: Color(0xFFC9C4BE),
    outlineVariant: Color(0xFFE7E5E4),
    inverseSurface: Color(0xFF161A2D),
    onInverseSurface: Color(0xFFF8FAFC),
    inversePrimary: Color(0xFFFFB59E),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Color(0x00000000),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF7A45),
    onPrimary: Color(0xFF3D1406),
    primaryContainer: Color(0xFF7A250C),
    onPrimaryContainer: Color(0xFFFFDBCF),
    secondary: Color(0xFFFFB020),
    onSecondary: Color(0xFF2B1A00),
    secondaryContainer: Color(0xFF5C3B00),
    onSecondaryContainer: Color(0xFFFFE3AE),
    tertiary: Color(0xFF22D3EE),
    onTertiary: Color(0xFF00363F),
    tertiaryContainer: Color(0xFF004E5A),
    onTertiaryContainer: Color(0xFFA5F3FC),
    error: Color(0xFFF87171),
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFEE2E2),
    surface: Color(0xFF111827),
    onSurface: Color(0xFFF8FAFC),
    onSurfaceVariant: Color(0xFF94A3B8),
    surfaceContainerLowest: Color(0xFF0B0F1A),
    surfaceContainerLow: Color(0xFF0F1520),
    surfaceContainer: Color(0xFF1A2233),
    surfaceContainerHigh: Color(0xFF202A3C),
    surfaceContainerHighest: Color(0xFF273244),
    outline: Color(0xFF475569),
    outlineVariant: Color(0xFF273244),
    inverseSurface: Color(0xFFF8FAFC),
    onInverseSurface: Color(0xFF161A2D),
    inversePrimary: Color(0xFF7A250C),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Color(0x00000000),
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required FitGoTokens tokens,
    required Color scaffoldBackground,
  }) {
    final isDark = brightness == Brightness.dark;
    final isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    // Ember is a 3.1:1 accent on white, so normal-size accent text uses the
    // deeper orange in light mode. Icons and progress rings keep the vivid hue.
    final accentText = isDark ? scheme.primary : tokens.emberDeep;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      canvasColor: scaffoldBackground,
      visualDensity: VisualDensity.standard,
      splashFactory: isApple ? NoSplash.splashFactory : InkRipple.splashFactory,
      textTheme: FitGoTypography.textTheme(
        tokens.textPrimary,
        tokens.textSecondary,
      ),
      extensions: [tokens],
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.inputRadius),
      borderSide: BorderSide(color: tokens.border),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: tokens.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: scaffoldBackground,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          side: BorderSide(color: tokens.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.border, thickness: 1),
      iconTheme: IconThemeData(color: tokens.textPrimary, size: 24),
      listTileTheme: ListTileThemeData(
        iconColor: tokens.ember,
        textColor: tokens.textPrimary,
        subtitleTextStyle: TextStyle(color: tokens.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.inputRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? tokens.surfaceMuted : tokens.surfaceMuted,
        hintStyle: TextStyle(color: tokens.textSecondary),
        labelStyle: TextStyle(color: tokens.textSecondary),
        floatingLabelStyle: TextStyle(color: accentText),
        errorStyle: TextStyle(color: scheme.error),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FitGoSpacing.md,
          vertical: FitGoSpacing.md,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: tokens.border.withValues(alpha: 0.5)),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: FitGoSpacing.lg,
              vertical: FitGoSpacing.sm,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.inputRadius),
            ),
          ),
          textStyle: WidgetStatePropertyAll(base.textTheme.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.primary.withValues(alpha: 0.38);
            }
            return scheme.primary;
          }),
          foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: FitGoSpacing.lg,
              vertical: FitGoSpacing.sm,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.inputRadius),
            ),
          ),
          textStyle: WidgetStatePropertyAll(base.textTheme.labelLarge),
          side: WidgetStatePropertyAll(BorderSide(color: tokens.border)),
          foregroundColor: WidgetStatePropertyAll(tokens.textPrimary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          textStyle: WidgetStatePropertyAll(base.textTheme.labelLarge),
          foregroundColor: WidgetStatePropertyAll(accentText),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.inputRadius),
            ),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: tokens.surfaceMuted,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        side: BorderSide(color: tokens.border),
        labelStyle: base.textTheme.labelMedium?.copyWith(
          color: tokens.textPrimary,
        ),
        secondaryLabelStyle: base.textTheme.labelMedium?.copyWith(
          color: accentText,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: FitGoSpacing.sm,
          vertical: FitGoSpacing.xs,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          textStyle: WidgetStatePropertyAll(base.textTheme.labelMedium),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primary.withValues(alpha: 0.14);
            }
            return tokens.surfaceMuted;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accentText;
            }
            return tokens.textSecondary;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: tokens.border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.inputRadius),
            ),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accentText, size: 24);
          }
          return IconThemeData(color: tokens.textSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return base.textTheme.labelMedium?.copyWith(
            color: selected ? accentText : tokens.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: accentText),
        unselectedIconTheme: IconThemeData(color: tokens.textSecondary),
        selectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
          color: accentText,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
          color: tokens.textSecondary,
        ),
        useIndicator: true,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        modalBackgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: tokens.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.sheetRadius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
        ),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: tokens.textPrimary,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: tokens.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.inputRadius),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: tokens.border,
        circularTrackColor: tokens.border,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: tokens.border,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.onPrimary;
          }
          return tokens.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return tokens.border;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(FitGoRadii.input),
        ),
        textStyle: base.textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: scheme.primary,
        primaryContrastingColor: scheme.onPrimary,
        scaffoldBackgroundColor: scaffoldBackground,
        barBackgroundColor: tokens.surface,
      ),
    );
  }
}
