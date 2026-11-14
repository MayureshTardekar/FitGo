import 'dart:convert';

/// A meal the user can log again without retyping its macros.
class MealTemplate {
  const MealTemplate({
    required this.id,
    required this.name,
    required this.calories,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.fiberGrams = 0,
    this.sugarGrams = 0,
    this.lastUsedEpoch = 0,
    this.useCount = 0,
  });

  final String id;
  final String name;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int fiberGrams;
  final int sugarGrams;
  final int lastUsedEpoch;
  final int useCount;

  /// Stable identity used to avoid duplicate recent/saved rows.
  String get key => '${name.trim().toLowerCase()}|$calories';

  MealTemplate scaled(double portion) {
    final safe = portion.clamp(0.25, 10.0);
    int scale(int value) => (value * safe).round();
    return MealTemplate(
      id: id,
      name: name,
      calories: scale(calories),
      proteinGrams: scale(proteinGrams),
      carbsGrams: scale(carbsGrams),
      fatGrams: scale(fatGrams),
      fiberGrams: scale(fiberGrams),
      sugarGrams: scale(sugarGrams),
      lastUsedEpoch: lastUsedEpoch,
      useCount: useCount,
    );
  }

  MealTemplate copyWith({
    String? id,
    String? name,
    int? calories,
    int? proteinGrams,
    int? carbsGrams,
    int? fatGrams,
    int? fiberGrams,
    int? sugarGrams,
    int? lastUsedEpoch,
    int? useCount,
  }) {
    return MealTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      fiberGrams: fiberGrams ?? this.fiberGrams,
      sugarGrams: sugarGrams ?? this.sugarGrams,
      lastUsedEpoch: lastUsedEpoch ?? this.lastUsedEpoch,
      useCount: useCount ?? this.useCount,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'calories': calories,
    'protein': proteinGrams,
    'carbs': carbsGrams,
    'fat': fatGrams,
    'fiber': fiberGrams,
    'sugar': sugarGrams,
    'lastUsed': lastUsedEpoch,
    'useCount': useCount,
  };

  static MealTemplate? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final name = value['name'];
    final calories = value['calories'];
    if (name is! String || name.trim().isEmpty) return null;
    if (calories is! num || calories <= 0) return null;

    int read(String key) {
      final raw = value[key];
      return raw is num ? raw.toInt() : 0;
    }

    return MealTemplate(
      id: value['id'] is String
          ? value['id'] as String
          : '${name.trim().toLowerCase()}|${calories.toInt()}',
      name: name.trim(),
      calories: calories.toInt(),
      proteinGrams: read('protein'),
      carbsGrams: read('carbs'),
      fatGrams: read('fat'),
      fiberGrams: read('fiber'),
      sugarGrams: read('sugar'),
      lastUsedEpoch: read('lastUsed'),
      useCount: read('useCount'),
    );
  }

  static List<MealTemplate> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(MealTemplate.tryFromJson)
          .whereType<MealTemplate>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(List<MealTemplate> meals) {
    return jsonEncode(meals.map((meal) => meal.toJson()).toList());
  }
}
