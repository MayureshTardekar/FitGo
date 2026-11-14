import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/units.dart';
import '../models/user_profile.dart';
import '../providers/local_data_refresh.dart';
import '../providers/monthly_calorie_alert_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/sync_status_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/units_provider.dart';
import '../services/supabase_service.dart';
import '../ui/components/fitgo_card.dart';
import '../ui/components/fitgo_list_row.dart';
import '../ui/components/fitgo_pill.dart';
import '../ui/components/fitgo_primary_button.dart';
import '../ui/components/fitgo_segmented_control.dart';
import '../ui/components/fitgo_section_header.dart';
import '../ui/components/fitgo_sync_status_pill.dart';
import '../ui/haptics.dart';
import '../ui/theme/fitgo_tokens.dart';

const _appVersion = '3.0.0 (3)';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const _ProfileBody(),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final themeMode = ref.watch(themeModeProvider);
    final units = ref.watch(unitSystemProvider);
    final calorieAlert = ref.watch(monthlyCalorieAlertProvider);

    if (profile == null) {
      return const Center(child: Text('No profile found'));
    }

    final dailyFromWeekly = (profile.weeklyCalorieGoal / 7).round();
    final deficit = profile.tdee - dailyFromWeekly;
    final monthlyKg = deficit.abs() * 30 / 7700;
    final projection = deficit.abs() < 25
        ? 'Maintaining'
        : deficit > 0
        ? '−${monthlyKg.toStringAsFixed(1)} kg/mo'
        : '+${monthlyKg.toStringAsFixed(1)} kg/mo';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FitGoSpacing.md,
        FitGoSpacing.sm,
        FitGoSpacing.md,
        FitGoSpacing.xxxl,
      ),
      children: [
        _ProfileHeader(profile: profile, units: units),
        const SizedBox(height: FitGoSpacing.xl),
        const FitGoSectionHeader(
          title: 'Goals',
          subtitle: 'Targets and body measurements.',
        ),
        _SettingsGroup(
          children: [
            FitGoListRow(
              leadingIcon: Icons.local_fire_department_outlined,
              title: 'Calorie budget',
              subtitle:
                  '≈ $dailyFromWeekly kcal/day · '
                  '${(dailyFromWeekly * 30).round()} kcal/month',
              trailingText: '${profile.weeklyCalorieGoal} / wk',
              onTap: () =>
                  _editField(context, ref, 'weeklyCalories', profile, units),
            ),
            FitGoListRow(
              leadingIcon: Icons.water_drop_outlined,
              title: 'Water goal',
              subtitle: 'Daily hydration target',
              trailingText: units.formatVolume(profile.waterGoalMl.toDouble()),
              onTap: () => _editField(context, ref, 'water', profile, units),
            ),
            FitGoListRow(
              leadingIcon: Icons.flag_outlined,
              title: 'Weight goal',
              subtitle: 'Used for your calorie projection',
              trailingText: _goalLabel(profile.weightGoal),
              onTap: () => _pickWeightGoal(context, ref, profile),
            ),
            FitGoListRow(
              leadingIcon: Icons.monitor_weight_outlined,
              title: 'Weight',
              trailingText: units.formatWeight(profile.weightKg),
              onTap: () => _editField(context, ref, 'weight', profile, units),
            ),
            FitGoListRow(
              leadingIcon: Icons.height_rounded,
              title: 'Height',
              trailingText: units.isMetric
                  ? '${profile.heightCm.toStringAsFixed(0)} cm'
                  : formatFeetInches(profile.heightCm),
              onTap: () => _editField(context, ref, 'height', profile, units),
            ),
            FitGoListRow(
              leadingIcon: Icons.insights_outlined,
              title: 'Weight projection',
              subtitle: 'Estimated from your daily budget',
              trailingText: projection,
              onTap: () => _showProjection(context, profile),
            ),
            FitGoListRow(
              leadingIcon: Icons.restart_alt_rounded,
              title: 'Redo full setup',
              subtitle: 'Re-run onboarding and replace your goals',
              destructive: true,
              onTap: () => _confirmRedoSetup(context),
            ),
          ],
        ),
        const SizedBox(height: FitGoSpacing.xl),
        const FitGoSectionHeader(
          title: 'Preferences',
          subtitle: 'Appearance, units, and reminders.',
        ),
        _SettingsGroup(
          children: [
            _SegmentedSetting<ThemeMode>(
              icon: themeMode == ThemeMode.dark
                  ? Icons.dark_mode_outlined
                  : themeMode == ThemeMode.light
                  ? Icons.light_mode_outlined
                  : Icons.brightness_auto_outlined,
              title: 'Appearance',
              subtitle: themeMode == ThemeMode.system
                  ? 'Follows your device setting'
                  : themeMode == ThemeMode.dark
                  ? 'Always use the dark theme'
                  : 'Always use the light theme',
              values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              labels: const ['System', 'Light', 'Dark'],
              selected: themeMode,
              onChanged: (mode) {
                FitGoHaptics.select();
                ref.read(themeModeProvider.notifier).setMode(mode);
              },
            ),
            _SegmentedSetting<UnitSystem>(
              icon: Icons.straighten_rounded,
              title: 'Units',
              subtitle: 'Stored as kg and ml either way',
              values: const [UnitSystem.metric, UnitSystem.imperial],
              labels: const ['Metric', 'Imperial'],
              selected: units,
              onChanged: (system) {
                FitGoHaptics.select();
                ref.read(unitSystemProvider.notifier).setSystem(system);
              },
            ),
            FitGoListRow(
              leadingIcon: Icons.notification_important_outlined,
              title: 'Monthly Calorie Guard',
              subtitle: 'Warn before you exceed a monthly limit',
              showChevron: false,
              trailing: Switch.adaptive(
                value: calorieAlert.enabled,
                onChanged: (value) => ref
                    .read(monthlyCalorieAlertProvider.notifier)
                    .updateSettings(enabled: value),
              ),
            ),
            _CalorieGuardSummary(alert: calorieAlert),
            FitGoListRow(
              leadingIcon: Icons.calendar_month_outlined,
              title: 'Max intake',
              trailingText: '${calorieAlert.monthlyLimit} kcal',
              onTap: () => _editCalorieGuardNumber(
                context,
                ref,
                title: 'Max Monthly Intake',
                current: calorieAlert.monthlyLimit,
                suffix: 'kcal',
                onSave: (value) => ref
                    .read(monthlyCalorieAlertProvider.notifier)
                    .updateSettings(monthlyLimit: value),
              ),
            ),
            FitGoListRow(
              leadingIcon: Icons.priority_high_rounded,
              title: 'Warn at',
              trailingText:
                  '${calorieAlert.warningPercent}% · ${calorieAlert.warningAt} kcal',
              onTap: () => _editCalorieGuardNumber(
                context,
                ref,
                title: 'Warning Percent',
                current: calorieAlert.warningPercent,
                suffix: '%',
                onSave: (value) => ref
                    .read(monthlyCalorieAlertProvider.notifier)
                    .updateSettings(warningPercent: value),
              ),
            ),
            FitGoListRow(
              leadingIcon: Icons.schedule_rounded,
              title: 'Alert time',
              trailingText: calorieAlert.alertTimeLabel,
              onTap: () => _pickCalorieGuardTime(context, ref, calorieAlert),
            ),
            FitGoListRow(
              leadingIcon: Icons.message_outlined,
              title: 'Message',
              subtitle: calorieAlert.message,
              onTap: () =>
                  _editCalorieGuardMessage(context, ref, calorieAlert.message),
            ),
          ],
        ),
        const SizedBox(height: FitGoSpacing.xl),
        const FitGoSectionHeader(
          title: 'Account & Backup',
          subtitle: 'Saved here first, backed up when online.',
        ),
        const _AccountBackupCard(),
        const SizedBox(height: FitGoSpacing.xl),
        const FitGoSectionHeader(
          title: 'Help & Privacy',
          subtitle: 'How your data is handled.',
        ),
        _SettingsGroup(
          children: [
            FitGoListRow(
              leadingIcon: Icons.sync_rounded,
              title: 'How sync works',
              onTap: () => _showInfoDialog(
                context,
                title: 'How sync works',
                body:
                    'FitGo saves every change on this device first. When you '
                    'are signed in, changes are queued and uploaded to your '
                    'private cloud backup. A cloud refresh never overwrites a '
                    'change that is still waiting to upload. Guest profiles '
                    'stay on this device until you choose to import them.',
              ),
            ),
            FitGoListRow(
              leadingIcon: Icons.privacy_tip_outlined,
              title: 'Privacy & your data',
              onTap: () => _showInfoDialog(
                context,
                title: 'Privacy & your data',
                body:
                    'Food, fasting, water, activity, sleep, and weight logs '
                    'are stored on this device. Signed-in backups are stored '
                    'in your private Supabase account. FitGo does not sell '
                    'your data, use it for advertising, or share health data '
                    'with third parties.',
                url: 'https://fitgo.app/privacy',
              ),
            ),
            FitGoListRow(
              leadingIcon: Icons.description_outlined,
              title: 'Terms of use',
              onTap: () => _showInfoDialog(
                context,
                title: 'Terms of use',
                body:
                    'FitGo is a personal tracking tool, not medical advice. '
                    'Use it alongside professional guidance and do not misuse '
                    'the service or upload unlawful content.',
                url: 'https://fitgo.app/terms',
              ),
            ),
            FitGoListRow(
              leadingIcon: Icons.help_outline_rounded,
              title: 'Support',
              onTap: () => _showInfoDialog(
                context,
                title: 'Support',
                body:
                    'Help articles and contact details are published at the '
                    'support page. Open the address below in your browser.',
                url: 'https://fitgo.app/support',
              ),
            ),
            const FitGoListRow(
              leadingIcon: Icons.info_outline_rounded,
              title: 'App version',
              trailingText: _appVersion,
              showChevron: false,
            ),
          ],
        ),
        const SizedBox(height: FitGoSpacing.xl),
        Center(
          child: Text(
            'Developed by Mayuresh',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.tokens.textSecondary,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  String _goalLabel(String goal) => switch (goal) {
    'lose' => 'Lose weight',
    'gain' => 'Gain weight',
    'custom' => 'Custom budget',
    _ => 'Maintain weight',
  };

  void _editField(
    BuildContext context,
    WidgetRef ref,
    String field,
    UserProfile profile,
    UnitSystem units,
  ) {
    final controller = TextEditingController();
    String label;
    String suffix;

    switch (field) {
      case 'weight':
        label = 'Weight';
        suffix = units.weightLabel;
        controller.text = units
            .weightFromKg(profile.weightKg)
            .toStringAsFixed(1);
      case 'height':
        label = 'Height';
        suffix = units.heightLabel;
        controller.text = units.isMetric
            ? profile.heightCm.toStringAsFixed(0)
            : units.heightFromCm(profile.heightCm).toStringAsFixed(1);
      case 'weeklyCalories':
        label = 'Weekly calorie budget';
        suffix = 'kcal/week';
        controller.text = '${profile.weeklyCalorieGoal}';
      case 'water':
        label = 'Daily water goal';
        suffix = units.volumeLabel;
        controller.text = units
            .volumeFromMl(profile.waterGoalMl.toDouble())
            .toStringAsFixed(units.isMetric ? 0 : 1);
      default:
        return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;

              switch (field) {
                case 'weight':
                  final updated = profile.copy()
                    ..weightKg = units.weightToKg(value);
                  ref.read(profileProvider.notifier).saveProfile(updated);
                case 'height':
                  final updated = profile.copy()
                    ..heightCm = units.heightToCm(value);
                  ref.read(profileProvider.notifier).saveProfile(updated);
                case 'weeklyCalories':
                  ref
                      .read(profileProvider.notifier)
                      .updateGoals(
                        weeklyCalorieGoal: value.round(),
                        calorieGoal: (value / 7).round(),
                      );
                case 'water':
                  ref
                      .read(profileProvider.notifier)
                      .updateGoals(
                        waterGoalMl: units.volumeToMl(value).round(),
                      );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickWeightGoal(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    const goals = [
      ('lose', 'Lose weight'),
      ('maintain', 'Maintain weight'),
      ('gain', 'Gain weight'),
      ('custom', 'Custom budget'),
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Weight goal'),
        children: [
          for (final (value, label) in goals)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, value),
              child: Row(
                children: [
                  Icon(
                    profile.weightGoal == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                  ),
                  const SizedBox(width: FitGoSpacing.sm),
                  Text(label),
                ],
              ),
            ),
        ],
      ),
    );

    if (selected == null) return;
    await ref.read(profileProvider.notifier).updateGoals(weightGoal: selected);
  }

  void _showProjection(BuildContext context, UserProfile profile) {
    final dailyTarget = (profile.weeklyCalorieGoal / 7).round();
    final deficit = profile.tdee - dailyTarget;
    final monthlyKg = deficit.abs() * 30 / 7700;
    final theme = Theme.of(context);
    final tokens = context.tokens;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Weight projection'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MathRow(
                label: 'Maintenance (TDEE)',
                value: '${profile.tdee} kcal/day',
              ),
              _MathRow(label: 'Daily target', value: '$dailyTarget kcal/day'),
              _MathRow(
                label: deficit >= 0 ? 'Daily deficit' : 'Daily surplus',
                value: deficit >= 0
                    ? '−${deficit.abs()} kcal/day'
                    : '+${deficit.abs()} kcal/day',
                isHighlight: true,
                color: deficit >= 0 ? tokens.aqua : tokens.emberDeep,
              ),
              const SizedBox(height: FitGoSpacing.sm),
              _MathRow(
                label: 'Monthly impact',
                value: '${deficit.abs() * 30} kcal',
              ),
              _MathRow(
                label: 'Equivalent weight',
                value: '${monthlyKg.toStringAsFixed(2)} kg',
                isHighlight: true,
              ),
              const SizedBox(height: FitGoSpacing.sm),
              Text(
                '*Estimates use 7700 kcal = 1 kg. Actual results vary.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRedoSetup(BuildContext context) async {
    final shouldRedo = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redo full setup?'),
        content: const Text(
          'This opens onboarding again and replaces your current goals. '
          'Your logged history stays on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (shouldRedo != true || !context.mounted) return;
    context.push('/onboarding?redo=1');
  }

  void _editCalorieGuardNumber(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required int current,
    required String suffix,
    required Future<void> Function(int value) onSave,
  }) {
    final controller = TextEditingController(text: '$current');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: title,
            suffixText: suffix,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              await onSave(value);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCalorieGuardTime(
    BuildContext context,
    WidgetRef ref,
    MonthlyCalorieAlertState alert,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: alert.alertHour, minute: alert.alertMinute),
      helpText: 'Alert time',
    );
    if (picked == null) return;
    await ref
        .read(monthlyCalorieAlertProvider.notifier)
        .updateSettings(alertHour: picked.hour, alertMinute: picked.minute);
  }

  void _editCalorieGuardMessage(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    final controller = TextEditingController(text: current);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notification message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Message',
            hintText: 'A short reminder to stay within your budget.',
            border: OutlineInputBorder(),
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
                  .read(monthlyCalorieAlertProvider.notifier)
                  .updateSettings(message: controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(
    BuildContext context, {
    required String title,
    required String body,
    String? url,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
              if (url != null) ...[
                const SizedBox(height: FitGoSpacing.md),
                SelectableText(
                  url,
                  style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                    color: dialogContext.tokens.emberDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (url != null)
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy link'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.profile, required this.units});

  final UserProfile profile;
  final UnitSystem units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = theme.colorScheme;
    final isLoggedIn = SupabaseService.isLoggedIn;
    final email = SupabaseService.currentUser?.email ?? '';
    final heightM = profile.heightCm / 100;
    final bmi = heightM <= 0 ? 0.0 : profile.weightKg / (heightM * heightM);
    final bmiLabel = bmi <= 0
        ? ''
        : bmi < 18.5
        ? 'Underweight'
        : bmi < 25
        ? 'Healthy'
        : bmi < 30
        ? 'Overweight'
        : 'Obese';
    final healthyBmi = bmi >= 18.5 && bmi < 25;
    final bmiColor = healthyBmi
        ? scheme.onTertiaryContainer
        : scheme.onErrorContainer;
    final bmiBackground = healthyBmi
        ? scheme.tertiaryContainer
        : scheme.errorContainer;

    return FitGoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: tokens.ember.withValues(alpha: 0.14),
            child: Icon(
              profile.gender == 'male'
                  ? Icons.male_rounded
                  : Icons.female_rounded,
              color: tokens.emberDeep,
              size: 28,
            ),
          ),
          const SizedBox(width: FitGoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn
                      ? (email.isEmpty ? 'Signed in' : email)
                      : 'Guest profile',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${profile.age} yrs · '
                  '${profile.gender[0].toUpperCase()}${profile.gender.substring(1)} · '
                  '${units.formatWeight(profile.weightKg)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: FitGoSpacing.xs),
                Wrap(
                  spacing: FitGoSpacing.xs,
                  runSpacing: FitGoSpacing.xxs,
                  children: [
                    const SyncStatusPill(),
                    if (bmiLabel.isNotEmpty)
                      FitGoPill(
                        label: 'BMI ${bmi.toStringAsFixed(1)} · $bmiLabel',
                        icon: Icons.monitor_heart_outlined,
                        color: bmiColor,
                        background: bmiBackground,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedSetting<T extends Object> extends StatelessWidget {
  const _SegmentedSetting({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FitGoListRow(
          leadingIcon: icon,
          title: title,
          subtitle: subtitle,
          showChevron: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FitGoSpacing.md,
            0,
            FitGoSpacing.md,
            FitGoSpacing.md,
          ),
          child: FitGoSegmentedControl<T>(
            values: values,
            labels: labels,
            selected: selected,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _CalorieGuardSummary extends StatelessWidget {
  const _CalorieGuardSummary({required this.alert});

  final MonthlyCalorieAlertState alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final progress = alert.monthlyLimit > 0
        ? (alert.monthTotal / alert.monthlyLimit).clamp(0.0, 1.0)
        : 0.0;
    final color = alert.isOverLimit
        ? theme.colorScheme.error
        : alert.isInWarningZone
        ? tokens.emberDeep
        : tokens.ember;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitGoSpacing.md,
        0,
        FitGoSpacing.md,
        FitGoSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: tokens.surfaceMuted,
              color: color,
            ),
          ),
          const SizedBox(height: FitGoSpacing.xs),
          Text(
            '${alert.monthTotal} / ${alert.monthlyLimit} kcal this month',
            style: theme.textTheme.bodySmall?.copyWith(
              color: alert.isOverLimit
                  ? theme.colorScheme.error
                  : tokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountBackupCard extends ConsumerStatefulWidget {
  const _AccountBackupCard();

  @override
  ConsumerState<_AccountBackupCard> createState() => _AccountBackupCardState();
}

class _AccountBackupCardState extends ConsumerState<_AccountBackupCard> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider);
    final guestDataAvailable =
        ref.watch(guestDataAvailableProvider).valueOrNull ?? false;
    final isLoggedIn = SupabaseService.isLoggedIn;
    final email = SupabaseService.currentUser?.email ?? '';
    final lastSync = status.lastSyncedAt;
    final theme = Theme.of(context);

    return _SettingsGroup(
      children: [
        FitGoListRow(
          leadingIcon: isLoggedIn
              ? Icons.verified_user_outlined
              : Icons.person_off_outlined,
          title: isLoggedIn
              ? (email.isEmpty ? 'Signed in' : email)
              : 'Guest profile',
          subtitle: isLoggedIn
              ? 'Cloud backup enabled'
              : 'Local only · Sign in to back up',
          showChevron: false,
        ),
        FitGoListRow(
          leadingIcon: Icons.cloud_done_outlined,
          title: 'Last sync',
          subtitle: 'Pull-first refresh from your backup',
          trailingText: lastSync == null ? 'Never' : relativeSyncTime(lastSync),
          showChevron: false,
        ),
        FitGoListRow(
          leadingIcon: Icons.cloud_upload_outlined,
          title: 'Pending changes',
          subtitle: status.cloudEnabled
              ? 'Saved here, waiting to upload'
              : 'Guest data never leaves this device',
          trailingText: status.cloudEnabled
              ? '${status.pendingChanges}'
              : 'Local only',
          showChevron: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FitGoSpacing.md,
            FitGoSpacing.sm,
            FitGoSpacing.md,
            FitGoSpacing.md,
          ),
          child: FitGoPrimaryButton(
            label: isLoggedIn ? 'Retry sync' : 'Sign in or create account',
            icon: isLoggedIn ? Icons.sync_rounded : Icons.cloud_upload_outlined,
            loading: _syncing,
            tonal: true,
            onPressed: isLoggedIn ? _syncNow : () => context.push('/auth'),
          ),
        ),
        if (isLoggedIn && guestDataAvailable)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FitGoSpacing.md,
              0,
              FitGoSpacing.md,
              FitGoSpacing.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _importGuestData,
                icon: const Icon(Icons.move_to_inbox_outlined),
                label: const Text('Import guest data'),
              ),
            ),
          ),
        if (isLoggedIn)
          FitGoListRow(
            leadingIcon: Icons.logout_rounded,
            title: 'Sign out',
            subtitle: 'Keeps this device’s logs in guest mode',
            destructive: true,
            onTap: _confirmSignOut,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FitGoSpacing.md,
            0,
            FitGoSpacing.md,
            FitGoSpacing.md,
          ),
          child: Text(
            'Changes save on this device first. A poor connection never blocks '
            'logging and never loses a pending edit.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _syncing = true);

    final storage = ref.read(localStorageProvider);
    await storage.syncWithCloud();
    refreshLocalDataProviders(ref);
    if (!mounted) return;

    setState(() => _syncing = false);
    final status = ref.read(syncStatusProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          status.hasPendingChanges
              ? 'Still offline. ${status.pendingChanges} change'
                    '${status.pendingChanges == 1 ? '' : 's'} saved on this '
                    'device.'
              : 'Cloud backup is up to date.',
        ),
      ),
    );
  }

  Future<void> _importGuestData() async {
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import guest data?'),
        content: const Text(
          'Copy the progress saved on this device in guest mode into this '
          'account? Existing account records are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (shouldImport != true) return;
    if (!mounted) return;

    final storage = ref.read(localStorageProvider);
    final imported = await storage.importGuestData();
    await storage.syncWithCloud();
    if (!mounted) return;

    ref.invalidate(guestDataAvailableProvider);
    refreshLocalDataProviders(ref);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          imported == 0
              ? 'Nothing new to import'
              : '$imported local record${imported == 1 ? '' : 's'} imported',
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your logs stay on this device and the app switches to guest mode. '
          'Unsynced changes stay queued for the next time you sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true) return;

    await SupabaseService.signOut();
    if (!mounted) return;
    context.go('/profile');
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final content = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        content.add(Divider(height: 1, thickness: 1, color: tokens.border));
      }
      content.add(children[i]);
    }
    return FitGoCard(
      padding: EdgeInsets.zero,
      child: Column(children: content),
    );
  }
}

class _MathRow extends StatelessWidget {
  const _MathRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.color,
  });

  final String label;
  final String value;
  final bool isHighlight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isHighlight ? tokens.textPrimary : tokens.textSecondary,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: FitGoSpacing.sm),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color ?? tokens.textPrimary,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
