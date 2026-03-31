import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../providers/activity_provider.dart';
import '../providers/calorie_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/water_provider.dart';
import '../providers/weekly_provider.dart';
import '../providers/weight_provider.dart';
import '../widgets/radial_dial.dart';
import '../widgets/weight_chart.dart';
import 'past_day_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FitGo'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Log Past Day',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PastDayLogScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _WeeklyBanner(),
          SizedBox(height: 16),
          _NetCaloriesBanner(),
          SizedBox(height: 16),
          _FastingCard(),
          SizedBox(height: 16),
          _CalorieCard(),
          SizedBox(height: 16),
          _StepsCard(),
          SizedBox(height: 16),
          _ActivityCard(),
          SizedBox(height: 16),
          _WaterCard(),
          SizedBox(height: 16),
          _SleepCard(),
          SizedBox(height: 16),
          _WeightCard(),
        ],
      ),
    );
  }
}

// ─── Weekly Banner ───────────────────────────────────────────────────────────

class _WeeklyBanner extends ConsumerWidget {
  const _WeeklyBanner();

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
                      'Weekly: ${weekly.totalConsumed} / ${weekly.weeklyGoal} kcal',
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
              tween: Tween(begin: 0, end: weekly.weeklyProgress.clamp(0.0, 1.0)),
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
    canvas.drawPath(
      fillPath,
      Paint()..color = color.withAlpha(30),
    );

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
        canvas.drawCircle(
          Offset(x, y),
          2.5,
          Paint()..color = color,
        );
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
                Text('Intermittent Fasting',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            if (fasting.isFasting && fasting.startTime != null) ...[
              // Protocol selector (tap to change duration mid-fast)
              GestureDetector(
                onTap: () => _showDurationPicker(context, ref, fasting.target),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
              const SizedBox(height: 16),
            ],

            const RadialDial(),
            const SizedBox(height: 16),

            if (!fasting.isFasting) ...[
              _FastingStartSection(
                onStart: (minutes, {DateTime? startTime}) {
                  ref.read(fastingProvider.notifier).startFasting(
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
                    fasting.isComplete ? 'Fast Complete — End' : 'End Fast',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
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

  void _showDurationPicker(BuildContext context, WidgetRef ref, Duration current) {
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
              Text('Change Fasting Duration',
                  style: Theme.of(ctx).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...presets.entries.map((e) {
                final isSelected = current.inMinutes == e.value;
                return ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  tileColor:
                      isSelected ? cs.primary.withAlpha(20) : null,
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  title: Text(e.key,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? cs.primary : cs.onSurface,
                      )),
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

    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Today, $timeStr';
    if (isTomorrow) return 'Tomorrow, $timeStr';
    if (isYesterday) return 'Yesterday, $timeStr';
    return '${dt.day}/${dt.month}, $timeStr';
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref,
      {required bool isStart}) async {
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

      var start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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

      var endTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
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
                Text(label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.5,
                    )),
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
                  child: Text(time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? cs.primary.withAlpha(25) : cs.surfaceContainerHighest,
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

    var start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (start.isAfter(now)) return;

    widget.onStart(_selectedMinutes, startTime: start);
  }
}

// ─── Calorie Card ────────────────────────────────────────────────────────────

class _CalorieCard extends ConsumerWidget {
  const _CalorieCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalCalories = ref.watch(calorieProvider);
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, color: colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Calories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (goalReached) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () => _showEditGoalDialog(context, ref, weeklyGoal),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$totalCalories / $dailyQuota kcal',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, size: 14, color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Weekly: ${weekly.totalConsumed} / $weeklyGoal kcal',
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
            if (isFasting) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        style: TextStyle(fontSize: 11, color: colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Quick add row
            Row(
              children: AppConstants.calorieQuickAdd.map(
                (amount) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilledButton.tonal(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.read(calorieProvider.notifier).addCalories(amount);
                        _checkMilestone(context, totalCalories + amount, dailyQuota);
                      },
                      child: Text('+$amount'),
                    ),
                  ),
                ),
              ).toList(),
            ),
            const SizedBox(height: 8),
            // Other + Edit row
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      onPressed: () => _showCustomCalorieDialog(context, ref, totalCalories, dailyQuota),
                      child: const Text('Other'),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditCaloriesDialog(context, ref, totalCalories),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Total'),
                    ),
                  ),
                ),
              ],
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

  void _showEditGoalDialog(BuildContext context, WidgetRef ref, int currentWeekly) {
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
                ref.read(profileProvider.notifier).updateGoals(
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

  void _showCustomCalorieDialog(BuildContext context, WidgetRef ref, int currentTotal, int goal) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Calories'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Calories (kcal)',
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
                ref.read(calorieProvider.notifier).addCalories(value);
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

  void _showEditCaloriesDialog(BuildContext context, WidgetRef ref, int currentTotal) {
    final controller = TextEditingController(text: currentTotal.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Today\'s Calories'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Total calories today',
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
              if (value != null && value >= 0) {
                ref.read(calorieProvider.notifier).setCalories(value);
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
                  Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
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
                      Icon(Icons.edit, size: 14, color: colorScheme.onSurfaceVariant),
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
              color: goalReached ? const Color(0xFFFFBA08) : colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(waterProvider.notifier).addWater(AppConstants.waterStepMl);
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

  void _showEditGoalDialog(BuildContext context, WidgetRef ref, int currentGoal) {
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
                ref.read(profileProvider.notifier).updateGoals(waterGoalMl: value);
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
    final latestWeight =
        entries.isNotEmpty ? '${entries.last.weight.toStringAsFixed(1)} kg' : '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_weight_outlined, color: colorScheme.tertiary),
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
              Text('−', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 18)),
              _netStat(context, 'Burned', '${activity.totalBurned}', cs.primary),
              Text('=', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 18)),
              _netStat(
                context,
                'Net',
                '$net',
                isOver ? cs.error : cs.primary,
              ),
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

  Widget _netStat(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
        Text('kcal',
            style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                Text('Steps',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (activity.steps >= stepsGoal) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, color: cs.primary, size: 20),
                ],
                const Spacer(),
                Text(
                  '${activity.steps} / $stepsGoal',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
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
                _miniStat(context, '${distanceKm.toStringAsFixed(1)} km', 'Distance'),
                _miniStat(context, '${activity.stepCalories} kcal', 'Burned'),
                _miniStat(context, '${(activity.steps / 1312).toStringAsFixed(0)} min',
                    'Walking time'),
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
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            )),
        Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ],
    );
  }

  void _showStepsInput(BuildContext context, WidgetRef ref, int current) {
    final controller = TextEditingController(
        text: current > 0 ? current.toString() : '');
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
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
                Text('Exercise',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  '${activity.activityCalories} kcal burned',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (activity.activities.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...activity.activities.map((a) => Padding(
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
                          child: Text(a.name,
                              style: theme.textTheme.bodyMedium),
                        ),
                        Text('${a.minutes} min',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        const SizedBox(width: 10),
                        Text('${a.caloriesBurned} kcal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: cs.tertiary,
                            )),
                      ],
                    ),
                  )),
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
                        onTap: () =>
                            setDialogState(() => selected = preset),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withAlpha(25)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
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
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_fire_department,
                            size: 16,
                            color: Theme.of(context).colorScheme.tertiary),
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
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final mins = int.tryParse(minutesCtrl.text);
                  if (mins != null && mins > 0) {
                    ref.read(activityProvider.notifier).addActivity(
                          selected.name,
                          mins,
                          selected.met,
                        );
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
                Text('Sleep',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (hasSleep)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: qualityColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(qualityLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: qualityColor,
                        )),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (hasSleep) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _sleepStat(context, activity.bedtime, 'Bedtime',
                      Icons.nights_stay, cs.secondary),
                  _sleepStat(context, activity.wakeTime, 'Wake up',
                      Icons.wb_sunny, cs.primary),
                  _sleepStat(context, '${hours}h ${mins}m', 'Duration',
                      Icons.hourglass_bottom, qualityColor),
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
                child: Text('No sleep logged yet',
                    style: TextStyle(color: cs.onSurfaceVariant)),
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

  Widget _sleepStat(BuildContext context, String value, String label,
      IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            )),
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

    ref.read(activityProvider.notifier).updateSleep(
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
