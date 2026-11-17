import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/units.dart';
import '../../providers/activity_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/units_provider.dart';
import '../../providers/weight_provider.dart';
import '../../widgets/weight_chart.dart';
import '../components/fitgo_sheet.dart';
import '../theme/fitgo_tokens.dart';

Future<void> showActivitySheet(BuildContext context) {
  return showFitGoSheet(context, builder: (_) => const ActivitySheet());
}

Future<void> showSleepSheet(BuildContext context) {
  return showFitGoSheet(context, builder: (_) => const SleepSheet());
}

Future<void> showWeightSheet(BuildContext context) {
  return showFitGoSheet(context, builder: (_) => const WeightSheet());
}

class ActivitySheet extends ConsumerWidget {
  const ActivitySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityProvider);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    const goal = 10000;
    final progress = (activity.steps / goal).clamp(0.0, 1.0);
    final distance = activity.steps * 0.00075;

    return FitGoSheet(
      title: 'Activity',
      subtitle: 'Steps and exercise for today.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${activity.steps}',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: FitGoSpacing.xxs),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/ $goal steps',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FitGoSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: tokens.surfaceMuted,
              color: tokens.mint,
            ),
          ),
          const SizedBox(height: FitGoSpacing.xs),
          Text(
            '${distance.toStringAsFixed(1)} km · ${activity.stepCalories} kcal from steps',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: FitGoSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editSteps(context, ref, activity.steps),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit steps'),
                ),
              ),
              const SizedBox(width: FitGoSpacing.sm),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _logExercise(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Exercise'),
                ),
              ),
            ],
          ),
          const SizedBox(height: FitGoSpacing.lg),
          Text(
            'Exercise',
            style: theme.textTheme.titleMedium?.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: FitGoSpacing.xs),
          if (activity.activities.isEmpty)
            Text(
              'No exercise logged today.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            )
          else
            for (final item in activity.activities)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.fitness_center, color: tokens.ember),
                title: Text(item.name),
                subtitle: Text('${item.minutes} min'),
                trailing: Text(
                  '${item.caloriesBurned} kcal',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          if (activity.activityCalories > 0)
            Padding(
              padding: const EdgeInsets.only(top: FitGoSpacing.xs),
              child: Text(
                '${activity.totalBurned} kcal burned in total today.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _editSteps(BuildContext context, WidgetRef ref, int current) {
    final controller = TextEditingController(
      text: current > 0 ? '$current' : '',
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Steps today'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Total steps',
            hintText: 'e.g. 8500',
            prefixIcon: Icon(Icons.directions_walk),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0) return;
              ref.read(activityProvider.notifier).updateSteps(value);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _logExercise(BuildContext context, WidgetRef ref) {
    final minutes = TextEditingController(text: '30');
    var selected = activityPresets.first;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final weight = ref.read(profileProvider)?.weightKg ?? 70;
          final mins = int.tryParse(minutes.text.trim()) ?? 30;
          final burn = (selected.met * weight * (mins / 60)).round();

          return AlertDialog(
            title: const Text('Log exercise'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: FitGoSpacing.xs,
                    runSpacing: FitGoSpacing.xs,
                    children: [
                      for (final preset in activityPresets)
                        ChoiceChip(
                          label: Text('${preset.icon} ${preset.name}'),
                          selected: selected.name == preset.name,
                          onSelected: (_) =>
                              setDialogState(() => selected = preset),
                        ),
                    ],
                  ),
                  const SizedBox(height: FitGoSpacing.md),
                  TextField(
                    controller: minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      suffixText: 'min',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: FitGoSpacing.sm),
                  Text(
                    'Estimated burn: $burn kcal',
                    style: Theme.of(dialogContext).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = int.tryParse(minutes.text.trim());
                  if (value == null || value <= 0) return;
                  ref
                      .read(activityProvider.notifier)
                      .addActivity(selected.name, value, selected.met);
                  Navigator.of(dialogContext).pop();
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

class SleepSheet extends ConsumerWidget {
  const SleepSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityProvider);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final hasSleep = activity.sleepMinutes > 0;
    final hours = activity.sleepMinutes ~/ 60;
    final minutes = activity.sleepMinutes % 60;

    return FitGoSheet(
      title: 'Sleep',
      subtitle: 'Bedtime, wake time, and duration.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasSleep) ...[
            Text(
              '${hours}h ${minutes}m',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: FitGoSpacing.xxs),
            Text(
              '${activity.bedtime} → ${activity.wakeTime}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: FitGoSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (activity.sleepMinutes / 480).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: tokens.surfaceMuted,
                color: tokens.aqua,
              ),
            ),
            const SizedBox(height: FitGoSpacing.xs),
            Text(
              activity.sleepMinutes >= 480
                  ? '8 hour target reached.'
                  : '${((480 - activity.sleepMinutes) / 60).toStringAsFixed(1)}h short of 8h.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ] else
            Text(
              'No sleep logged yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          const SizedBox(height: FitGoSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _logSleep(context, ref),
              icon: Icon(hasSleep ? Icons.edit_outlined : Icons.add),
              label: Text(hasSleep ? 'Edit sleep' : 'Log sleep'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logSleep(BuildContext context, WidgetRef ref) async {
    final bedtime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 0),
      helpText: 'Bedtime',
    );
    if (bedtime == null || !context.mounted) return;

    final wake = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
      helpText: 'Wake time',
    );
    if (wake == null || !context.mounted) return;

    final bedMinutes = bedtime.hour * 60 + bedtime.minute;
    final wakeMinutes = wake.hour * 60 + wake.minute;
    var duration = wakeMinutes - bedMinutes;
    if (duration <= 0) duration += 24 * 60;

    ref
        .read(activityProvider.notifier)
        .updateSleep(
          bedtime: _clock(bedtime),
          wakeTime: _clock(wake),
          minutes: duration,
        );
  }

  String _clock(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

class WeightSheet extends ConsumerWidget {
  const WeightSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(weightProvider);
    final units = ref.watch(unitSystemProvider);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final chartHeight = (MediaQuery.sizeOf(context).height * 0.34)
        .clamp(240.0, 320.0)
        .toDouble();
    final latest = entries.isNotEmpty
        ? units.formatWeight(entries.last.weight)
        : 'No weight logged';

    return FitGoSheet(
      title: 'Weight',
      subtitle: 'Trends stay on this device until they sync.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Latest', style: theme.textTheme.labelLarge?.copyWith(color: tokens.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: FitGoSpacing.xxs),
          Text(
            latest,
            style: theme.textTheme.displaySmall?.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: FitGoSpacing.md),
          WeightChart(height: chartHeight),
          const SizedBox(height: FitGoSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _logWeight(context, ref, units),
              icon: const Icon(Icons.add),
              label: const Text('Log weight'),
            ),
          ),
        ],
      ),
    );
  }

  void _logWeight(BuildContext context, WidgetRef ref, UnitSystem units) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log weight'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Weight',
            suffixText: units.weightLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              ref
                  .read(weightProvider.notifier)
                  .logWeight(units.weightToKg(value));
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
