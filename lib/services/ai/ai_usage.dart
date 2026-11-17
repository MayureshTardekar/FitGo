import 'dart:math';

import 'package:intl/intl.dart';

import '../local_storage.dart';
import 'ai_models.dart';

/// Per-account AI request counters.
///
/// Counters live in the account's local Hive settings box. They are never
/// uploaded, so switching accounts cannot inherit another user's usage.
class AiUsage {
  const AiUsage({
    required this.dateKey,
    required this.premiumUsed,
    required this.fallbackUsed,
  });

  factory AiUsage.empty(String dateKey) =>
      AiUsage(dateKey: dateKey, premiumUsed: 0, fallbackUsed: 0);

  final String dateKey;
  final int premiumUsed;
  final int fallbackUsed;

  int get premiumRemaining => max(0, AiModels.premiumDailyLimit - premiumUsed);

  bool get premiumAvailable => premiumRemaining > 0;

  AiUsage copyWith({int? premiumUsed, int? fallbackUsed}) => AiUsage(
    dateKey: dateKey,
    premiumUsed: premiumUsed ?? this.premiumUsed,
    fallbackUsed: fallbackUsed ?? this.fallbackUsed,
  );
}

class AiUsageStore {
  const AiUsageStore(this.storage);

  static const dateSetting = 'ai_usage_date';
  static const premiumSetting = 'ai_usage_premium';
  static const fallbackSetting = 'ai_usage_fallback';

  final LocalStorage storage;

  AiUsage load(DateTime now) {
    final today = _dateKey(now);
    final storedDate = storage.getSetting<String>(dateSetting, '');
    if (storedDate != today) return AiUsage.empty(today);

    return AiUsage(
      dateKey: today,
      premiumUsed: _counter(storage.getSetting<int>(premiumSetting, 0)),
      fallbackUsed: _counter(storage.getSetting<int>(fallbackSetting, 0)),
    );
  }

  Future<AiUsage> record(AiModel model, DateTime now) async {
    final current = load(now);
    final updated = model.premium
        ? current.copyWith(premiumUsed: current.premiumUsed + 1)
        : current.copyWith(fallbackUsed: current.fallbackUsed + 1);

    await storage.saveLocalSetting(dateSetting, updated.dateKey);
    await storage.saveLocalSetting(premiumSetting, updated.premiumUsed);
    await storage.saveLocalSetting(fallbackSetting, updated.fallbackUsed);
    return updated;
  }

  Future<void> clear() async {
    await storage.deleteLocalSetting(dateSetting);
    await storage.deleteLocalSetting(premiumSetting);
    await storage.deleteLocalSetting(fallbackSetting);
  }

  static String _dateKey(DateTime value) =>
      DateFormat('yyyy-MM-dd').format(value);

  static int _counter(int value) => value.clamp(0, 100000).toInt();
}

/// Chooses the first ten requests of the day from the two premium models,
/// alternating between them, then falls back to Flash Lite automatically.
class AiModelRouter {
  const AiModelRouter();

  List<AiModel> route(AiUsage usage) {
    if (!usage.premiumAvailable) {
      return const [AiModels.flashLite35];
    }

    final first = usage.premiumUsed.isEven
        ? AiModels.flash38
        : AiModels.flash36;
    final second = first == AiModels.flash38
        ? AiModels.flash36
        : AiModels.flash38;

    if (usage.premiumRemaining == 1) {
      return [first, AiModels.flashLite35];
    }
    return [first, second, AiModels.flashLite35];
  }
}
