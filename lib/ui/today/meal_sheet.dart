import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/meal_template.dart';
import '../../providers/calorie_provider.dart';
import '../../providers/meal_library_provider.dart';
import '../../providers/sync_status_provider.dart';
import '../components/fitgo_log_feedback.dart';
import '../components/fitgo_sheet.dart';
import '../theme/fitgo_tokens.dart';

Future<void> showMealSheet(BuildContext context) {
  return showFitGoSheet(context, builder: (_) => const MealSheet());
}

/// One sheet for recent meals, saved meals, portion adjustment, and manual
/// entry. Macros stay collapsed so name and calories remain the fast path.
class MealSheet extends ConsumerStatefulWidget {
  const MealSheet({super.key});

  @override
  ConsumerState<MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends ConsumerState<MealSheet> {
  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _sugar = TextEditingController();

  MealTemplate? _baseMeal;
  double _portion = 1;
  bool _saveTemplate = false;

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _fiber.dispose();
    _sugar.dispose();
    super.dispose();
  }

  int get _caloriesValue => int.tryParse(_calories.text.trim()) ?? 0;

  bool get _canSave => _caloriesValue > 0;

  void _applyMeal(MealTemplate meal) {
    setState(() {
      _baseMeal = meal;
      _portion = 1;
      _writeMeal(meal);
    });
  }

  void _writeMeal(MealTemplate meal) {
    _name.text = meal.name;
    _calories.text = '${meal.calories}';
    _protein.text = '${meal.proteinGrams}';
    _carbs.text = '${meal.carbsGrams}';
    _fat.text = '${meal.fatGrams}';
    _fiber.text = '${meal.fiberGrams}';
    _sugar.text = '${meal.sugarGrams}';
  }

  void _clearTemplate() {
    if (_baseMeal == null) return;
    _baseMeal = null;
    _portion = 1;
  }

  void _changePortion(double delta) {
    final base = _baseMeal;
    if (base == null) return;
    final next = (_portion + delta).clamp(0.5, 4.0);
    if (next == _portion) return;
    setState(() {
      _portion = next;
      _writeMeal(base.scaled(_portion));
    });
  }

  MealTemplate _currentMeal() {
    int read(TextEditingController controller) =>
        int.tryParse(controller.text.trim()) ?? 0;

    return MealTemplate(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty ? 'Meal' : _name.text.trim(),
      calories: _caloriesValue,
      proteinGrams: read(_protein),
      carbsGrams: read(_carbs),
      fatGrams: read(_fat),
      fiberGrams: read(_fiber),
      sugarGrams: read(_sugar),
    );
  }

  void _logMeal() {
    if (!_canSave) return;
    final meal = _currentMeal();
    final nutrition = ref.read(nutritionProvider.notifier);
    final library = ref.read(mealLibraryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final status = savedLocallyLabel(ref.read(syncStatusProvider));

    nutrition.addNutrition(
      label: meal.name,
      calories: meal.calories,
      proteinGrams: meal.proteinGrams,
      carbsGrams: meal.carbsGrams,
      fatGrams: meal.fatGrams,
      fiberGrams: meal.fiberGrams,
      sugarGrams: meal.sugarGrams,
    );
    library.recordLogged(meal);
    if (_saveTemplate) library.saveMeal(meal);

    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    showLogSnackBar(
      messenger,
      message: '${meal.name} logged',
      status: status,
      onUndo: nutrition.removeLastEntry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(mealLibraryProvider);
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final recent = library.recent.take(8).toList();
    final saved = library.saved.take(12).toList();

    return FitGoSheet(
      title: 'Log meal',
      subtitle: 'Recent meals first — or enter name and calories.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recent.isNotEmpty) ...[
            _LibraryTitle(label: 'Recent', tokens: tokens),
            const SizedBox(height: FitGoSpacing.xs),
            Wrap(
              spacing: FitGoSpacing.xs,
              runSpacing: FitGoSpacing.xs,
              children: [
                for (final meal in recent)
                  ActionChip(
                    label: Text('${meal.name} · ${meal.calories}'),
                    onPressed: () => _applyMeal(meal),
                  ),
              ],
            ),
            const SizedBox(height: FitGoSpacing.md),
          ],
          if (saved.isNotEmpty) ...[
            _LibraryTitle(label: 'Saved', tokens: tokens),
            const SizedBox(height: FitGoSpacing.xs),
            Wrap(
              spacing: FitGoSpacing.xs,
              runSpacing: FitGoSpacing.xs,
              children: [
                for (final meal in saved)
                  InputChip(
                    avatar: Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: tokens.amber,
                    ),
                    label: Text('${meal.name} · ${meal.calories}'),
                    onPressed: () => _applyMeal(meal),
                    onDeleted: () => ref
                        .read(mealLibraryProvider.notifier)
                        .removeSaved(meal.id),
                    deleteButtonTooltipMessage: 'Remove saved meal',
                  ),
              ],
            ),
            const SizedBox(height: FitGoSpacing.md),
          ],
          if (_baseMeal != null) ...[
            Container(
              padding: const EdgeInsets.all(FitGoSpacing.md),
              decoration: BoxDecoration(
                color: tokens.surfaceMuted,
                borderRadius: BorderRadius.circular(tokens.inputRadius),
                border: Border.all(color: tokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _baseMeal!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '$_caloriesValue kcal',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FitGoSpacing.sm),
                  Row(
                    children: [
                      Text(
                        'Portion',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      IconButton.outlined(
                        tooltip: 'Smaller portion',
                        onPressed: _portion > 0.5
                            ? () => _changePortion(-0.5)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FitGoSpacing.sm,
                        ),
                        child: Text(
                          '${_portion == _portion.roundToDouble() ? _portion.toInt() : _portion.toStringAsFixed(1)}×',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton.outlined(
                        tooltip: 'Larger portion',
                        onPressed: _portion < 4
                            ? () => _changePortion(0.5)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  Text(
                    'P ${_protein.text} g · C ${_carbs.text} g · F ${_fat.text} g',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FitGoSpacing.md),
          ],
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(_clearTemplate),
            decoration: const InputDecoration(
              labelText: 'Meal name',
              hintText: 'e.g. Paneer bowl',
              prefixIcon: Icon(Icons.restaurant_menu),
            ),
          ),
          const SizedBox(height: FitGoSpacing.sm),
          TextField(
            controller: _calories,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(_clearTemplate),
            decoration: const InputDecoration(
              labelText: 'Calories',
              suffixText: 'kcal',
              prefixIcon: Icon(Icons.local_fire_department_outlined),
            ),
          ),
          const SizedBox(height: FitGoSpacing.xs),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: FitGoSpacing.xs),
              title: Text(
                'Details (macros)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Row(
                  children: [
                    Expanded(child: _macroField(_protein, 'Protein')),
                    const SizedBox(width: FitGoSpacing.sm),
                    Expanded(child: _macroField(_carbs, 'Carbs')),
                  ],
                ),
                const SizedBox(height: FitGoSpacing.sm),
                Row(
                  children: [
                    Expanded(child: _macroField(_fat, 'Fat')),
                    const SizedBox(width: FitGoSpacing.sm),
                    Expanded(child: _macroField(_fiber, 'Fiber')),
                  ],
                ),
                const SizedBox(height: FitGoSpacing.sm),
                _macroField(_sugar, 'Sugar'),
              ],
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _saveTemplate,
            onChanged: (value) => setState(() => _saveTemplate = value),
            title: const Text('Save to my meals'),
            subtitle: const Text('Reuse this meal later'),
          ),
          const SizedBox(height: FitGoSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _canSave ? _logMeal : null,
              icon: const Icon(Icons.check_rounded),
              label: Text(_canSave ? 'Log $_caloriesValue kcal' : 'Log meal'),
            ),
          ),
          const _TodayMealLog(),
        ],
      ),
    );
  }

  Widget _macroField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(_clearTemplate),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'g',
        isDense: true,
      ),
    );
  }
}

class _LibraryTitle extends StatelessWidget {
  const _LibraryTitle({required this.label, required this.tokens});

  final String label;
  final FitGoTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: tokens.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TodayMealLog extends ConsumerWidget {
  const _TodayMealLog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(
      nutritionProvider.select((state) => state.entries),
    );
    if (entries.isEmpty) return const SizedBox.shrink();

    final tokens = context.tokens;
    final theme = Theme.of(context);
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.calories);

    return Padding(
      padding: const EdgeInsets.only(top: FitGoSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Today',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$total kcal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: FitGoSpacing.xs),
          for (var i = entries.length - 1; i >= 0; i--)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                Icons.restaurant_outlined,
                color: tokens.textSecondary,
                size: 20,
              ),
              title: Text(entries[i].label),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${entries[i].calories} kcal',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove meal',
                    onPressed: () {
                      final removed = entries[i];
                      final nutrition = ref.read(nutritionProvider.notifier);
                      final messenger = ScaffoldMessenger.of(context);
                      final status = savedLocallyLabel(
                        ref.read(syncStatusProvider),
                      );
                      if (!nutrition.removeEntryAt(i)) return;
                      showLogSnackBar(
                        messenger,
                        message: '${removed.label} removed',
                        status: status,
                        onUndo: () => nutrition.addNutrition(
                          label: removed.label,
                          calories: removed.calories,
                          proteinGrams: removed.proteinGrams,
                          carbsGrams: removed.carbsGrams,
                          fatGrams: removed.fatGrams,
                          fiberGrams: removed.fiberGrams,
                          sugarGrams: removed.sugarGrams,
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
