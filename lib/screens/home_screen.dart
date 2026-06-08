import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../providers/activity_provider.dart';
import '../providers/calorie_provider.dart';
import '../providers/dashboard_focus_provider.dart';
import '../providers/monthly_calorie_alert_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/water_provider.dart';
import '../providers/weekly_nutrition_plan_provider.dart';
import '../providers/weekly_provider.dart';
import '../providers/weight_provider.dart';
import '../widgets/radial_dial.dart';
import '../widgets/weight_chart.dart';
import 'past_day_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMode = ref.watch(dashboardFocusModeProvider);
    final fasting = ref.watch(fastingProvider);
    final effectiveMode = selectedMode == DashboardFocusMode.auto
        ? fasting.isFasting
              ? DashboardFocusMode.fasting
              : DashboardFocusMode.nutrition
        : selectedMode;

    ref.listen<FastingState>(fastingProvider, (previous, next) {
      if (previous?.reminderSignal == next.reminderSignal ||
          next.reminderSignal == 0 ||
          !next.isFasting) {
        return;
      }

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Fasting reminder: drink water and stay zero-calorie.',
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '+250 ml',
            onPressed: () => ref.read(waterProvider.notifier).addWater(250),
          ),
        ),
      );
    });
    ref.watch(monthlyCalorieAlertProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitGo'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Log Past Day',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PastDayLogScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const _DashboardFocusSelector(),
          const SizedBox(height: 12),
          const _TodayOverviewStrip(),
          const SizedBox(height: 12),
          ..._focusChildren(effectiveMode),
        ],
      ),
    );
  }

  List<Widget> _focusChildren(DashboardFocusMode mode) {
    final gap = const SizedBox(height: 12);

    switch (mode) {
      case DashboardFocusMode.fasting:
        return [
          const _FastingCard(),
          gap,
          const _FastingSupportCard(),
          gap,
          const _DashboardDropdown(
            title: 'Food and more',
            children: [
              _CalorieCard(),
              _WeeklyNutritionCoachCard(),
              _NetCaloriesBanner(),
              _WaterCard(),
              _StepsCard(),
              _ActivityCard(),
              _SleepCard(),
              _WeightCard(),
            ],
          ),
        ];
      case DashboardFocusMode.nutrition:
        return [
          const _WeeklyNutritionCoachCard(),
          gap,
          const _CalorieCard(),
          gap,
          const _DashboardDropdown(
            title: 'Fast and more',
            children: [
              _FastingCard(),
              _NetCaloriesBanner(),
              _WaterCard(),
              _StepsCard(),
              _ActivityCard(),
              _SleepCard(),
              _WeightCard(),
            ],
          ),
        ];
      case DashboardFocusMode.full:
        return [
          const _WeeklyNutritionCoachCard(),
          gap,
          const _NetCaloriesBanner(),
          gap,
          const _FastingCard(),
          gap,
          const _CalorieCard(),
          gap,
          const _DashboardDropdown(
            title: 'More today',
            initiallyExpanded: true,
            children: [
              _WaterCard(),
              _StepsCard(),
              _ActivityCard(),
              _SleepCard(),
              _WeightCard(),
            ],
          ),
        ];
      case DashboardFocusMode.auto:
        return const [];
    }
  }
}

class _DashboardFocusSelector extends ConsumerWidget {
  const _DashboardFocusSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(dashboardFocusModeProvider);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: SegmentedButton<DashboardFocusMode>(
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 8),
          ),
          textStyle: WidgetStatePropertyAll(
            Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        segments: const [
          ButtonSegment(
            value: DashboardFocusMode.auto,
            icon: Icon(Icons.auto_awesome, size: 16),
            label: Text('Auto'),
          ),
          ButtonSegment(
            value: DashboardFocusMode.fasting,
            icon: Icon(Icons.timer_outlined, size: 16),
            label: Text('Fast'),
          ),
          ButtonSegment(
            value: DashboardFocusMode.nutrition,
            icon: Icon(Icons.restaurant_menu, size: 16),
            label: Text('Food'),
          ),
          ButtonSegment(
            value: DashboardFocusMode.full,
            icon: Icon(Icons.view_agenda_outlined, size: 16),
            label: Text('Full'),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (value) =>
            ref.read(dashboardFocusModeProvider.notifier).setMode(value.first),
      ),
    );
  }
}

class _TodayOverviewStrip extends ConsumerWidget {
  const _TodayOverviewStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nutrition = ref.watch(nutritionProvider);
    final profile = ref.watch(profileProvider);
    final water = ref.watch(waterProvider);
    final fasting = ref.watch(fastingProvider);
    final activity = ref.watch(activityProvider);
    final cs = Theme.of(context).colorScheme;

    final dailyQuota = profile?.dailyQuota ?? AppConstants.dailyCalorieGoalKcal;
    final waterGoal = profile?.waterGoalMl ?? AppConstants.dailyWaterGoalMl;
    final caloriesSafe = nutrition.totalCalories <= dailyQuota;
    final waterSafe = water >= waterGoal;
    final fastColor = fasting.isFasting ? FitColors.aqua : cs.onSurfaceVariant;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DashboardStatTile(
                icon: Icons.local_fire_department,
                label: 'Calories',
                value: '${nutrition.totalCalories} / $dailyQuota',
                color: caloriesSafe ? FitColors.successGreen : cs.error,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DashboardStatTile(
                icon: Icons.water_drop_outlined,
                label: 'Water',
                value: '$water / $waterGoal ml',
                color: waterSafe ? FitColors.aqua : cs.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DashboardStatTile(
                icon: Icons.timer_outlined,
                label: 'Fast',
                value: fasting.isFasting
                    ? formatDurationShort(fasting.elapsed)
                    : 'Ready',
                color: fastColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DashboardStatTile(
                icon: Icons.directions_walk,
                label: 'Steps',
                value: activity.steps.toString(),
                color: activity.steps > 0
                    ? FitColors.successGreen
                    : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DashboardStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 68,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FastingSupportCard extends ConsumerWidget {
  const _FastingSupportCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final water = ref.watch(waterProvider);
    final profile = ref.watch(profileProvider);
    final fasting = ref.watch(fastingProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final waterGoal = profile?.waterGoalMl ?? AppConstants.dailyWaterGoalMl;
    final progress = waterGoal > 0
        ? (water / waterGoal).clamp(0.0, 1.0).toDouble()
        : 0.0;

    if (!fasting.isFasting) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.water_drop_outlined, color: FitColors.aqua),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Start a fast to enable water reminders and calorie lock.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_clock_outlined, color: FitColors.aqua),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fasting Focus',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (fasting.remindersEnabled)
                  Text(
                    'Next ${formatDurationShort(fasting.untilNextReminder)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: FitColors.aqua,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Calories locked. Drink water and stay zero-calorie.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _AnimatedProgressBar(
              progress: progress,
              color: FitColors.aqua,
              backgroundColor: cs.surfaceContainerHighest,
            ),
            const SizedBox(height: 6),
            Text(
              '$water / $waterGoal ml water',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        ref.read(waterProvider.notifier).addWater(250),
                    icon: const Icon(Icons.water_drop, size: 18),
                    label: const Text('+250 ml'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(waterProvider.notifier).addWater(500),
                    icon: const Icon(Icons.local_drink_outlined, size: 18),
                    label: const Text('+500 ml'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardDropdown extends StatelessWidget {
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _DashboardDropdown({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(Icons.expand_circle_down_outlined, color: cs.primary),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final child in children)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
        ],
      ),
    );
  }
}

class _MacroDashboard extends StatelessWidget {
  final NutritionState nutrition;

  const _MacroDashboard({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MacroTile(
                label: 'Protein',
                value: nutrition.proteinGrams,
                target: nutrition.targets.proteinGrams,
                icon: Icons.egg_alt_outlined,
                color: FitColors.successGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MacroTile(
                label: 'Carbs',
                value: nutrition.carbsGrams,
                target: nutrition.targets.carbsGrams,
                icon: Icons.grain,
                color: const Color(0xFFFFBA08),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MacroTile(
                label: 'Fat',
                value: nutrition.fatGrams,
                target: nutrition.targets.fatGrams,
                icon: Icons.opacity,
                color: const Color(0xFFE85D04),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MacroTile(
                label: 'Fiber',
                value: nutrition.fiberGrams,
                target: nutrition.targets.fiberGrams,
                icon: Icons.eco_outlined,
                color: FitColors.mintGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MacroTile(
          label: 'Sugar',
          value: nutrition.sugarGrams,
          target: nutrition.targets.sugarGrams,
          icon: Icons.cake_outlined,
          color: nutrition.sugarGrams > nutrition.targets.sugarGrams
              ? cs.error
              : FitColors.aqua,
          isLimit: true,
        ),
        if (nutrition.entries.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...nutrition.entries.reversed
              .take(3)
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.restaurant,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${entry.calories} kcal',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final int value;
  final int target;
  final IconData icon;
  final Color color;
  final bool isLimit;

  const _MacroTile({
    required this.label,
    required this.value,
    required this.target,
    required this.icon,
    required this.color,
    this.isLimit = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    final overLimit = isLimit && value > target;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(180),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: overLimit ? cs.error.withAlpha(90) : cs.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: overLimit ? cs.error : color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$value / $target g',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: overLimit ? cs.error : cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: cs.surfaceContainerHigh,
              color: overLimit ? cs.error : color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Weekly Banner ───────────────────────────────────────────────────────────

class _WeeklyNutritionCoachCard extends ConsumerWidget {
  const _WeeklyNutritionCoachCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(weeklyNutritionPlanProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final urgent = plan.items.any(
      (item) => item.isOverWeekly || item.isTodayOver,
    );
    final safeColor = plan.consistencyStreak > 0
        ? FitColors.successGreen
        : FitColors.aqua;
    final statusColor = urgent ? cs.error : safeColor;

    if (!plan.enabled) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.route_outlined, color: FitColors.aqua),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '7-Day Plan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Optional rolling nutrition plan',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () =>
                    ref.read(weeklyNutritionPlanProvider.notifier).startToday(),
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(
          urgent ? Icons.warning_amber_rounded : Icons.route_outlined,
          color: statusColor,
        ),
        title: Text(
          'Weekly Plan',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plan.weekLabel}  |  Day ${plan.cycleDay}/7',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${plan.consistencyStreak}-day streak | ${plan.headline}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withAlpha(70)),
            ),
            child: Text(
              plan.guidance,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ref
                      .read(weeklyNutritionPlanProvider.notifier)
                      .resetStartDate(DateTime.now()),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Start today'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Pause plan',
                onPressed: () => ref
                    .read(weeklyNutritionPlanProvider.notifier)
                    .setEnabled(false),
                icon: const Icon(Icons.pause),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _showTargetDialog(context, ref, plan),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Targets'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...plan.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WeeklyPlanRow(
                item: item,
                icon: _iconFor(item.key),
                color: _colorFor(context, item),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String key) => switch (key) {
    'calories' => Icons.local_fire_department,
    'protein' => Icons.egg_alt_outlined,
    'carbs' => Icons.grain,
    'fat' => Icons.opacity,
    'fiber' => Icons.eco_outlined,
    'sugar' => Icons.cake_outlined,
    'water' => Icons.water_drop,
    _ => Icons.circle_outlined,
  };

  Color _colorFor(BuildContext context, WeeklyPlanItem item) {
    final cs = Theme.of(context).colorScheme;
    if (item.isOverWeekly || item.isTodayOver) return cs.error;
    if (item.isClose) return const Color(0xFFE85D04);
    if (item.key == 'water') return FitColors.aqua;
    if (item.key == 'protein' || item.key == 'fiber') {
      return FitColors.successGreen;
    }
    return const Color(0xFFFFBA08);
  }

  void _showTargetDialog(
    BuildContext context,
    WidgetRef ref,
    WeeklyNutritionPlanState plan,
  ) {
    TextEditingController ctrl(String key) {
      return TextEditingController(text: plan.item(key).target.toString());
    }

    final calories = ctrl('calories');
    final protein = ctrl('protein');
    final carbs = ctrl('carbs');
    final fat = ctrl('fat');
    final fiber = ctrl('fiber');
    final sugar = ctrl('sugar');
    final water = ctrl('water');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Weekly Targets'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _weeklyTargetField(calories, 'Calories', 'kcal'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _weeklyTargetField(protein, 'Protein', 'g')),
                  const SizedBox(width: 10),
                  Expanded(child: _weeklyTargetField(carbs, 'Carbs', 'g')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _weeklyTargetField(fat, 'Fat', 'g')),
                  const SizedBox(width: 10),
                  Expanded(child: _weeklyTargetField(fiber, 'Fiber', 'g')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _weeklyTargetField(sugar, 'Sugar', 'g')),
                  const SizedBox(width: 10),
                  Expanded(child: _weeklyTargetField(water, 'Water', 'ml')),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(weeklyNutritionPlanProvider.notifier)
                  .updateTargets(
                    calories: int.tryParse(calories.text),
                    protein: int.tryParse(protein.text),
                    carbs: int.tryParse(carbs.text),
                    fat: int.tryParse(fat.text),
                    fiber: int.tryParse(fiber.text),
                    sugar: int.tryParse(sugar.text),
                    water: int.tryParse(water.text),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _weeklyTargetField(
    TextEditingController controller,
    String label,
    String suffix,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _WeeklyPlanRow extends StatelessWidget {
  final WeeklyPlanItem item;
  final IconData icon;
  final Color color;

  const _WeeklyPlanRow({
    required this.item,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final leftText = item.isLimit
        ? item.remaining >= 0
              ? '${item.amount(item.remaining)} left'
              : '${item.amount(item.remaining.abs())} over'
        : '${item.amount((item.target - item.consumed).clamp(0, item.target).toInt())} pending';
    final todayText = item.isLimit
        ? 'Today ${item.amount(item.todayConsumed)} / ${item.amount(item.adjustedTodayTarget)}'
        : 'Today ${item.amount(item.todayConsumed)}, avg ${item.amount(item.adjustedTodayTarget)}';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(150),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${item.amount(item.consumed)} / ${item.amount(item.target)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: item.isOverWeekly ? cs.error : cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHigh,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  leftText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: item.isOverWeekly ? cs.error : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  todayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: item.isTodayOver ? cs.error : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (item.adjustedNextDayTarget > 0) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Next day budget: ${item.amount(item.adjustedNextDayTarget)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class WeeklyBanner extends ConsumerWidget {
  const WeeklyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklyProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isOver = weekly.remainingBudget < 0;
    final statusColor = isOver
        ? colorScheme.error
        : weekly.isOnTrack
        ? const Color(0xFFFFBA08)
        : const Color(0xFFE85D04);
    final bannerColor = statusColor.withAlpha(20);
    final textColor = colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isOver
                    ? Icons.warning_amber_rounded
                    : weekly.isOnTrack
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s target: ${weekly.adjustedDailyTarget} kcal',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'This week: ${weekly.totalConsumed} / ${weekly.weeklyGoal} kcal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
              // Mini sparkline of the week
              SizedBox(
                width: 80,
                height: 32,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    values: weekly.days
                        .map((d) => d.calories.toDouble())
                        .toList(),
                    target: weekly.adjustedDailyTarget.toDouble(),
                    color: statusColor,
                    trackColor: colorScheme.outlineVariant.withAlpha(60),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Weekly progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: weekly.weeklyProgress.clamp(0.0, 1.0),
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(weekly.weeklyProgress * 100).toInt()}% of weekly budget',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: textColor.withAlpha(150),
                ),
              ),
              Text(
                '${weekly.remainingBudget.abs()} ${isOver ? "over" : "left"}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final double target;
  final Color color;
  final Color trackColor;

  _SparklinePainter({
    required this.values,
    required this.target,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxVal = values.fold<double>(target, (a, b) => a > b ? a : b) * 1.2;
    if (maxVal == 0) return;

    final stepX = size.width / (values.length - 1);

    // Target line
    final targetY = size.height - (target / maxVal * size.height);
    final targetPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, targetY),
      Offset(size.width, targetY),
      targetPaint,
    );

    // Sparkline path
    final path = Path();
    final fillPath = Path();
    bool started = false;

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxVal * size.height);
      if (!started) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Fill under the line
    fillPath.lineTo((values.length - 1) * stepX, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = color.withAlpha(30));

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots
    for (int i = 0; i < values.length; i++) {
      if (values[i] > 0) {
        final x = i * stepX;
        final y = size.height - (values[i] / maxVal * size.height);
        canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => true;
}

// ─── Fasting Card ────────────────────────────────────────────────────────────

class _FastingCard extends ConsumerWidget {
  const _FastingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fasting = ref.watch(fastingProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Intermittent Fasting',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (fasting.isFasting && fasting.startTime != null) ...[
              // Protocol selector (tap to change duration mid-fast)
              GestureDetector(
                onTap: () => _showDurationPicker(context, ref, fasting.target),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getProtocolLabel(fasting.target),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 18, color: cs.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ─── Start / End time row (editable) ───
              Row(
                children: [
                  Expanded(
                    child: _TimeChip(
                      label: 'FAST STARTED',
                      time: _formatDateTime(fasting.startTime!),
                      icon: Icons.play_circle_outline,
                      onTap: () => _pickTime(context, ref, isStart: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeChip(
                      label: 'FAST ENDS',
                      time: _formatDateTime(
                        fasting.startTime!.add(fasting.target),
                      ),
                      icon: Icons.flag_outlined,
                      onTap: null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _FastingReminderControls(),
              const SizedBox(height: 16),
            ],

            const RadialDial(),
            const SizedBox(height: 16),

            if (!fasting.isFasting) ...[
              _FastingStartSection(
                onStart: (minutes, {DateTime? startTime}) {
                  ref
                      .read(fastingProvider.notifier)
                      .startFasting(
                        durationMinutes: minutes,
                        startTime: startTime,
                      );
                  HapticFeedback.mediumImpact();
                },
              ),
            ] else ...[
              // End button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    ref.read(fastingProvider.notifier).stopFasting();
                    HapticFeedback.lightImpact();
                  },
                  child: Text(
                    fasting.isComplete ? 'Fast Complete - End' : 'End Fast',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _pickTime(context, ref, isStart: false),
                icon: const Icon(Icons.history, size: 16),
                label: const Text('I ended earlier'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDurationPicker(
    BuildContext context,
    WidgetRef ref,
    Duration current,
  ) {
    final presets = {
      '16:8': 960,
      '18:6': 1080,
      '20:4': 1200,
      '24h': 1440,
      '36h': 2160,
    };

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change Fasting Duration',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...presets.entries.map((e) {
                final isSelected = current.inMinutes == e.value;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  tileColor: isSelected ? cs.primary.withAlpha(20) : null,
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  title: Text(
                    e.key,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '${e.value ~/ 60}h fasting, ${24 - e.value ~/ 60}h eating${e.value > 1440 ? " (extended)" : ""}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  onTap: () {
                    ref.read(fastingProvider.notifier).changeDuration(e.value);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  String _getProtocolLabel(Duration target) {
    final hours = target.inHours;
    if (hours >= 24) return '${hours}h';
    final eating = 24 - hours;
    return '$hours:$eating';
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.day == now.day && dt.month == now.month;
    final isTomorrow = dt.day == now.day + 1 && dt.month == now.month;
    final isYesterday = dt.day == now.day - 1 && dt.month == now.month;

    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Today, $timeStr';
    if (isTomorrow) return 'Tomorrow, $timeStr';
    if (isYesterday) return 'Yesterday, $timeStr';
    return '${dt.day}/${dt.month}, $timeStr';
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref, {
    required bool isStart,
  }) async {
    final now = DateTime.now();

    if (isStart) {
      // Pick date first (last 5 days)
      final date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now.subtract(const Duration(days: 5)),
        lastDate: now,
        helpText: 'When did you start fasting?',
      );
      if (date == null || !context.mounted) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        helpText: 'Select start time',
      );
      if (time == null || !context.mounted) return;

      var start = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (start.isAfter(now)) return;

      ref.read(fastingProvider.notifier).editStartTime(start);
    } else {
      // End time
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        helpText: 'When did you stop fasting?',
      );
      if (time == null || !context.mounted) return;

      var endTime = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (endTime.isAfter(now)) {
        endTime = endTime.subtract(const Duration(days: 1));
      }

      ref.read(fastingProvider.notifier).stopFastingAt(endTime);
    }
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final VoidCallback? onTap;

  const _TimeChip({
    required this.label,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                if (onTap != null) ...[
                  const Spacer(),
                  Icon(Icons.edit, size: 12, color: cs.primary),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 14, color: cs.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FastingReminderControls extends ConsumerWidget {
  const _FastingReminderControls();

  static const _intervals = {
    30: '30m',
    60: '1h',
    90: '1.5h',
    120: '2h',
    180: '3h',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fasting = ref.watch(fastingProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = fasting.reminderInterval.inMinutes;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                fasting.remindersEnabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: fasting.remindersEnabled
                    ? cs.primary
                    : cs.onSurfaceVariant,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fasting alerts',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      fasting.remindersEnabled
                          ? 'Next in ${formatDurationShort(fasting.untilNextReminder)}'
                          : 'Paused',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: fasting.remindersEnabled,
                onChanged: (value) => ref
                    .read(fastingProvider.notifier)
                    .configureReminder(enabled: value),
              ),
            ],
          ),
          if (fasting.remindersEnabled) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _intervals.entries.map((entry) {
                final isSelected = selected == entry.key;
                return ChoiceChip(
                  selected: isSelected,
                  label: Text(entry.value),
                  avatar: isSelected ? const Icon(Icons.check, size: 16) : null,
                  onSelected: (_) => ref
                      .read(fastingProvider.notifier)
                      .configureReminder(intervalMinutes: entry.key),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _FastingStartSection extends StatefulWidget {
  final void Function(int minutes, {DateTime? startTime}) onStart;

  const _FastingStartSection({required this.onStart});

  @override
  State<_FastingStartSection> createState() => _FastingStartSectionState();
}

class _FastingStartSectionState extends State<_FastingStartSection> {
  int _selectedMinutes = AppConstants.defaultFastingMinutes;

  static const _presets = {
    '16:8': 960,
    '18:6': 1080,
    '20:4': 1200,
    '24h': 1440,
    '36h': 2160,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: _presets.entries.map((e) {
            final selected = _selectedMinutes == e.value;
            final cs = Theme.of(context).colorScheme;
            return GestureDetector(
              onTap: () => setState(() => _selectedMinutes = e.value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? cs.primary.withAlpha(25)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? cs.primary : cs.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  e.key,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        // Big start button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => widget.onStart(_selectedMinutes),
            child: Text(
              'Start ${formatDurationShort(Duration(minutes: _selectedMinutes))} Fast',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Started earlier
        TextButton.icon(
          onPressed: () => _pickPastStart(context),
          icon: const Icon(Icons.history, size: 16),
          label: const Text('I started earlier'),
        ),
      ],
    );
  }

  Future<void> _pickPastStart(BuildContext context) async {
    final now = DateTime.now();

    // Pick date (last 5 days)
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 5)),
      lastDate: now,
      helpText: 'Which day did you start?',
    );
    if (date == null || !context.mounted) return;

    // Pick time
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'What time did you start?',
    );
    if (time == null || !context.mounted) return;

    var start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (start.isAfter(now)) return;

    widget.onStart(_selectedMinutes, startTime: start);
  }
}

// ─── Calorie Card ────────────────────────────────────────────────────────────

class _CalorieCard extends ConsumerWidget {
  const _CalorieCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nutrition = ref.watch(nutritionProvider);
    final totalCalories = nutrition.totalCalories;
    final profile = ref.watch(profileProvider);
    final weekly = ref.watch(weeklyProvider);
    final fasting = ref.watch(fastingProvider);
    final colorScheme = Theme.of(context).colorScheme;
    // Daily quota = weekly goal / 7 (the real daily target)
    final dailyQuota = profile?.dailyQuota ?? AppConstants.dailyCalorieGoalKcal;
    final weeklyGoal = weekly.weeklyGoal;
    final progress = (totalCalories / dailyQuota).clamp(0.0, 1.0);
    final goalReached = totalCalories >= dailyQuota;
    final halfReached = totalCalories >= dailyQuota / 2;
    final isFasting = fasting.isFasting && !fasting.isComplete;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, color: colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nutrition Today',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (goalReached) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ],
                const SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    onTap: () => _showEditGoalDialog(context, ref, weeklyGoal),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalCalories / $dailyQuota kcal',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'This week: ${weekly.totalConsumed} / $weeklyGoal kcal',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _AnimatedProgressBar(
              progress: progress,
              color: goalReached
                  ? colorScheme.primary
                  : halfReached
                  ? const Color(0xFFE85D04)
                  : colorScheme.error,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            if (halfReached && !goalReached) ...[
              const SizedBox(height: 4),
              Text(
                'Halfway there!',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFE85D04),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 14),
            _MacroDashboard(nutrition: nutrition),
            if (isFasting) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.error.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 14, color: colorScheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You\'re currently fasting. Adding calories will break your fast.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (!isFasting) ...[
              Row(
                children: AppConstants.calorieQuickAdd
                    .map(
                      (amount) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilledButton.tonal(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(calorieProvider.notifier)
                                  .addCalories(amount);
                              _checkMilestone(
                                context,
                                totalCalories + amount,
                                dailyQuota,
                              );
                            },
                            child: Text('+$amount'),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilledButton.tonalIcon(
                        onPressed: () => _showAddNutritionDialog(
                          context,
                          ref,
                          totalCalories,
                          dailyQuota,
                        ),
                        icon: const Icon(Icons.restaurant_menu, size: 18),
                        label: const Text('Add Food'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showEditNutritionDialog(context, ref, nutrition),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Food locked during fast'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _checkMilestone(BuildContext context, int newTotal, int goal) {
    if (newTotal >= goal && newTotal - goal < 500) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calorie goal reached!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showEditGoalDialog(
    BuildContext context,
    WidgetRef ref,
    int currentWeekly,
  ) {
    final controller = TextEditingController(text: currentWeekly.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Weekly Calorie Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Weekly budget (kcal)',
                hintText: 'e.g. 7500',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setDialogState) {
                final v = int.tryParse(controller.text);
                final daily = v != null && v > 0 ? (v / 7).round() : 0;
                controller.addListener(() => setDialogState(() {}));
                return Text(
                  daily > 0 ? 'That\'s ~$daily kcal/day' : '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                ref
                    .read(profileProvider.notifier)
                    .updateGoals(
                      weeklyCalorieGoal: value,
                      calorieGoal: (value / 7).round(),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddNutritionDialog(
    BuildContext context,
    WidgetRef ref,
    int currentTotal,
    int goal,
  ) {
    final labelCtrl = TextEditingController();
    final caloriesCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final fiberCtrl = TextEditingController();
    final sugarCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Food'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Food name',
                  hintText: 'e.g. Paneer bowl',
                  prefixIcon: Icon(Icons.restaurant_menu),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _nutritionField(
                controller: caloriesCtrl,
                label: 'Calories',
                suffix: 'kcal',
                icon: Icons.local_fire_department,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _nutritionField(
                      controller: proteinCtrl,
                      label: 'Protein',
                      suffix: 'g',
                      icon: Icons.egg_alt_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _nutritionField(
                      controller: carbsCtrl,
                      label: 'Carbs',
                      suffix: 'g',
                      icon: Icons.grain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _nutritionField(
                      controller: fatCtrl,
                      label: 'Fat',
                      suffix: 'g',
                      icon: Icons.opacity,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _nutritionField(
                      controller: fiberCtrl,
                      label: 'Fiber',
                      suffix: 'g',
                      icon: Icons.eco_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _nutritionField(
                controller: sugarCtrl,
                label: 'Sugar',
                suffix: 'g',
                icon: Icons.cake_outlined,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(caloriesCtrl.text);
              if (value != null && value > 0) {
                ref
                    .read(nutritionProvider.notifier)
                    .addNutrition(
                      label: labelCtrl.text,
                      calories: value,
                      proteinGrams: int.tryParse(proteinCtrl.text) ?? 0,
                      carbsGrams: int.tryParse(carbsCtrl.text) ?? 0,
                      fatGrams: int.tryParse(fatCtrl.text) ?? 0,
                      fiberGrams: int.tryParse(fiberCtrl.text) ?? 0,
                      sugarGrams: int.tryParse(sugarCtrl.text) ?? 0,
                    );
                Navigator.pop(ctx);
                _checkMilestone(context, currentTotal + value, goal);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditNutritionDialog(
    BuildContext context,
    WidgetRef ref,
    NutritionState nutrition,
  ) {
    final caloriesCtrl = TextEditingController(
      text: nutrition.totalCalories.toString(),
    );
    final proteinCtrl = TextEditingController(
      text: nutrition.proteinGrams.toString(),
    );
    final carbsCtrl = TextEditingController(
      text: nutrition.carbsGrams.toString(),
    );
    final fatCtrl = TextEditingController(text: nutrition.fatGrams.toString());
    final fiberCtrl = TextEditingController(
      text: nutrition.fiberGrams.toString(),
    );
    final sugarCtrl = TextEditingController(
      text: nutrition.sugarGrams.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Today\'s Nutrition'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _nutritionField(
                controller: caloriesCtrl,
                label: 'Calories',
                suffix: 'kcal',
                icon: Icons.local_fire_department,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _nutritionField(
                      controller: proteinCtrl,
                      label: 'Protein',
                      suffix: 'g',
                      icon: Icons.egg_alt_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _nutritionField(
                      controller: carbsCtrl,
                      label: 'Carbs',
                      suffix: 'g',
                      icon: Icons.grain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _nutritionField(
                      controller: fatCtrl,
                      label: 'Fat',
                      suffix: 'g',
                      icon: Icons.opacity,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _nutritionField(
                      controller: fiberCtrl,
                      label: 'Fiber',
                      suffix: 'g',
                      icon: Icons.eco_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _nutritionField(
                controller: sugarCtrl,
                label: 'Sugar',
                suffix: 'g',
                icon: Icons.cake_outlined,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(caloriesCtrl.text);
              if (value != null && value >= 0) {
                ref
                    .read(nutritionProvider.notifier)
                    .setNutrition(
                      calories: value,
                      proteinGrams: int.tryParse(proteinCtrl.text) ?? 0,
                      carbsGrams: int.tryParse(carbsCtrl.text) ?? 0,
                      fatGrams: int.tryParse(fatCtrl.text) ?? 0,
                      fiberGrams: int.tryParse(fiberCtrl.text) ?? 0,
                      sugarGrams: int.tryParse(sugarCtrl.text) ?? 0,
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _nutritionField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required IconData icon,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// ─── Water Card ──────────────────────────────────────────────────────────────

class _WaterCard extends ConsumerWidget {
  const _WaterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waterMl = ref.watch(waterProvider);
    final profile = ref.watch(profileProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final goal = profile?.waterGoalMl ?? AppConstants.dailyWaterGoalMl;
    final progress = (waterMl / goal).clamp(0.0, 1.0);
    final goalReached = waterMl >= goal;
    final glasses = (waterMl / 250).floor();
    final totalGlasses = (goal / 250).ceil();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Water',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (goalReached) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () => _showEditGoalDialog(context, ref, goal),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${waterMl}ml / ${goal}ml',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Glass indicators
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(totalGlasses, (i) {
                final filled = i < glasses;
                return Icon(
                  Icons.water_drop,
                  size: 18,
                  color: filled
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                );
              }),
            ),
            const SizedBox(height: 12),
            _AnimatedProgressBar(
              progress: progress,
              color: goalReached
                  ? const Color(0xFFFFBA08)
                  : colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(waterProvider.notifier)
                      .addWater(AppConstants.waterStepMl);
                  final newTotal = waterMl + AppConstants.waterStepMl;
                  if (newTotal >= goal && waterMl < goal) {
                    HapticFeedback.heavyImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Water goal reached! Stay hydrated!'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add),
                label: Text('+${AppConstants.waterStepMl}ml'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGoalDialog(
    BuildContext context,
    WidgetRef ref,
    int currentGoal,
  ) {
    final controller = TextEditingController(text: currentGoal.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Water Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Daily water goal (ml)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                ref
                    .read(profileProvider.notifier)
                    .updateGoals(waterGoalMl: value);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─── Weight Card ─────────────────────────────────────────────────────────────

class _WeightCard extends ConsumerWidget {
  const _WeightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(weightProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final latestWeight = entries.isNotEmpty
        ? '${entries.last.weight.toStringAsFixed(1)} kg'
        : '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_weight_outlined,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Weight',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  latestWeight,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const WeightChart(),
            const SizedBox(height: 12),
            Center(
              child: FilledButton.tonalIcon(
                onPressed: () => _showWeightDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Log Weight'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeightDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Weight'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Weight (kg)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0) {
                ref.read(weightProvider.notifier).logWeight(value);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Progress Bar ───────────────────────────────────────────────────

class _AnimatedProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final Color backgroundColor;

  const _AnimatedProgressBar({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            backgroundColor: backgroundColor,
            color: color,
          ),
        );
      },
    );
  }
}

// ─── Net Calories Banner ─────────────────────────────────────────────────────

class _NetCaloriesBanner extends ConsumerWidget {
  const _NetCaloriesBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalCalories = ref.watch(calorieProvider);
    final activity = ref.watch(activityProvider);
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final net = totalCalories - activity.totalBurned;
    final dailyQuota = profile?.dailyQuota ?? 2000;
    final remaining = dailyQuota - net;
    final isOver = remaining < 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _netStat(context, 'Eaten', '$totalCalories', cs.error),
              Text(
                '-',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 18),
              ),
              _netStat(
                context,
                'Burned',
                '${activity.totalBurned}',
                cs.primary,
              ),
              Text(
                '=',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 18),
              ),
              _netStat(context, 'Net', '$net', isOver ? cs.error : cs.primary),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: dailyQuota > 0 ? (net / dailyQuota).clamp(0.0, 1.0) : 0,
              minHeight: 4,
              backgroundColor: cs.surfaceContainerHighest,
              color: isOver ? cs.error : cs.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isOver
                ? '${remaining.abs()} kcal over your net goal'
                : '$remaining kcal remaining (net)',
            style: TextStyle(
              fontSize: 11,
              color: isOver ? cs.error : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _netStat(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontFeatures: const [FontFeature.tabularFigures()],
            color: color,
          ),
        ),
        Text(
          'kcal',
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Steps Card ──────────────────────────────────────────────────────────────

class _StepsCard extends ConsumerWidget {
  const _StepsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    const stepsGoal = 10000;
    final progress = (activity.steps / stepsGoal).clamp(0.0, 1.0);
    final distanceKm = (activity.steps * 0.00075);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_walk, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Steps',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (activity.steps >= stepsGoal) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, color: cs.primary, size: 20),
                ],
                const Spacer(),
                Text(
                  '${activity.steps} / $stepsGoal',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AnimatedProgressBar(
              progress: progress,
              color: cs.primary,
              backgroundColor: cs.surfaceContainerHighest,
            ),
            const SizedBox(height: 8),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat(
                  context,
                  '${distanceKm.toStringAsFixed(1)} km',
                  'Distance',
                ),
                _miniStat(context, '${activity.stepCalories} kcal', 'Burned'),
                _miniStat(
                  context,
                  '${(activity.steps / 1312).toStringAsFixed(0)} min',
                  'Walking time',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: FilledButton.icon(
                onPressed: () => _showStepsInput(context, ref, activity.steps),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Enter Steps'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(BuildContext context, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ],
    );
  }

  void _showStepsInput(BuildContext context, WidgetRef ref, int current) {
    final controller = TextEditingController(
      text: current > 0 ? current.toString() : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Steps'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Total steps today',
                hintText: 'e.g. 8500',
                prefixIcon: Icon(Icons.directions_walk),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check Google Fit, Apple Health, or your\nfitness band for today\'s step count',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null && v >= 0) {
                ref.read(activityProvider.notifier).updateSteps(v);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─── Activity Card (Exercise Logger) ─────────────────────────────────────────

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fitness_center, color: cs.tertiary),
                const SizedBox(width: 8),
                Text(
                  'Exercise',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${activity.activityCalories} kcal burned',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (activity.activities.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...activity.activities.map(
                (a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getEmoji(a.name),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(a.name, style: theme.textTheme.bodyMedium),
                      ),
                      Text(
                        '${a.minutes} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${a.caloriesBurned} kcal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Center(
              child: FilledButton.tonalIcon(
                onPressed: () => _showAddActivity(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Log Exercise'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmoji(String name) {
    for (final preset in activityPresets) {
      if (preset.name == name) return preset.icon;
    }
    return '🏃';
  }

  void _showAddActivity(BuildContext context, WidgetRef ref) {
    final minutesCtrl = TextEditingController(text: '30');
    ActivityPreset selected = activityPresets[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final profile = ref.read(profileProvider);
          final weightKg = profile?.weightKg ?? 70;
          final mins = int.tryParse(minutesCtrl.text) ?? 30;
          final estBurn = (selected.met * weightKg * (mins / 60)).round();

          return AlertDialog(
            title: const Text('Log Exercise'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Activity grid
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: activityPresets.map((preset) {
                      final isSelected = selected.name == preset.name;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selected = preset),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withAlpha(25)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '${preset.icon} ${preset.name}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: minutesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 16,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Estimated burn: $estBurn kcal',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final mins = int.tryParse(minutesCtrl.text);
                  if (mins != null && mins > 0) {
                    ref
                        .read(activityProvider.notifier)
                        .addActivity(selected.name, mins, selected.met);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Sleep Card ──────────────────────────────────────────────────────────────

class _SleepCard extends ConsumerWidget {
  const _SleepCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final hasSleep = activity.sleepMinutes > 0;
    final hours = activity.sleepMinutes ~/ 60;
    final mins = activity.sleepMinutes % 60;

    // Sleep quality color
    Color qualityColor;
    String qualityLabel;
    if (activity.sleepMinutes >= 420) {
      qualityColor = cs.primary;
      qualityLabel = 'Great';
    } else if (activity.sleepMinutes >= 360) {
      qualityColor = const Color(0xFFE85D04);
      qualityLabel = 'Okay';
    } else if (activity.sleepMinutes > 0) {
      qualityColor = cs.error;
      qualityLabel = 'Low';
    } else {
      qualityColor = cs.onSurfaceVariant;
      qualityLabel = '';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bedtime, color: cs.secondary),
                const SizedBox(width: 8),
                Text(
                  'Sleep',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (hasSleep)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: qualityColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      qualityLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: qualityColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (hasSleep) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _sleepStat(
                    context,
                    activity.bedtime,
                    'Bedtime',
                    Icons.nights_stay,
                    cs.secondary,
                  ),
                  _sleepStat(
                    context,
                    activity.wakeTime,
                    'Wake up',
                    Icons.wb_sunny,
                    cs.primary,
                  ),
                  _sleepStat(
                    context,
                    '${hours}h ${mins}m',
                    'Duration',
                    Icons.hourglass_bottom,
                    qualityColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Sleep bar (target: 8h = 480 min)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (activity.sleepMinutes / 480).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: qualityColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                activity.sleepMinutes >= 480
                    ? 'Target 8h reached!'
                    : '${((480 - activity.sleepMinutes) / 60).toStringAsFixed(1)}h short of 8h target',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ] else
              Center(
                child: Text(
                  'No sleep logged yet',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 12),
            Center(
              child: FilledButton.tonalIcon(
                onPressed: () => _showSleepInput(context, ref),
                icon: Icon(hasSleep ? Icons.edit : Icons.add, size: 18),
                label: Text(hasSleep ? 'Edit Sleep' : 'Log Sleep'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sleepStat(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ],
    );
  }

  void _showSleepInput(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();

    // Pick bedtime
    final bedtime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 0),
      helpText: 'When did you go to bed?',
    );
    if (bedtime == null || !context.mounted) return;

    // Pick wake time
    final wakeTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: 0),
      helpText: 'When did you wake up?',
    );
    if (wakeTime == null || !context.mounted) return;

    // Calculate duration
    var bedMinutes = bedtime.hour * 60 + bedtime.minute;
    var wakeMinutes = wakeTime.hour * 60 + wakeTime.minute;
    var duration = wakeMinutes - bedMinutes;
    if (duration <= 0) duration += 24 * 60; // overnight
    // Cap at 16 hours
    if (duration > 16 * 60) duration = 16 * 60;

    ref
        .read(activityProvider.notifier)
        .updateSleep(
          bedtime:
              '${bedtime.hour.toString().padLeft(2, '0')}:${bedtime.minute.toString().padLeft(2, '0')}',
          wakeTime:
              '${wakeTime.hour.toString().padLeft(2, '0')}:${wakeTime.minute.toString().padLeft(2, '0')}',
          minutes: duration,
        );

    if (context.mounted) {
      final h = duration ~/ 60;
      final m = duration % 60;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sleep logged: ${h}h ${m}m'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
