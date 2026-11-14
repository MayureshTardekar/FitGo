import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/units.dart';
import '../models/user_profile.dart';
import '../providers/profile_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/units_provider.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../ui/components/fitgo_card.dart';
import '../ui/components/fitgo_mark.dart';
import '../ui/components/fitgo_primary_button.dart';
import '../ui/components/fitgo_segmented_control.dart';
import '../ui/theme/fitgo_tokens.dart';

/// Six-step onboarding: welcome, body details, activity, goal, reminders, and
/// a plan summary.
///
/// Values are kept in canonical units (kg/cm/ml) and only converted at the UI
/// edge. Progress is saved as an account-local draft so an interrupted setup
/// resumes where it stopped. Notification permission is requested only after
/// the user explicitly taps “Enable reminders”.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _totalSteps = 6;
  static const _draftKey = 'onboarding_draft_v1';
  static const _minimumAge = 13;

  static const _goalValues = ['lose', 'maintain', 'gain'];
  static const _paceValues = ['gentle', 'steady', 'ambitious'];
  static const _paceLabels = ['Gentle', 'Steady', 'Ambitious'];
  static const _genderValues = ['male', 'female', 'unspecified'];

  int _step = 0;

  UnitSystem _unitSystem = UnitSystem.metric;
  String _gender = 'male';
  DateTime? _dob;
  String _activity = 'light';
  String _goal = 'maintain';
  String _pace = 'steady';

  double _weightKg = 70;
  double _heightCm = 170;

  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  final _weeklyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _customBudget = false;

  bool _notificationsEnabled = false;
  bool _notificationBusy = false;
  bool _saving = false;

  int get _age {
    final dob = _dob;
    if (dob == null) return 25;
    return UserProfile.ageFromDob(dob);
  }

  double get _bmr {
    if (_weightKg <= 0 || _heightCm <= 0) return 0;
    final base = 10 * _weightKg + 6.25 * _heightCm - 5 * _age;
    return switch (_gender) {
      'male' => base + 5,
      'female' => base - 161,
      _ => (base + 5 + base - 161) / 2,
    };
  }

  int get _tdee {
    if (_bmr <= 0) return 0;
    return (_bmr * UserProfile.activityMultiplier(_activity)).round();
  }

  int get _dailyDelta {
    return switch (_goal) {
      'lose' => -switch (_pace) {
        'gentle' => 250,
        'ambitious' => 750,
        _ => 500,
      },
      'gain' => switch (_pace) {
        'gentle' => 150,
        'ambitious' => 450,
        _ => 300,
      },
      _ => 0,
    };
  }

  int get _suggestedWeekly {
    if (_tdee <= 0) return 0;
    return ((_tdee + _dailyDelta) * 7).round();
  }

  int get _weeklyTarget {
    if (_customBudget) {
      final value = int.tryParse(_weeklyCtrl.text.trim());
      if (value != null && value > 0) return value;
    }
    return _suggestedWeekly;
  }

  int get _dailyTarget => _weeklyTarget <= 0 ? 0 : (_weeklyTarget / 7).round();

  int get _waterGoalMl {
    if (_weightKg <= 0) return 2000;
    return ((_weightKg * 35) / 250).round() * 250;
  }

  bool get _aboutValid {
    final dob = _dob;
    if (dob == null) return false;
    if (UserProfile.ageFromDob(dob) < _minimumAge) return false;
    return _weightKg >= 30 &&
        _weightKg <= 300 &&
        _heightCm >= 120 &&
        _heightCm <= 230;
  }

  bool get _canContinue {
    return switch (_step) {
      1 => _aboutValid,
      3 => !_customBudget || (int.tryParse(_weeklyCtrl.text.trim()) ?? 0) > 0,
      5 => !_saving,
      _ => true,
    };
  }

  @override
  void initState() {
    super.initState();
    _unitSystem = ref.read(unitSystemProvider);
    _weightCtrl = TextEditingController(text: _weightInput(_weightKg));
    _heightCtrl = TextEditingController(text: _heightInput(_heightCm));
    _loadDraft();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _weeklyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Draft ─────────────────────────────────────────────────────────────

  void _loadDraft() {
    final storage = ref.read(localStorageProvider);
    final raw = storage.getSetting<String>(_draftKey, '');
    if (raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);

      final unit = map['unitSystem'];
      _unitSystem = unit == 'imperial'
          ? UnitSystem.imperial
          : UnitSystem.metric;

      final gender = map['gender'];
      if (_genderValues.contains(gender)) _gender = gender as String;

      final dob = map['dob'];
      if (dob is String) _dob = DateTime.tryParse(dob);

      final activity = map['activity'];
      if (UserProfile.activityLevels.contains(activity)) {
        _activity = activity as String;
      }

      final goal = map['goal'];
      if (_goalValues.contains(goal)) _goal = goal as String;

      final pace = map['pace'];
      if (_paceValues.contains(pace)) _pace = pace as String;

      final weight = map['weightKg'];
      if (weight is num && weight >= 30 && weight <= 300) {
        _weightKg = weight.toDouble();
      }

      final height = map['heightCm'];
      if (height is num && height >= 120 && height <= 230) {
        _heightCm = height.toDouble();
      }

      _customBudget = map['customBudget'] == true;
      final weekly = map['weekly'];
      if (weekly is num && weekly > 0) {
        _weeklyCtrl.text = weekly.round().toString();
      }

      final step = map['step'];
      if (step is int) {
        _step = step.clamp(0, _totalSteps - 2).toInt();
      }

      _weightCtrl.text = _weightInput(_weightKg);
      _heightCtrl.text = _heightInput(_heightCm);
    } catch (_) {
      // A corrupt draft is ignored; onboarding starts from the beginning.
    }
  }

  void _persistDraft() {
    unawaited(_persistDraftNow());
  }

  Future<void> _persistDraftNow() async {
    final map = <String, Object?>{
      'step': _step,
      'unitSystem': _unitSystem.name,
      'gender': _gender,
      'dob': _dob?.toIso8601String(),
      'activity': _activity,
      'goal': _goal,
      'pace': _pace,
      'weightKg': _weightKg,
      'heightCm': _heightCm,
      'customBudget': _customBudget,
      'weekly': _customBudget ? int.tryParse(_weeklyCtrl.text.trim()) : null,
    };
    await ref
        .read(localStorageProvider)
        .saveLocalSetting(_draftKey, jsonEncode(map));
  }

  // ─── Formatting ────────────────────────────────────────────────────────

  String _trim(double value, int decimals) {
    var text = value.toStringAsFixed(decimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }

  String _weightInput(double kg) => _trim(_unitSystem.weightFromKg(kg), 1);

  String _heightInput(double cm) => _trim(
    _unitSystem.isMetric ? cm : _unitSystem.heightFromCm(cm),
    _unitSystem.isMetric ? 0 : 1,
  );

  String _formatKcal(int value) => NumberFormat.decimalPattern().format(value);

  String _activityLabel(String value) => switch (value) {
    'sedentary' => 'Sedentary',
    'moderate' => 'Moderately active',
    'active' => 'Very active',
    _ => 'Lightly active',
  };

  String _activityDescription(String value) => switch (value) {
    'sedentary' => 'Desk job, little planned exercise',
    'moderate' => 'Exercise 3–5 days a week',
    'active' => 'Hard exercise 6–7 days a week',
    _ => 'Light exercise 1–3 days a week',
  };

  IconData _activityIcon(String value) => switch (value) {
    'sedentary' => Icons.chair_outlined,
    'moderate' => Icons.directions_run,
    'active' => Icons.fitness_center,
    _ => Icons.directions_walk,
  };

  String _goalLabel(String value) => switch (value) {
    'lose' => 'Lose weight',
    'gain' => 'Gain weight',
    _ => 'Maintain weight',
  };

  String get _goalPillLabel => switch (_goal) {
    'lose' => 'Lose',
    'gain' => 'Gain',
    _ => 'Maintain',
  };

  // ─── Body ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _buildTopBar(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _buildStep(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _buildNav(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final canGoBack =
        _step > 0 || (GoRouter.maybeOf(context)?.canPop() ?? false);

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 48,
              child: canGoBack
                  ? IconButton(
                      onPressed: _back,
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back),
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                _step == 0 ? 'FitGo' : 'Step ${_step + 1} of $_totalSteps',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: _step == 0
                  ? null
                  : Text(
                      '${((_step + 1) / _totalSteps * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
            ),
          ],
        ),
        if (_step > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_step + 1) / _totalSteps,
              minHeight: 4,
              backgroundColor: tokens.surfaceMuted,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _buildWelcomeStep(),
      1 => _buildAboutStep(),
      2 => _buildActivityStep(),
      3 => _buildGoalStep(),
      4 => _buildReminderStep(),
      _ => _buildSummaryStep(),
    };
  }

  Widget _buildNav() {
    final isLast = _step == _totalSteps - 1;

    if (_step == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FitGoPrimaryButton(
            label: 'Get started',
            icon: Icons.arrow_forward,
            onPressed: _next,
          ),
          if (!SupabaseService.isLoggedIn)
            TextButton(
              onPressed: () => context.go('/auth'),
              child: const Text('I already have an account'),
            ),
        ],
      );
    }

    return Row(
      children: [
        TextButton(
          onPressed: _saving ? null : _back,
          child: const Text('Back'),
        ),
        const SizedBox(width: FitGoSpacing.xs),
        Expanded(
          child: FitGoPrimaryButton(
            label: isLast ? 'Start using FitGo' : 'Continue',
            icon: isLast ? Icons.check : Icons.arrow_forward,
            loading: _saving,
            onPressed: _canContinue ? _next : null,
          ),
        ),
      ],
    );
  }

  // ─── Step 1: Welcome ───────────────────────────────────────────────────

  Widget _buildWelcomeStep() {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Center(child: FitGoMark(size: 76)),
        const SizedBox(height: 24),
        Text(
          'Your day, in one place',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Track food, fasting, water, movement, sleep, and weight without '
          'turning your health into an ad profile.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: tokens.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        _welcomePoint(
          Icons.wifi_off_rounded,
          'Works offline',
          'Your logs stay available without a connection.',
        ),
        _welcomePoint(
          Icons.lock_outline_rounded,
          'Private by default',
          'You decide if and when data syncs to the cloud.',
        ),
        _welcomePoint(
          Icons.auto_graph_rounded,
          'Built around your week',
          'A flexible weekly calorie budget instead of a daily guilt meter.',
        ),
      ],
    );
  }

  Widget _welcomePoint(IconData icon, String title, String body) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: FitGoSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.ember.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(FitGoRadii.cardSmall),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: FitGoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 2: About you ─────────────────────────────────────────────────

  Widget _buildAboutStep() {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeading(
          'About you',
          'FitGo uses this to estimate your energy needs. You can change it '
              'later in Profile.',
        ),
        const SizedBox(height: FitGoSpacing.lg),
        FitGoSegmentedControl<UnitSystem>(
          values: UnitSystem.values,
          labels: const ['Metric', 'Imperial'],
          selected: _unitSystem,
          onChanged: _setUnitSystem,
        ),
        const SizedBox(height: FitGoSpacing.lg),
        Text(
          'Sex used for the calorie estimate',
          style: theme.textTheme.labelLarge?.copyWith(
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: FitGoSpacing.xs),
        Wrap(
          spacing: FitGoSpacing.xs,
          runSpacing: FitGoSpacing.xs,
          children: [
            _genderChip('Male', 'male'),
            _genderChip('Female', 'female'),
            _genderChip('Prefer not to say', 'unspecified'),
          ],
        ),
        const SizedBox(height: FitGoSpacing.lg),
        _dobCard(),
        const SizedBox(height: FitGoSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _numberField(
                controller: _weightCtrl,
                label: 'Weight',
                suffix: _unitSystem.weightLabel,
                onChanged: _onWeightChanged,
              ),
            ),
            const SizedBox(width: FitGoSpacing.sm),
            Expanded(
              child: _numberField(
                controller: _heightCtrl,
                label: 'Height',
                suffix: _unitSystem.heightLabel,
                onChanged: _onHeightChanged,
              ),
            ),
          ],
        ),
        if (!_unitSystem.isMetric) ...[
          const SizedBox(height: FitGoSpacing.xs),
          Text(
            formatFeetInches(_heightCm),
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: FitGoSpacing.lg),
        _energyPreview(),
      ],
    );
  }

  Widget _genderChip(String label, String value) {
    final selected = _gender == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _gender = value);
        _persistDraft();
      },
    );
  }

  Widget _dobCard() {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final dob = _dob;

    return InkWell(
      borderRadius: BorderRadius.circular(FitGoRadii.cardSmall),
      onTap: _pickDob,
      child: Container(
        padding: const EdgeInsets.all(FitGoSpacing.md),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(FitGoRadii.cardSmall),
          border: Border.all(color: dob == null ? tokens.border : tokens.ember),
        ),
        child: Row(
          children: [
            Icon(Icons.cake_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: FitGoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date of birth',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                  Text(
                    dob == null
                        ? 'Tap to select'
                        : '${DateFormat('d MMM yyyy').format(dob)} · $_age years old',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: tokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FitGoRadii.input),
        ),
      ),
    );
  }

  Widget _energyPreview() {
    if (_tdee <= 0) return const SizedBox.shrink();
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return FitGoCard(
      color: tokens.surfaceMuted,
      padding: const EdgeInsets.all(FitGoSpacing.md),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: FitGoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated daily burn',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                Text(
                  '${_formatKcal(_tdee)} kcal/day',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '×${UserProfile.activityMultiplier(_activity).toStringAsFixed(2)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final latest = DateTime(now.year - _minimumAge, now.month, now.day);
    final initial = _dob ?? DateTime(now.year - 25, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(latest) ? latest : initial,
      firstDate: DateTime(1930),
      lastDate: latest,
      helpText: 'Select your date of birth',
    );
    if (picked == null) return;
    setState(() => _dob = picked);
    await _persistDraftNow();
  }

  void _onWeightChanged(String text) {
    final parsed = double.tryParse(text.trim());
    setState(() {
      _weightKg = parsed == null ? 0 : _unitSystem.weightToKg(parsed);
    });
  }

  void _onHeightChanged(String text) {
    final parsed = double.tryParse(text.trim());
    setState(() {
      _heightCm = parsed == null ? 0 : _unitSystem.heightToCm(parsed);
    });
  }

  void _setUnitSystem(UnitSystem system) {
    if (system == _unitSystem) return;
    final kg = _weightKg;
    final cm = _heightCm;
    setState(() {
      _unitSystem = system;
      _weightCtrl.text = _weightInput(kg);
      _heightCtrl.text = _heightInput(cm);
    });
    unawaited(_persistDraftNow());
  }

  // ─── Step 3: Activity ──────────────────────────────────────────────────

  Widget _buildActivityStep() {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeading(
          'How active is a typical week?',
          'This adjusts the calories your body burns. Choose your normal week, '
              'not your best one.',
        ),
        const SizedBox(height: FitGoSpacing.lg),
        for (final value in UserProfile.activityLevels)
          Padding(
            padding: const EdgeInsets.only(bottom: FitGoSpacing.sm),
            child: _selectionCard(
              selected: _activity == value,
              onTap: () {
                setState(() => _activity = value);
                _persistDraft();
              },
              leading: Icon(
                _activityIcon(value),
                color: _activity == value
                    ? theme.colorScheme.primary
                    : tokens.textSecondary,
              ),
              title: _activityLabel(value),
              subtitle: _activityDescription(value),
              trailing: Text(
                '×${UserProfile.activityMultiplier(value).toStringAsFixed(2)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
          ),
        const SizedBox(height: FitGoSpacing.xs),
        _energyPreview(),
      ],
    );
  }

  // ─── Step 4: Goal ──────────────────────────────────────────────────────

  Widget _buildGoalStep() {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeading(
          'What are you working toward?',
          'FitGo turns your goal into a weekly calorie budget, then shows the '
              'daily number.',
        ),
        const SizedBox(height: FitGoSpacing.lg),
        _selectionCard(
          selected: _goal == 'lose',
          onTap: () {
            setState(() => _goal = 'lose');
            _persistDraft();
          },
          leading: Icon(
            Icons.trending_down,
            color: _goal == 'lose'
                ? theme.colorScheme.primary
                : tokens.textSecondary,
          ),
          title: 'Lose weight',
          subtitle: 'A steady calorie deficit',
        ),
        const SizedBox(height: FitGoSpacing.sm),
        _selectionCard(
          selected: _goal == 'maintain',
          onTap: () {
            setState(() => _goal = 'maintain');
            _persistDraft();
          },
          leading: Icon(
            Icons.balance,
            color: _goal == 'maintain'
                ? theme.colorScheme.primary
                : tokens.textSecondary,
          ),
          title: 'Maintain weight',
          subtitle: 'Match the energy you burn',
        ),
        const SizedBox(height: FitGoSpacing.sm),
        _selectionCard(
          selected: _goal == 'gain',
          onTap: () {
            setState(() => _goal = 'gain');
            _persistDraft();
          },
          leading: Icon(
            Icons.trending_up,
            color: _goal == 'gain'
                ? theme.colorScheme.primary
                : tokens.textSecondary,
          ),
          title: 'Gain weight',
          subtitle: 'A controlled calorie surplus',
        ),
        if (_goal != 'maintain') ...[
          const SizedBox(height: FitGoSpacing.lg),
          Text(
            'Pace',
            style: theme.textTheme.labelLarge?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: FitGoSpacing.xs),
          FitGoSegmentedControl<String>(
            values: _paceValues,
            labels: _paceLabels,
            selected: _pace,
            onChanged: (value) {
              setState(() => _pace = value);
              _persistDraft();
            },
          ),
          const SizedBox(height: FitGoSpacing.xs),
          Text(
            '${_dailyDelta.abs()} kcal/day '
            '${_goal == 'lose' ? 'deficit' : 'surplus'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: FitGoSpacing.md),
        SwitchListTile.adaptive(
          value: _customBudget,
          onChanged: (value) {
            setState(() {
              _customBudget = value;
              if (!value) _weeklyCtrl.clear();
            });
            _persistDraft();
          },
          contentPadding: EdgeInsets.zero,
          title: const Text('Set a custom weekly budget'),
          subtitle: const Text('For a target from your coach or dietitian.'),
        ),
        if (_customBudget) ...[
          const SizedBox(height: FitGoSpacing.xs),
          TextField(
            controller: _weeklyCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {});
              _persistDraft();
            },
            decoration: InputDecoration(
              labelText: 'Weekly calorie budget',
              hintText: 'e.g. 14,000',
              suffixText: 'kcal/week',
              prefixIcon: const Icon(Icons.edit_calendar_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FitGoRadii.input),
              ),
            ),
          ),
        ],
        const SizedBox(height: FitGoSpacing.lg),
        _planPreview(),
      ],
    );
  }

  Widget _planPreview() {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final tdee = _tdee;
    final daily = _dailyTarget;
    final weekly = _weeklyTarget;
    if (tdee <= 0 || weekly <= 0) {
      return Text(
        'Add your body details to see a plan preview.',
        style: theme.textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
      );
    }

    final delta = daily - tdee;
    final isDeficit = delta < 0;
    final kgPerWeek = (delta.abs() * 7 / 7700);

    return FitGoCard(
      color: tokens.surfaceMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _planStat(
                  'Weekly budget',
                  '${_formatKcal(weekly)} kcal',
                ),
              ),
              Container(width: 1, height: 40, color: tokens.border),
              Expanded(
                child: _planStat('Daily intake', '${_formatKcal(daily)} kcal'),
              ),
            ],
          ),
          const Divider(height: FitGoSpacing.xl),
          _planRow('Estimated burn', '${_formatKcal(tdee)} kcal'),
          if (delta != 0)
            _planRow(
              isDeficit ? 'Daily deficit' : 'Daily surplus',
              '${_formatKcal(delta.abs())} kcal',
            ),
          if (kgPerWeek >= 0.01) ...[
            const SizedBox(height: FitGoSpacing.xs),
            Text(
              'About ${kgPerWeek.toStringAsFixed(2)} kg '
              '${isDeficit ? 'lost' : 'gained'} per week at this pace.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
          if (isDeficit && daily < 1200) ...[
            const SizedBox(height: FitGoSpacing.sm),
            _safetyWarning(
              'Eating below 1,200 kcal/day can be unsafe. Talk to a doctor '
              'before an extreme diet.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _planStat(String label, String value) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
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
          style: theme.textTheme.titleMedium?.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _planRow(String label, String value) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _safetyWarning(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(FitGoSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(FitGoRadii.input),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: FitGoSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 5: Reminders ─────────────────────────────────────────────────

  Widget _buildReminderStep() {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FitGoSpacing.md),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: tokens.ember.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: FitGoSpacing.lg),
        Text(
          'Stay on track without watching the clock',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: FitGoSpacing.xs),
        Text(
          'FitGo can nudge you at the right moment. Reminders are scheduled on '
          'this device — never sold or used for ads.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: tokens.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: FitGoSpacing.lg),
        _benefitRow(
          Icons.timer_outlined,
          'Fasting check-ins',
          'Gentle reminders while a fast is running.',
        ),
        _benefitRow(
          Icons.water_drop_outlined,
          'Hydration nudges',
          'A reminder to drink water during your fast.',
        ),
        _benefitRow(
          Icons.calendar_month_outlined,
          'Monthly calorie warning',
          'A heads-up before you pass your monthly budget.',
        ),
        const SizedBox(height: FitGoSpacing.lg),
        if (_notificationsEnabled)
          Container(
            padding: const EdgeInsets.all(FitGoSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(FitGoRadii.cardSmall),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: FitGoSpacing.sm),
                Expanded(
                  child: Text(
                    'Reminders are enabled',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          FitGoPrimaryButton(
            label: 'Enable reminders',
            icon: Icons.notifications_none,
            loading: _notificationBusy,
            onPressed: _notificationBusy ? null : _enableReminders,
          ),
        const SizedBox(height: FitGoSpacing.xs),
        Text(
          'You can skip this and turn notifications on later in Profile.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _benefitRow(IconData icon, String title, String body) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: FitGoSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.surfaceMuted,
              borderRadius: BorderRadius.circular(FitGoRadii.cardSmall),
            ),
            child: Icon(icon, size: 20, color: tokens.textSecondary),
          ),
          const SizedBox(width: FitGoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enableReminders() async {
    if (_notificationBusy) return;
    setState(() => _notificationBusy = true);

    final granted = await NotificationService.requestPermission();
    if (!mounted) return;

    setState(() {
      _notificationBusy = false;
      _notificationsEnabled = granted;
    });

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are off. You can enable them later in device '
            'settings or Profile.',
          ),
        ),
      );
    }
  }

  // ─── Step 6: Summary ───────────────────────────────────────────────────

  Widget _buildSummaryStep() {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final weekly = _weeklyTarget;
    final daily = _dailyTarget;
    final delta = daily - _tdee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeading(
          'You’re all set',
          'Here’s the plan FitGo will start with. Every number can be adjusted '
              'later.',
        ),
        const SizedBox(height: FitGoSpacing.lg),
        FitGoCard(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.ember.withValues(alpha: 0.16),
              tokens.amber.withValues(alpha: 0.08),
            ],
          ),
          borderColor: tokens.ember.withValues(alpha: 0.35),
          padding: const EdgeInsets.all(FitGoSpacing.xl),
          child: Column(
            children: [
              Text(
                'Weekly calorie budget',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatKcal(weekly)} kcal',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatKcal(daily)} kcal/day',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              if (delta != 0) ...[
                const SizedBox(height: FitGoSpacing.sm),
                Text(
                  '${_formatKcal(delta.abs())} kcal/day '
                  '${delta < 0 ? 'deficit' : 'surplus'} vs. your estimated burn',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: FitGoSpacing.md),
        Row(
          children: [
            Expanded(
              child: _summaryStat(
                Icons.local_fire_department_outlined,
                'Daily intake',
                '${_formatKcal(daily)} kcal',
              ),
            ),
            const SizedBox(width: FitGoSpacing.sm),
            Expanded(
              child: _summaryStat(
                Icons.water_drop_outlined,
                'Water goal',
                _unitSystem.formatVolume(_waterGoalMl.toDouble()),
              ),
            ),
          ],
        ),
        const SizedBox(height: FitGoSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _summaryStat(
                Icons.bolt_outlined,
                'Estimated burn',
                '${_formatKcal(_tdee)} kcal',
              ),
            ),
            const SizedBox(width: FitGoSpacing.sm),
            Expanded(
              child: _summaryStat(
                Icons.flag_outlined,
                'Goal',
                _goalLabel(_goal),
              ),
            ),
          ],
        ),
        const SizedBox(height: FitGoSpacing.md),
        Wrap(
          spacing: FitGoSpacing.xs,
          runSpacing: FitGoSpacing.xs,
          children: [
            _infoPill(_unitSystem.isMetric ? 'Metric' : 'Imperial'),
            _infoPill(_activityLabel(_activity)),
            _infoPill(_goalPillLabel),
            _infoPill(_notificationsEnabled ? 'Reminders on' : 'Reminders off'),
          ],
        ),
        const SizedBox(height: FitGoSpacing.md),
        Text(
          'Estimates use the Mifflin–St Jeor equation. FitGo is a tracking tool, '
          'not medical advice.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: tokens.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _summaryStat(IconData icon, String label, String value) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(FitGoSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(FitGoRadii.cardSmall),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: tokens.textSecondary),
          const SizedBox(width: FitGoSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(String label) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FitGoSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(FitGoRadii.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── Shared widgets ────────────────────────────────────────────────────

  Widget _stepHeading(String title, String subtitle) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: FitGoSpacing.xs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: tokens.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _selectionCard({
    required bool selected,
    required VoidCallback onTap,
    required Widget leading,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return FitGoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FitGoSpacing.md),
      color: selected ? tokens.ember.withValues(alpha: 0.08) : tokens.surface,
      borderColor: selected ? tokens.ember : tokens.border,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? tokens.ember.withValues(alpha: 0.14)
                  : tokens.surfaceMuted,
              borderRadius: BorderRadius.circular(FitGoRadii.cardSmall),
            ),
            child: Center(child: leading),
          ),
          const SizedBox(width: FitGoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: FitGoSpacing.xs),
            trailing,
          ],
          const SizedBox(width: FitGoSpacing.xs),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            color: selected ? tokens.ember : tokens.textSecondary,
            size: 22,
          ),
        ],
      ),
    );
  }

  // ─── Navigation ────────────────────────────────────────────────────────

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (!_canContinue) return;

    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      await _persistDraftNow();
      _scrollToTop();
      return;
    }

    await _finish();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    });
  }

  Future<void> _back() async {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      GoRouter.maybeOf(context)?.pop();
      return;
    }
    setState(() => _step--);
    await _persistDraftNow();
    _scrollToTop();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await ref.read(unitSystemProvider.notifier).setSystem(_unitSystem);
      await ref.read(localStorageProvider).saveLocalSetting(_draftKey, '');

      final profile = UserProfile(
        weightKg: _weightKg,
        heightCm: _heightCm,
        age: _age,
        gender: _gender,
        weightGoal: _goal,
        weeklyCalorieGoal: _weeklyTarget,
        calorieGoal: _dailyTarget,
        dobString: _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '',
        activityLevel: _activity,
      );

      await ref.read(profileProvider.notifier).saveProfile(profile);
      if (!mounted) return;
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your profile. Please try again.'),
        ),
      );
    }
  }
}
