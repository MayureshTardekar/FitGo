import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/units.dart';
import '../../models/goal_plan.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../components/fitgo_card.dart';
import '../components/fitgo_sheet.dart';
import '../theme/fitgo_tokens.dart';

Future<void> showGoalPlannerSheet(
  BuildContext context, {
  required UserProfile profile,
  required UnitSystem units,
}) {
  return showFitGoSheet(
    context,
    builder: (_) => GoalPlannerSheet(profile: profile, units: units),
  );
}

class GoalPlannerSheet extends ConsumerStatefulWidget {
  const GoalPlannerSheet({
    super.key,
    required this.profile,
    required this.units,
  });

  final UserProfile profile;
  final UnitSystem units;

  @override
  ConsumerState<GoalPlannerSheet> createState() => _GoalPlannerSheetState();
}

class _GoalPlannerSheetState extends ConsumerState<GoalPlannerSheet> {
  late final TextEditingController _targetCtrl;
  late DateTime _targetDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.profile.goalTargetDateValue;
    _targetDate =
        existing != null &&
            existing.isAfter(DateTime.now().subtract(const Duration(days: 1)))
        ? existing
        : DateTime.now().add(const Duration(days: 84));

    final initialTarget = widget.profile.targetWeightKg > 0
        ? widget.profile.targetWeightKg
        : switch (widget.profile.weightGoal) {
            'lose' => (widget.profile.weightKg - 5).clamp(30.0, 300.0),
            'gain' => (widget.profile.weightKg + 5).clamp(30.0, 300.0),
            _ => widget.profile.weightKg,
          };

    _targetCtrl = TextEditingController(
      text: widget.units.weightFromKg(initialTarget).toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  double? get _targetKg {
    final value = double.tryParse(_targetCtrl.text.trim());
    if (value == null) return null;
    return widget.units.weightToKg(value);
  }

  GoalPlan? get _plan {
    final targetKg = _targetKg;
    if (targetKg == null || targetKg < 30 || targetKg > 300) return null;
    return GoalPlan.calculate(
      currentWeightKg: widget.profile.weightKg,
      targetWeightKg: targetKg,
      targetDate: _targetDate,
      tdee: widget.profile.tdee,
      today: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final plan = _plan;

    return FitGoSheet(
      title: 'Plan your goal',
      subtitle:
          'Choose a target weight and date. FitGo turns it into a daily '
          'calorie and water target.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CurrentWeight(
            weight: widget.profile.weightKg,
            units: widget.units,
            tdee: widget.profile.tdee,
          ),
          const SizedBox(height: FitGoSpacing.lg),
          TextField(
            controller: _targetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Goal weight',
              suffixText: widget.units.weightLabel,
              prefixIcon: const Icon(Icons.flag_outlined),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: FitGoSpacing.md),
          InkWell(
            borderRadius: BorderRadius.circular(FitGoRadii.input),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Target date',
                prefixIcon: Icon(Icons.event_outlined),
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('d MMM yyyy').format(_targetDate),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: FitGoSpacing.lg),
          if (plan == null)
            Text(
              'Enter a goal weight between 30 and 300 kg.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else ...[
            _PlanPreview(plan: plan, units: widget.units),
            const SizedBox(height: FitGoSpacing.sm),
            _SafetyNote(plan: plan),
          ],
          const SizedBox(height: FitGoSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: FitGoSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: plan == null || _saving ? null : _apply,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Use this plan'),
                ),
              ),
            ],
          ),
          const SizedBox(height: FitGoSpacing.xs),
          Text(
            'Estimates use 7,700 kcal per kg of body-weight change. '
            'Water is based on your current weight and never below '
            '${GoalPlan.minDailyWaterMl ~/ 1000} L/day. Actual progress varies '
            'with water, hormones, and activity.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day + 1);
    final lastDate = DateTime(now.year + 5, now.month, now.day);
    final initial = _targetDate.isBefore(firstDate)
        ? firstDate
        : _targetDate.isAfter(lastDate)
        ? lastDate
        : _targetDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'When do you want to reach this weight?',
    );
    if (picked == null || !mounted) return;
    setState(() => _targetDate = picked);
  }

  Future<void> _apply() async {
    final plan = _plan;
    if (plan == null || _saving) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    await ref
        .read(profileProvider.notifier)
        .updateGoals(
          targetWeightKg: plan.targetWeightKg,
          goalTargetDate: DateFormat('yyyy-MM-dd').format(plan.targetDate),
          weightGoal: plan.goalType,
          calorieGoal: plan.dailyCalories,
          weeklyCalorieGoal: plan.dailyCalories * 7,
          waterGoalMl: plan.dailyWaterMl,
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Goal plan saved on this device.')),
    );
  }
}

class _CurrentWeight extends StatelessWidget {
  const _CurrentWeight({
    required this.weight,
    required this.units,
    required this.tdee,
  });

  final double weight;
  final UnitSystem units;
  final int tdee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return FitGoCard(
      color: tokens.surfaceMuted,
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
                  Icons.monitor_weight_outlined,
                  color: tokens.emberDeep,
                ),
              ),
              const SizedBox(width: FitGoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current weight',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                    Text(
                      units.formatWeight(weight),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FitGoSpacing.sm),
          Wrap(
            spacing: FitGoSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Estimated burn',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              Text(
                '$tdee kcal/day',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanPreview extends StatelessWidget {
  const _PlanPreview({required this.plan, required this.units});

  final GoalPlan plan;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final pace = plan.isMaintain || plan.weeklyKgChange.abs() < 0.01
        ? 'Maintaining'
        : '${plan.weeklyKgChange.abs().toStringAsFixed(2)} kg/week '
              '${plan.isLoss ? 'lost' : 'gained'}';

    return FitGoCard(
      color: tokens.surfaceMuted,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PlanStat(
                  label: 'Daily intake',
                  value: '${plan.dailyCalories} kcal',
                ),
              ),
              Container(width: 1, height: 42, color: tokens.border),
              Expanded(
                child: _PlanStat(
                  label: 'Daily water',
                  value: units.formatVolume(plan.dailyWaterMl.toDouble()),
                ),
              ),
            ],
          ),
          const Divider(height: FitGoSpacing.xl),
          _PlanRow(
            label: 'Goal',
            value:
                '${units.formatWeight(plan.targetWeightKg)} by '
                '${DateFormat('d MMM yyyy').format(plan.targetDate)}',
          ),
          _PlanRow(
            label: plan.isMaintain
                ? 'Daily balance'
                : plan.isLoss
                ? 'Daily deficit'
                : 'Daily surplus',
            value: '${plan.dailyDelta.abs()} kcal',
          ),
          _PlanRow(label: 'Expected pace', value: pace),
          if (!plan.isMaintain)
            _PlanRow(
              label: 'Total change',
              value: '${plan.totalKgChange.abs().toStringAsFixed(1)} kg',
            ),
        ],
      ),
    );
  }
}

class _PlanStat extends StatelessWidget {
  const _PlanStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: FitGoSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote({required this.plan});

  final GoalPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    final String message;
    if (plan.isLoss && plan.dailyDelta == 0) {
      message =
          'Your estimated burn is already close to the safe minimum, so '
          'FitGo cannot create a safe deficit. Add activity or talk to a '
          'health professional.';
    } else if (plan.requestedDateTooAggressive) {
      final limit = plan.isLoss
          ? GoalPlan.maxDailyDeficit
          : GoalPlan.maxDailySurplus;
      message =
          'Your target date stays yours to keep. FitGo will not suggest more '
          'than $limit kcal/day of ${plan.isLoss ? 'deficit' : 'surplus'}'
          '${plan.isLoss ? ' or an intake below ${GoalPlan.minDailyCalories} kcal/day' : ''}, '
          'so the saved plan follows a safer pace. The earliest safe date is '
          '${DateFormat('d MMM yyyy').format(plan.earliestSafeDate)}.';
    } else if (plan.isMaintain) {
      message =
          'Your target matches your current weight. FitGo will keep your '
          'calories at maintenance.';
    } else {
      message =
          'This is a steady plan. Weigh yourself at the same time of day and '
          'update your weight so the plan stays accurate.';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          plan.requestedDateTooAggressive
              ? Icons.info_outline_rounded
              : Icons.check_circle_outline_rounded,
          size: 18,
          color: plan.requestedDateTooAggressive ? tokens.amber : tokens.mint,
        ),
        const SizedBox(width: FitGoSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
