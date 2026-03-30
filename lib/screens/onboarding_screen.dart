import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/user_profile.dart';
import '../providers/profile_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  static const _totalSteps = 4;

  // Step 1: Gender
  String _gender = 'male';

  // Step 2: Body — sliders + DOB
  double _weight = 70;
  double _height = 170;
  DateTime? _dob;

  // Step 3: Goal + custom weekly
  String _weightGoal = 'maintain';
  final _weeklyCtrl = TextEditingController();
  bool _useCustomWeekly = false;

  int get _age => _dob != null ? UserProfile.ageFromDob(_dob!) : 25;

  int get _calcTdee {
    double bmr;
    if (_gender == 'male') {
      bmr = 10 * _weight + 6.25 * _height - 5 * _age + 5;
    } else {
      bmr = 10 * _weight + 6.25 * _height - 5 * _age - 161;
    }
    return (bmr * 1.4).round();
  }

  int get _suggestedWeekly {
    final tdee = _calcTdee;
    switch (_weightGoal) {
      case 'lose':
        return (tdee - 500) * 7;
      case 'gain':
        return (tdee + 300) * 7;
      default:
        return tdee * 7;
    }
  }

  int get _effectiveWeekly {
    if (_useCustomWeekly) {
      return int.tryParse(_weeklyCtrl.text) ?? _suggestedWeekly;
    }
    return _suggestedWeekly;
  }

  @override
  void dispose() {
    _weeklyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Header
              Text(
                _step == 0 ? 'Welcome to FitGo' : _stepTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _stepSubtitle,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ((_step + 1) / _totalSteps).clamp(0.0, 1.0).toDouble(),
                  minHeight: 4,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 24),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey(_step),
                  child: _buildStep(),
                ),
              ),
              // Navigation
              _buildNav(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String get _stepTitle => switch (_step) {
        0 => 'Welcome to FitGo',
        1 => 'About You',
        2 => 'Your Goal',
        3 => 'Your Plan',
        _ => '',
      };

  String get _stepSubtitle => switch (_step) {
        0 => 'Choose your gender',
        1 => 'Help us calculate your needs',
        2 => 'Set your weekly calorie budget',
        3 => 'Review and get started',
        _ => '',
      };

  Widget _buildStep() {
    return switch (_step) {
      0 => _buildGenderStep(),
      1 => _buildBodyStep(),
      2 => _buildGoalStep(),
      3 => _buildSummaryStep(),
      _ => const SizedBox(),
    };
  }

  // ─── Step 1: Gender ──────────────────────────────────────────────────────

  Widget _buildGenderStep() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _genderCard('Male', Icons.male, 'male', cs),
          const SizedBox(width: 20),
          _genderCard('Female', Icons.female, 'female', cs),
        ],
      ),
    );
  }

  Widget _genderCard(
      String label, IconData icon, String value, ColorScheme cs) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 130,
        height: 150,
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
          boxShadow: selected
              ? [BoxShadow(color: cs.primary.withAlpha(30), blurRadius: 12)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 52,
                color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                )),
          ],
        ),
      ),
    );
  }

  // ─── Step 2: Body Details ────────────────────────────────────────────────

  Widget _buildBodyStep() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        // DOB Picker
          GestureDetector(
            onTap: _pickDob,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _dob != null ? cs.primary : cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date of Birth',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        Text(
                          _dob != null
                              ? '${DateFormat('dd MMM yyyy').format(_dob!)}  ·  $_age years old'
                              : 'Tap to select',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _dob != null
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.calendar_today, size: 18, color: cs.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Weight slider
          _sliderCard(
            icon: Icons.monitor_weight_outlined,
            label: 'Weight',
            value: _weight,
            unit: 'kg',
            min: 30,
            max: 200,
            divisions: 170,
            onChanged: (v) => setState(() => _weight = v),
          ),
          const SizedBox(height: 16),
          // Height slider
          _sliderCard(
            icon: Icons.height,
            label: 'Height',
            value: _height,
            unit: 'cm',
            min: 100,
            max: 220,
            divisions: 120,
            onChanged: (v) => setState(() => _height = v),
          ),
          const SizedBox(height: 16),
          // Live TDEE preview
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Your estimated TDEE: $_calcTdee kcal/day',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sliderCard({
    required IconData icon,
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(
                '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} $unit',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1930),
      lastDate: now,
      helpText: 'Select your date of birth',
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  // ─── Step 3: Goal ────────────────────────────────────────────────────────

  Widget _buildGoalStep() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        // Preset goals
          _goalOption(
            'Lose Weight',
            'Deficit of 500 kcal/day',
            Icons.trending_down,
            const Color(0xFFFFBA08),
            'lose',
          ),
          const SizedBox(height: 10),
          _goalOption(
            'Maintain Weight',
            'Balanced intake at TDEE',
            Icons.balance,
            cs.primary,
            'maintain',
          ),
          const SizedBox(height: 10),
          _goalOption(
            'Gain Weight',
            'Surplus of 300 kcal/day',
            Icons.trending_up,
            const Color(0xFFE85D04),
            'gain',
          ),
          const SizedBox(height: 10),
          _goalOption(
            'Custom Budget',
            'Set your own weekly target',
            Icons.tune,
            cs.tertiary,
            'custom',
          ),
          const SizedBox(height: 20),

          // Show calculated or custom input
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _useCustomWeekly
                ? _buildCustomInput()
                : _buildCalculatedPreview(),
        ),
      ],
    );
  }

  Widget _goalOption(
      String title, String subtitle, IconData icon, Color color, String value) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final selected = _weightGoal == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _weightGoal = value;
          _useCustomWeekly = value == 'custom';
          if (!_useCustomWeekly) {
            _weeklyCtrl.text = '';
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(20) : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? color.withAlpha(30)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 20,
                  color: selected ? color : cs.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: selected ? color : cs.onSurface,
                      )),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (value != 'custom') ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_calcWeeklyFor(value)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: selected ? color : cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _weightChangeLabel(value),
                    style: TextStyle(
                      fontSize: 9,
                      color: selected ? color : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, size: 20, color: color),
              ),
          ],
        ),
      ),
    );
  }

  String _weightChangeLabel(String goal) {
    final weekly = _calcWeeklyFor(goal);
    final daily = (weekly / 7).round();
    final deficit = _calcTdee - daily; // positive = deficit, negative = surplus
    final kgPerWeek = deficit / 7700 * 7;
    if (kgPerWeek.abs() < 0.01) return 'maintain';
    final sign = kgPerWeek > 0 ? '-' : '+';
    return '$sign${kgPerWeek.abs().toStringAsFixed(1)} kg/week';
  }

  int _calcWeeklyFor(String goal) {
    final tdee = _calcTdee;
    switch (goal) {
      case 'lose':
        return (tdee - 500) * 7;
      case 'gain':
        return (tdee + 300) * 7;
      default:
        return tdee * 7;
    }
  }

  Widget _buildCalculatedPreview() {
    final weekly = _suggestedWeekly;
    final daily = (weekly / 7).round();
    return _buildBreakdownCard(weekly: weekly, daily: daily);
  }

  Widget _buildCustomInput() {
    final cs = Theme.of(context).colorScheme;
    final customVal = int.tryParse(_weeklyCtrl.text);
    final daily =
        customVal != null && customVal > 0 ? (customVal / 7).round() : 0;

    return Column(
      children: [
        TextField(
          controller: _weeklyCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Your weekly calorie budget',
            hintText: 'e.g. 7500',
            suffixText: 'kcal/week',
            border: const OutlineInputBorder(),
            prefixIcon: Icon(Icons.edit_calendar, color: cs.primary),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (daily > 0) ...[
          const SizedBox(height: 12),
          _buildBreakdownCard(weekly: customVal!, daily: daily),
        ],
      ],
    );
  }

  /// The unified breakdown card showing math + weight prediction
  Widget _buildBreakdownCard({required int weekly, required int daily}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tdee = _calcTdee;
    // Deficit = TDEE - daily intake (positive = deficit, negative = surplus)
    final deficit = tdee - daily;
    final isDeficit = deficit > 0;
    final isSurplus = deficit < 0;

    // 7700 kcal ≈ 1 kg of body fat
    final weeklyDeficit = deficit * 7;
    final kgPerWeek = weeklyDeficit / 7700;
    final kgPerMonth = kgPerWeek * 4.33;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _previewStat('Daily Intake', '$daily', 'kcal/day', cs.onSurface),
              Container(width: 1, height: 36, color: cs.outlineVariant),
              _previewStat('Your TDEE', '$tdee', 'kcal/day', cs.primary),
              Container(width: 1, height: 36, color: cs.outlineVariant),
              _previewStat(
                isDeficit ? 'Deficit' : isSurplus ? 'Surplus' : 'Balanced',
                '${deficit.abs()}',
                'kcal/day',
                isDeficit
                    ? const Color(0xFFFFBA08)
                    : isSurplus
                        ? const Color(0xFFE85D04)
                        : cs.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Math explanation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How it works:',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _mathRow('Weekly budget', '$weekly kcal', cs.onSurface),
                _mathRow('Daily intake', '$weekly / 7 = $daily kcal', cs.onSurface),
                _mathRow('Your body burns', '$tdee kcal/day (TDEE)', cs.primary),
                const Divider(height: 12),
                _mathRow(
                  isDeficit ? 'Daily deficit' : 'Daily surplus',
                  '$tdee - $daily = ${deficit.abs()} kcal',
                  isDeficit ? const Color(0xFFFFBA08) : const Color(0xFFE85D04),
                ),
                _mathRow(
                  'Weekly ${isDeficit ? "deficit" : "surplus"}',
                  '${deficit.abs()} × 7 = ${weeklyDeficit.abs()} kcal',
                  isDeficit ? const Color(0xFFFFBA08) : const Color(0xFFE85D04),
                ),
              ],
            ),
          ),
          if (deficit != 0) ...[
            const SizedBox(height: 14),
            // Weight prediction
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDeficit
                    ? const Color(0xFFFFBA08).withAlpha(20)
                    : const Color(0xFFE85D04).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDeficit
                      ? const Color(0xFFFFBA08).withAlpha(60)
                      : const Color(0xFFE85D04).withAlpha(60),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isDeficit ? Icons.trending_down : Icons.trending_up,
                        size: 18,
                        color: isDeficit
                            ? const Color(0xFFFFBA08)
                            : const Color(0xFFE85D04),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Expected Weight ${isDeficit ? "Loss" : "Gain"}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDeficit
                              ? const Color(0xFFFFBA08)
                              : const Color(0xFFE85D04),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _weightPrediction(
                        'Per Week',
                        '${kgPerWeek.abs().toStringAsFixed(2)} kg',
                        isDeficit,
                      ),
                      _weightPrediction(
                        'Per Month',
                        '${kgPerMonth.abs().toStringAsFixed(1)} kg',
                        isDeficit,
                      ),
                      _weightPrediction(
                        'In 3 Months',
                        '${(kgPerMonth * 3).abs().toStringAsFixed(1)} kg',
                        isDeficit,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Projected weights
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _projectedWeight('Now', _weight, cs.onSurface),
                      Icon(Icons.arrow_forward, size: 14, color: cs.outlineVariant),
                      _projectedWeight(
                        '1 Month',
                        isDeficit
                            ? _weight - kgPerMonth.abs()
                            : _weight + kgPerMonth.abs(),
                        isDeficit
                            ? const Color(0xFFFFBA08)
                            : const Color(0xFFE85D04),
                      ),
                      Icon(Icons.arrow_forward, size: 14, color: cs.outlineVariant),
                      _projectedWeight(
                        '3 Months',
                        isDeficit
                            ? _weight - (kgPerMonth * 3).abs()
                            : _weight + (kgPerMonth * 3).abs(),
                        isDeficit
                            ? const Color(0xFFFFBA08)
                            : const Color(0xFFE85D04),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '* Based on 7,700 kcal ≈ 1 kg body fat. Actual results vary.',
                    style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            // Safety warning for extreme deficits
            if (daily < 1200 && isDeficit) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withAlpha(60),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 18, color: cs.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Eating below 1200 kcal/day can be unsafe. Consult a doctor before extreme diets.',
                        style: TextStyle(fontSize: 11, color: cs.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _mathRow(String label, String value, Color valueColor) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weightPrediction(String period, String amount, bool isLoss) {
    return Column(
      children: [
        Text(period,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          '${isLoss ? "-" : "+"}$amount',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isLoss ? const Color(0xFFFFBA08) : const Color(0xFFE85D04),
          ),
        ),
      ],
    );
  }

  Widget _projectedWeight(String label, double weight, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(
          '${weight.toStringAsFixed(1)} kg',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _previewStat(String label, String value, String unit, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant)),
        Text(value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color,
            )),
        Text(unit,
            style: TextStyle(
                fontSize: 9,
                color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  // ─── Step 4: Summary ─────────────────────────────────────────────────────

  Widget _buildSummaryStep() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final weekly = _effectiveWeekly;
    final daily = (weekly / 7).round();
    final surplus = daily - _calcTdee;
    final waterGoal = ((_weight * 35) / 250).round() * 250;

    return Column(
      children: [
        // Big weekly budget card
        Container(
          width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withAlpha(30), cs.primary.withAlpha(10)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary.withAlpha(40)),
            ),
            child: Column(
              children: [
                Text('Weekly Budget',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  '$weekly kcal',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '~$daily kcal/day  ·  ${surplus >= 0 ? "+$surplus" : "$surplus"} vs TDEE',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stats grid
          Row(
            children: [
              _summaryCard(Icons.local_fire_department, cs.error,
                  'Daily Calories', '$daily kcal'),
              const SizedBox(width: 10),
              _summaryCard(
                  Icons.water_drop, const Color(0xFFF48C06), 'Daily Water', '$waterGoal ml'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _summaryCard(Icons.bolt, cs.primary, 'Your TDEE',
                  '$_calcTdee kcal'),
              const SizedBox(width: 10),
              _summaryCard(
                Icons.trending_down,
                surplus >= 0 ? const Color(0xFFE85D04) : const Color(0xFFFFBA08),
                surplus >= 0 ? 'Daily Surplus' : 'Daily Deficit',
                '${surplus.abs()} kcal',
              ),
            ],
          ),
          const SizedBox(height: 20),
          // User info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoPill('${_weight.toStringAsFixed(0)} kg'),
                _infoPill('${_height.toStringAsFixed(0)} cm'),
                _infoPill('$_age yrs'),
                _infoPill(_gender),
                _infoPill(_goalLabel),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can change any of these later',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _summaryCard(
      IconData icon, Color color, String label, String value) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10, color: cs.onSurfaceVariant)),
                  Text(value,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoPill(String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
    );
  }

  String get _goalLabel => switch (_weightGoal) {
        'lose' => 'Lose',
        'gain' => 'Gain',
        'custom' => 'Custom',
        _ => 'Maintain',
      };

  // ─── Navigation ──────────────────────────────────────────────────────────

  Widget _buildNav() {
    final isLast = _step == _totalSteps - 1;
    return Row(
      children: [
        if (_step > 0)
          TextButton(
            onPressed: () => setState(() => _step--),
            child: const Text('Back'),
          ),
        const Spacer(),
        // Step dots
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_totalSteps, (i) {
            final active = i == _step;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            );
          }),
        ),
        const Spacer(),
        Consumer(
          builder: (context, ref, _) => FilledButton(
            onPressed: _canProceed ? () => _next(ref) : null,
            child: Text(isLast ? 'Get Started' : 'Next'),
          ),
        ),
      ],
    );
  }

  bool get _canProceed {
    if (_step == 1 && _dob == null) return false;
    if (_step == 2 && _useCustomWeekly) {
      final v = int.tryParse(_weeklyCtrl.text);
      return v != null && v > 0;
    }
    return true;
  }

  void _next(WidgetRef ref) {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      return;
    }

    // Save profile
    final weekly = _effectiveWeekly;
    final profile = UserProfile(
      weightKg: _weight,
      heightCm: _height,
      age: _age,
      gender: _gender,
      weightGoal: _weightGoal,
      weeklyCalorieGoal: weekly,
      calorieGoal: (weekly / 7).round(),
      dobString: _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '',
    );

    ref.read(profileProvider.notifier).saveProfile(profile);

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
