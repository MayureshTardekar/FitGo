import 'package:fitgo/models/meal_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const meal = MealTemplate(
    id: 'meal-1',
    name: 'Paneer bowl',
    calories: 520,
    proteinGrams: 28,
    carbsGrams: 48,
    fatGrams: 22,
    fiberGrams: 7,
    sugarGrams: 6,
    lastUsedEpoch: 1700000000000,
    useCount: 3,
  );

  test('meal templates round-trip through JSON', () {
    final decoded = MealTemplate.decodeList(MealTemplate.encodeList([meal]));

    expect(decoded, hasLength(1));
    final restored = decoded.single;
    expect(restored.id, meal.id);
    expect(restored.name, meal.name);
    expect(restored.calories, meal.calories);
    expect(restored.proteinGrams, meal.proteinGrams);
    expect(restored.carbsGrams, meal.carbsGrams);
    expect(restored.fatGrams, meal.fatGrams);
    expect(restored.fiberGrams, meal.fiberGrams);
    expect(restored.sugarGrams, meal.sugarGrams);
    expect(restored.lastUsedEpoch, meal.lastUsedEpoch);
    expect(restored.useCount, meal.useCount);
  });

  test('portion scaling adjusts calories and every macro', () {
    final doubled = meal.scaled(2);
    expect(doubled.calories, 1040);
    expect(doubled.proteinGrams, 56);
    expect(doubled.carbsGrams, 96);
    expect(doubled.fatGrams, 44);
    expect(doubled.fiberGrams, 14);
    expect(doubled.sugarGrams, 12);

    final half = meal.scaled(0.5);
    expect(half.calories, 260);
    expect(half.proteinGrams, 14);
    expect(half.fatGrams, 11);
  });

  test('portion scaling is clamped to a safe range', () {
    expect(meal.scaled(0).calories, (meal.calories * 0.25).round());
    expect(meal.scaled(100).calories, meal.calories * 10);
  });

  test('meal identity ignores surrounding whitespace and case', () {
    const duplicate = MealTemplate(
      id: 'other',
      name: '  paneer BOWL ',
      calories: 520,
    );

    expect(duplicate.key, meal.key);
    expect(duplicate.key, 'paneer bowl|520');
  });

  test('malformed meal lists are dropped instead of crashing', () {
    expect(MealTemplate.decodeList(null), isEmpty);
    expect(MealTemplate.decodeList('not json'), isEmpty);
    expect(MealTemplate.decodeList('[{"name":""}]'), isEmpty);
    expect(
      MealTemplate.decodeList(
        '[{"name":"Oats","calories":320,"protein":12}]',
      ).single.proteinGrams,
      12,
    );
  });
}
