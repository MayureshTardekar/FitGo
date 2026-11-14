import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../providers/timer_provider.dart';
import '../components/fitgo_sheet.dart';
import '../theme/fitgo_tokens.dart';

Future<void> showFastingSheet(BuildContext context) {
  return showFitGoSheet(context, builder: (_) => const FastingSheet());
}

const _fastingPresets = {
  '16:8': 960,
  '18:6': 1080,
  '20:4': 1200,
  '24h': 1440,
  '36h': 2160,
};

class FastingSheet extends ConsumerStatefulWidget {
  const FastingSheet({super.key});

  @override
  ConsumerState<FastingSheet> createState() => _FastingSheetState();
}

class _FastingSheetState extends ConsumerState<FastingSheet> {
  int _selectedMinutes = AppConstants.defaultFastingMinutes;

  @override
  Widget build(BuildContext context) {
    final fasting = ref.watch(fastingProvider);
    final tokens = context.tokens;
    final theme = Theme.of(context);

    if (fasting.isFasting) {
      final remaining = fasting.target - fasting.elapsed;
      final overtime = remaining.isNegative;
      return FitGoSheet(
        title: 'Fasting',
        subtitle:
            '${_protocolLabel(fasting.target)} · started ${_timeLabel(fasting.startTime)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              overtime
                  ? 'Goal reached'
                  : '${formatDurationShort(remaining)} left',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: FitGoSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fasting.progress,
                minHeight: 8,
                backgroundColor: tokens.surfaceMuted,
                color: tokens.aqua,
              ),
            ),
            const SizedBox(height: FitGoSpacing.md),
            Text(
              overtime
                  ? 'You are ${formatDurationShort(fasting.overtime)} past your target.'
                  : 'Elapsed ${formatDurationShort(fasting.elapsed)} of ${formatDurationShort(fasting.target)}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: FitGoSpacing.lg),
            Text(
              'Change duration',
              style: theme.textTheme.labelLarge?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: FitGoSpacing.xs),
            Wrap(
              spacing: FitGoSpacing.xs,
              runSpacing: FitGoSpacing.xs,
              children: [
                for (final entry in _fastingPresets.entries)
                  ChoiceChip(
                    label: Text(entry.key),
                    selected: fasting.target.inMinutes == entry.value,
                    onSelected: (_) {
                      ref
                          .read(fastingProvider.notifier)
                          .changeDuration(entry.value);
                    },
                  ),
              ],
            ),
            const SizedBox(height: FitGoSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: () {
                  ref.read(fastingProvider.notifier).stopFasting();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.stop_rounded),
                label: const Text('End fast'),
              ),
            ),
          ],
        ),
      );
    }

    return FitGoSheet(
      title: 'Start a fast',
      subtitle: 'Choose a window. Only the Fasting row changes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: FitGoSpacing.xs,
            runSpacing: FitGoSpacing.xs,
            children: [
              for (final entry in _fastingPresets.entries)
                ChoiceChip(
                  label: Text(entry.key),
                  selected: _selectedMinutes == entry.value,
                  onSelected: (_) =>
                      setState(() => _selectedMinutes = entry.value),
                ),
            ],
          ),
          const SizedBox(height: FitGoSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                ref
                    .read(fastingProvider.notifier)
                    .startFasting(durationMinutes: _selectedMinutes);
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                'Start ${formatDurationShort(Duration(minutes: _selectedMinutes))} fast',
              ),
            ),
          ),
          const SizedBox(height: FitGoSpacing.xs),
          Center(
            child: TextButton.icon(
              onPressed: _pickEarlierStart,
              icon: const Icon(Icons.history_rounded),
              label: const Text('I started earlier'),
            ),
          ),
        ],
      ),
    );
  }

  String _protocolLabel(Duration target) {
    final hours = target.inHours;
    if (hours >= 24) return '${hours}h fast';
    return '$hours:${24 - hours}';
  }

  String _timeLabel(DateTime? time) {
    if (time == null) return 'just now';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickEarlierStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 2)),
      lastDate: now,
      helpText: 'When did you start fasting?',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Start time',
    );
    if (time == null || !mounted) return;

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (start.isAfter(now)) return;

    ref
        .read(fastingProvider.notifier)
        .startFasting(durationMinutes: _selectedMinutes, startTime: start);
    if (mounted) Navigator.of(context).pop();
  }
}
