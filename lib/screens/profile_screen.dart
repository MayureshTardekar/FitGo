import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';
import '../services/supabase_service.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (profile == null) {
      return const Center(child: Text('No profile found'));
    }

    final bmi =
        profile.weightKg /
        ((profile.heightCm / 100) * (profile.heightCm / 100));
    final bmiCategory = bmi < 18.5
        ? 'Underweight'
        : bmi < 25
        ? 'Normal'
        : bmi < 30
        ? 'Overweight'
        : 'Obese';
    final bmiColor = bmi < 18.5
        ? const Color(0xFFE85D04)
        : bmi < 25
        ? cs.primary
        : bmi < 30
        ? const Color(0xFFE85D04)
        : cs.error;

    final dailyFromWeekly = (profile.weeklyCalorieGoal / 7).round();
    final deficit = profile.tdee - dailyFromWeekly;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar + name area
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: cs.primaryContainer,
                child: Icon(
                  profile.gender == 'male' ? Icons.male : Icons.female,
                  size: 40,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${profile.age} years old  ·  ${profile.gender[0].toUpperCase()}${profile.gender.substring(1)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // BMI Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.monitor_heart, color: bmiColor),
                    const SizedBox(width: 8),
                    Text(
                      'BMI',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: bmiColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        bmiCategory,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: bmiColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  bmi.toStringAsFixed(1),
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: bmiColor,
                  ),
                ),
                const SizedBox(height: 8),
                // BMI scale bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 185,
                          child: Container(color: const Color(0xFFE85D04)),
                        ),
                        Expanded(flex: 65, child: Container(color: cs.primary)),
                        Expanded(
                          flex: 50,
                          child: Container(color: const Color(0xFFE85D04)),
                        ),
                        Expanded(flex: 200, child: Container(color: cs.error)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('18.5', style: _scaleStyle(cs)),
                    Text('25', style: _scaleStyle(cs)),
                    Text('30', style: _scaleStyle(cs)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Body Stats Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Body Stats',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Weight',
                  value: '${profile.weightKg.toStringAsFixed(1)} kg',
                  onEdit: () => _editField(
                    context,
                    ref,
                    'weight',
                    profile.weightKg.toString(),
                  ),
                ),
                _DetailRow(
                  icon: Icons.height,
                  label: 'Height',
                  value: '${profile.heightCm.toStringAsFixed(0)} cm',
                  onEdit: () => _editField(
                    context,
                    ref,
                    'height',
                    profile.heightCm.toString(),
                  ),
                ),
                _DetailRow(
                  icon: Icons.cake_outlined,
                  label: 'Age',
                  value: '${profile.age} years',
                ),
                _DetailRow(
                  icon: Icons.person_outline,
                  label: 'Gender',
                  value:
                      '${profile.gender[0].toUpperCase()}${profile.gender.substring(1)}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Goals Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Goals Budget',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.calendar_month,
                  label: 'Monthly Budget',
                  value: '${(profile.weeklyCalorieGoal / 7 * 30).round()} kcal',
                  onEdit: () => _editField(
                    context,
                    ref,
                    'monthlyCalories',
                    (profile.weeklyCalorieGoal / 7 * 30).round().toString(),
                  ),
                ),
                _DetailRow(
                  icon: Icons.date_range,
                  label: 'Weekly Target',
                  value: '${profile.weeklyCalorieGoal} kcal',
                ),
                _DetailRow(
                  icon: Icons.local_fire_department,
                  label: 'Daily Target',
                  value: '$dailyFromWeekly kcal/day',
                ),
                _DetailRow(
                  icon: Icons.water_drop,
                  label: 'Water Goal',
                  value: '${profile.waterGoalMl} ml/day',
                  onEdit: () => _editField(
                    context,
                    ref,
                    'water',
                    profile.waterGoalMl.toString(),
                  ),
                ),
                _DetailRow(
                  icon: Icons.flag_outlined,
                  label: 'Weight Goal',
                  value: _goalLabel(profile.weightGoal),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Advanced Projections Math View
        Card(
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(Icons.calculate, color: cs.primary),
              title: Text(
                'Weight Loss Projection',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                deficit == 0 
                  ? 'Maintaining current weight' 
                  : (deficit > 0 
                      ? 'Losing ~${((deficit * 30) / 7700).toStringAsFixed(1)} kg / month' 
                      : 'Gaining ~${((deficit.abs() * 30) / 7700).toStringAsFixed(1)} kg / month'),
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
              ),
              childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                const SizedBox(height: 12),
                _MathRow(label: 'Maintenance (TDEE)', value: '${profile.tdee} kcal/day'),
                _MathRow(label: 'Daily Target', value: '$dailyFromWeekly kcal/day'),
                _MathRow(
                  label: deficit >= 0 ? 'Daily Deficit' : 'Daily Surplus', 
                  value: deficit >= 0 ? '-${deficit.abs()} kcal/day' : '+${deficit.abs()} kcal/day',
                  isHighlight: true,
                  color: deficit >= 0 ? cs.primary : const Color(0xFFE85D04),
                ),
                const SizedBox(height: 12),
                _MathRow(
                  label: 'Monthly Impact', 
                  value: '${deficit.abs() * 30} kcal',
                ),
                _MathRow(
                  label: 'Equivalent Weight', 
                  value: '${((deficit.abs() * 30) / 7700).toStringAsFixed(2)} kg',
                  isHighlight: true,
                ),
                const SizedBox(height: 8),
                Text(
                  '*Based on 7700 kcal = 1kg. Actual results may vary.',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.5)),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Account Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.cloud,
                  label: 'Sync Status',
                  value: SupabaseService.isLoggedIn ? 'Connected' : 'Offline',
                  valueColor: SupabaseService.isLoggedIn
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
                if (SupabaseService.isLoggedIn) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 20, color: cs.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Email',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 4),
                    child: Text(
                      SupabaseService.currentUser?.email ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        FilledButton.tonalIcon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (dCtx) => AlertDialog(
                title: const Text('Redo Full Setup?'),
                content: const Text('This will take you to the initial setup screen and overwrite your existing goals. Are you completely sure?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                    onPressed: () {
                      Navigator.pop(dCtx); // Close dialog

                      bool isCancelled = false;
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      
                      scaffoldMessenger.clearSnackBars();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: const Text('Navigating to setup in 5 seconds...'),
                          duration: const Duration(seconds: 5),
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: 'CANCEL (5s)',
                            textColor: Colors.yellow,
                            onPressed: () {
                              isCancelled = true;
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Action cancelled. Setup aborted.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                      );

                      Future.delayed(const Duration(seconds: 5), () {
                        if (!isCancelled && context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                          );
                        }
                      });
                    },
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: const Text('Proceed'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Redo Full Setup'),
        ),
        const SizedBox(height: 8),
        if (SupabaseService.isLoggedIn)
          OutlinedButton.icon(
            onPressed: () async {
              final nav = Navigator.of(context);
              await SupabaseService.signOut();
              if (context.mounted) {
                // Pop everything and go back to root — auth gate will show login
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
            icon: Icon(Icons.logout, color: cs.error),
            label: Text('Sign Out', style: TextStyle(color: cs.error)),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  TextStyle _scaleStyle(ColorScheme cs) =>
      TextStyle(fontSize: 9, color: cs.onSurfaceVariant);

  String _goalLabel(String goal) => switch (goal) {
    'lose' => 'Lose Weight',
    'gain' => 'Gain Weight',
    'custom' => 'Custom Budget',
    _ => 'Maintain Weight',
  };

  void _editField(
    BuildContext context,
    WidgetRef ref,
    String field,
    String current,
  ) {
    final controller = TextEditingController(text: current);
    String label;
    String suffix;
    switch (field) {
      case 'weight':
        label = 'Weight';
        suffix = 'kg';
      case 'height':
        label = 'Height';
        suffix = 'cm';
      case 'weeklyCalories':
        label = 'Weekly Calorie Budget';
        suffix = 'kcal/week';
      case 'monthlyCalories':
        label = 'Monthly Calorie Budget';
        suffix = 'kcal/mo';
      case 'water':
        label = 'Daily Water Goal';
        suffix = 'ml';
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
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
              final v = double.tryParse(controller.text);
              if (v == null || v <= 0) return;
              switch (field) {
                case 'weight':
                  ref.read(profileProvider.notifier).updateGoals();
                  final p = ref.read(profileProvider);
                  if (p != null) {
                    p.weightKg = v;
                    ref.read(profileProvider.notifier).saveProfile(p);
                  }
                case 'height':
                  final p = ref.read(profileProvider);
                  if (p != null) {
                    p.heightCm = v;
                    ref.read(profileProvider.notifier).saveProfile(p);
                  }
                case 'weeklyCalories':
                  ref
                      .read(profileProvider.notifier)
                      .updateGoals(
                        weeklyCalorieGoal: v.toInt(),
                        calorieGoal: (v / 7).round(),
                      );
                case 'monthlyCalories':
                  final daily = (v / 30).round();
                  final weekly = daily * 7;
                  ref
                      .read(profileProvider.notifier)
                      .updateGoals(
                        weeklyCalorieGoal: weekly,
                        calorieGoal: daily,
                      );
                case 'water':
                  ref
                      .read(profileProvider.notifier)
                      .updateGoals(waterGoalMl: v.toInt());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? cs.onSurface,
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              child: Icon(Icons.edit, size: 14, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _MathRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;
  final Color? color;

  const _MathRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label, 
              style: TextStyle(
                color: isHighlight ? (color ?? cs.onSurface) : cs.onSurfaceVariant, 
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: color ?? cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
