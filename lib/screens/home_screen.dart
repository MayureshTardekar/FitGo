import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../core/units.dart';
import '../core/utils.dart';
import '../providers/activity_provider.dart';
import '../providers/calorie_provider.dart';
import '../providers/local_data_refresh.dart';
import '../providers/monthly_calorie_alert_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/sync_status_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/units_provider.dart';
import '../providers/water_provider.dart';
import '../providers/weekly_provider.dart';
import '../providers/weight_provider.dart';
import '../ui/components/fitgo_card.dart';
import '../ui/components/fitgo_log_feedback.dart';
import '../ui/components/fitgo_section_header.dart';
import '../ui/components/fitgo_sync_status_pill.dart';
import '../ui/theme/fitgo_tokens.dart';
import '../ui/today/fasting_sheet.dart';
import '../ui/today/health_sheets.dart';
import '../ui/today/meal_sheet.dart';

/// Today is a quick logbook: one calorie hero, three flat log rows, and a
/// small health section. Reviewing lives in Trends; settings live in Profile.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(
      fastingProvider.select(
        (state) => (signal: state.reminderSignal, active: state.isFasting),
      ),
      (previous, next) {
        if (previous?.signal == next.signal ||
            next.signal == 0 ||
            !next.active) {
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
      },
    );
    ref.watch(monthlyCalorieAlertProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Log a past day',
            onPressed: () => context.push('/past-day'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final storage = ref.read(localStorageProvider);
          await storage.syncWithCloud();
          refreshLocalDataProviders(ref);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            FitGoSpacing.md,
            FitGoSpacing.xs,
            FitGoSpacing.md,
            FitGoSpacing.xxxl + FitGoSpacing.xxl,
          ),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: FitGoSpacing.sm,
              runSpacing: FitGoSpacing.xs,
              children: [
                const SyncStatusPill(),
                Text(
                  DateFormat('EEE, d MMM').format(DateTime.now()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: FitGoSpacing.sm),
            const _CalorieHero(),
            const SizedBox(height: FitGoSpacing.sm),
            const _LogbookCard(),
            const SizedBox(height: FitGoSpacing.xl),
            const FitGoSectionHeader(title: 'Health'),
            const _HealthCard(),
          ],
        ),
      ),
    );
  }
}

class _CalorieHero extends ConsumerWidget {
  const _CalorieHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nutrition = ref.watch(nutritionProvider);
    final weekly = ref.watch(weeklyProvider);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final overToday = nutrition.remainingCalories < 0;
    final overWeek = weekly.remainingBudget < 0;
    final progress = nutrition.targets.calories > 0
        ? (nutrition.totalCalories / nutrition.targets.calories).clamp(0.0, 1.0)
        : 0.0;

    return FitGoCard(
      padding: const EdgeInsets.all(FitGoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.ember.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(FitGoRadii.input),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: tokens.emberDeep,
                ),
              ),
              const SizedBox(width: FitGoSpacing.sm),
              Expanded(
                child: Text(
                  overToday ? 'Over today’s budget' : 'Calories left today',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FitGoSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  '${nutrition.remainingCalories.abs()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: overToday
                        ? theme.colorScheme.error
                        : tokens.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: FitGoSpacing.xxs),
              Text(
                overToday ? 'kcal over' : 'kcal',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: FitGoSpacing.xxs),
          Text(
            overWeek
                ? '${weekly.remainingBudget.abs()} kcal over this week'
                : '${weekly.remainingBudget} kcal left this week',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: overWeek ? theme.colorScheme.error : tokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: FitGoSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: tokens.surfaceMuted,
              color: overToday ? theme.colorScheme.error : tokens.ember,
            ),
          ),
          const SizedBox(height: FitGoSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showMealSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log meal'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogbookCard extends StatelessWidget {
  const _LogbookCard();

  @override
  Widget build(BuildContext context) {
    return const FitGoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _MealsRow(),
          Divider(height: 1),
          _FastingRow(),
          Divider(height: 1),
          _WaterRow(),
        ],
      ),
    );
  }
}

class _MealsRow extends ConsumerWidget {
  const _MealsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      nutritionProvider.select(
        (state) => (count: state.entries.length, calories: state.totalCalories),
      ),
    );
    final subtitle = summary.count == 0
        ? 'Nothing logged yet'
        : '${summary.count} logged · ${summary.calories} kcal';

    return _TodayRow(
      icon: Icons.restaurant_menu_rounded,
      iconColor: context.tokens.emberDeep,
      title: 'Meals',
      subtitle: subtitle,
      onTap: () => showMealSheet(context),
    );
  }
}

class _FastingRow extends ConsumerWidget {
  const _FastingRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      fastingProvider.select((state) {
        final remaining = state.target - state.elapsed;
        return (
          active: state.isFasting,
          done: state.isComplete,
          minutes: remaining.inMinutes,
        );
      }),
    );

    final subtitle = !summary.active
        ? 'Tap to start a fast'
        : summary.done
        ? 'Goal reached'
        : '${formatDurationShort(Duration(minutes: summary.minutes.abs()))} left';

    return _TodayRow(
      icon: Icons.timer_outlined,
      iconColor: context.tokens.aqua,
      title: 'Fasting',
      subtitle: subtitle,
      onTap: () => showFastingSheet(context),
    );
  }
}

class _WaterRow extends ConsumerWidget {
  const _WaterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final water = ref.watch(waterProvider);
    final profile = ref.watch(profileProvider);
    final units = ref.watch(unitSystemProvider);
    final goal = profile?.waterGoalMl ?? AppConstants.dailyWaterGoalMl;
    final step = AppConstants.waterStepMl;

    return _TodayRow(
      icon: Icons.water_drop_outlined,
      iconColor: context.tokens.aqua,
      title: 'Water',
      subtitle:
          '${units.formatVolume(water.toDouble())} / '
          '${units.formatVolume(goal.toDouble())}',
      trailing: FilledButton.tonal(
        style: FilledButton.styleFrom(
          minimumSize: const Size(96, 44),
          padding: const EdgeInsets.symmetric(horizontal: FitGoSpacing.md),
        ),
        onPressed: () {
          final waterNotifier = ref.read(waterProvider.notifier);
          final messenger = ScaffoldMessenger.of(context);
          final status = savedLocallyLabel(ref.read(syncStatusProvider));
          waterNotifier.addWater(step);
          HapticFeedback.lightImpact();
          showLogSnackBar(
            messenger,
            message: 'Water logged',
            status: status,
            onUndo: () => waterNotifier.removeWater(step),
          );
        },
        child: Text('+${units.formatVolume(step.toDouble())}'),
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard();

  @override
  Widget build(BuildContext context) {
    return const FitGoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _ActivityRow(),
          Divider(height: 1),
          _SleepRow(),
          Divider(height: 1),
          _WeightRow(),
        ],
      ),
    );
  }
}

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      activityProvider.select(
        (state) => (steps: state.steps, burned: state.totalBurned),
      ),
    );

    return _TodayRow(
      icon: Icons.directions_walk_rounded,
      iconColor: context.tokens.mint,
      title: 'Activity',
      subtitle: '${summary.steps} steps · ${summary.burned} kcal burned',
      onTap: () => showActivitySheet(context),
    );
  }
}

class _SleepRow extends ConsumerWidget {
  const _SleepRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = ref.watch(
      activityProvider.select((state) => state.sleepMinutes),
    );
    final subtitle = minutes <= 0
        ? 'Not logged'
        : '${minutes ~/ 60}h ${minutes % 60}m · ${minutes >= 420
              ? 'Great'
              : minutes >= 360
              ? 'Okay'
              : 'Low'}';

    return _TodayRow(
      icon: Icons.bedtime_outlined,
      iconColor: context.tokens.aqua,
      title: 'Sleep',
      subtitle: subtitle,
      onTap: () => showSleepSheet(context),
    );
  }
}

class _WeightRow extends ConsumerWidget {
  const _WeightRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(weightProvider);
    final units = ref.watch(unitSystemProvider);
    final subtitle = entries.isEmpty
        ? 'Not logged'
        : units.formatWeight(entries.last.weight);

    return _TodayRow(
      icon: Icons.monitor_weight_outlined,
      iconColor: context.tokens.emberDeep,
      title: 'Weight',
      subtitle: subtitle,
      onTap: () => showWeightSheet(context),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // At large text sizes the trailing action needs its own line,
              // otherwise the title and button fight for a 320pt row.
              final stackTrailing =
                  trailing != null &&
                  (textScale > 1.3 || constraints.maxWidth < 340);

              final details = Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(FitGoRadii.input),
                    ),
                    child: Icon(icon, color: iconColor, size: 21),
                  ),
                  const SizedBox(width: FitGoSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!stackTrailing) ...[
                    const SizedBox(width: FitGoSpacing.xs),
                    if (trailing != null)
                      trailing!
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: tokens.textSecondary,
                      ),
                  ],
                ],
              );

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FitGoSpacing.md,
                  vertical: FitGoSpacing.sm,
                ),
                child: stackTrailing
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          details,
                          const SizedBox(height: FitGoSpacing.xs),
                          trailing!,
                        ],
                      )
                    : details,
              );
            },
          ),
        ),
      ),
    );
  }
}
