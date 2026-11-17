import 'package:flutter/foundation.dart';

/// A Gemini text model the coach may use.
@immutable
class AiModel {
  const AiModel({required this.id, required this.label, required this.premium});

  final String id;
  final String label;

  /// Premium models share a small daily request allowance. Flash Lite is the
  /// always-available fallback.
  final bool premium;

  @override
  bool operator ==(Object other) => other is AiModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Model identifiers verified against the Gemini models endpoint.
///
/// These are stable model strings, not preview aliases. The fallback model is
/// intentionally the cheapest/fastest option so a chat keeps working after the
/// user's premium requests are used or a premium model is unavailable.
abstract final class AiModels {
  static const flash38 = AiModel(
    id: 'gemini-3.8-flash',
    label: '3.8 Flash',
    premium: true,
  );

  static const flash36 = AiModel(
    id: 'gemini-3.6-flash',
    label: '3.6 Flash',
    premium: true,
  );

  static const flashLite35 = AiModel(
    id: 'gemini-3.5-flash-lite',
    label: '3.5 Flash Lite',
    premium: false,
  );

  /// Free-tier daily allowance used by the app for the two premium models.
  static const premiumDailyLimit = 10;

  /// Published free-tier fallback allowance. The app does not need to enforce
  /// this; it is used only for the settings summary.
  static const fallbackDailyLimit = 1500;
}
