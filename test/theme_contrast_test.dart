import 'dart:math' as math;

import 'package:fitgo/ui/theme/fitgo_theme.dart';
import 'package:fitgo/ui/theme/fitgo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _linear(double channel) {
  if (channel <= 0.04045) return channel / 12.92;
  return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color color) {
  return 0.2126 * _linear(color.r) +
      0.7152 * _linear(color.g) +
      0.0722 * _linear(color.b);
}

double _contrast(Color foreground, Color background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

void _expectAa(Color foreground, Color background, String label) {
  expect(
    _contrast(foreground, background),
    greaterThanOrEqualTo(4.5),
    reason: '$label must meet WCAG AA for normal text',
  );
}

void main() {
  test('light and dark colour schemes meet AA for key text pairs', () {
    for (final (name, scheme) in [
      ('light', FitGoTheme.light.colorScheme),
      ('dark', FitGoTheme.dark.colorScheme),
    ]) {
      _expectAa(scheme.onPrimary, scheme.primary, '$name primary button');
      _expectAa(
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
        '$name primary container',
      );
      _expectAa(
        scheme.onSecondaryContainer,
        scheme.secondaryContainer,
        '$name secondary container',
      );
      _expectAa(
        scheme.onTertiaryContainer,
        scheme.tertiaryContainer,
        '$name tertiary container',
      );
      _expectAa(scheme.onError, scheme.error, '$name error button');
      _expectAa(
        scheme.onErrorContainer,
        scheme.errorContainer,
        '$name error container',
      );
      _expectAa(scheme.onSurface, scheme.surface, '$name body text');
      _expectAa(
        scheme.onSurfaceVariant,
        scheme.surface,
        '$name secondary text',
      );
    }
  });

  test('filled button theme itself uses an AA foreground', () {
    for (final (name, theme) in [
      ('light', FitGoTheme.light),
      ('dark', FitGoTheme.dark),
    ]) {
      final style = theme.filledButtonTheme.style!;
      final foreground = style.foregroundColor!.resolve(<WidgetState>{});
      final background = style.backgroundColor!.resolve(<WidgetState>{});
      expect(foreground, isNotNull, reason: '$name button foreground');
      expect(background, isNotNull, reason: '$name button background');
      _expectAa(foreground!, background!, '$name filled button');
    }
  });

  test('semantic text tokens meet AA on both surface levels', () {
    for (final (name, tokens) in [
      ('light', FitGoTokens.light),
      ('dark', FitGoTokens.dark),
    ]) {
      _expectAa(tokens.textPrimary, tokens.surface, '$name primary on surface');
      _expectAa(
        tokens.textSecondary,
        tokens.surface,
        '$name secondary on surface',
      );
      _expectAa(
        tokens.textSecondary,
        tokens.surfaceMuted,
        '$name secondary on muted surface',
      );
    }
  });
}
