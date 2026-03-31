import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/daily_metrics.dart';
import '../models/weight_entry.dart';
import '../providers/calorie_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/weight_provider.dart';

class PastDayLogScreen extends StatefulWidget {
  const PastDayLogScreen({super.key});

  @override
  State<PastDayLogScreen> createState() => _PastDayLogScreenState();
}

class _PastDayLogScreenState extends State<PastDayLogScreen> {
  late DateTime _selectedDate;
  final _caloriesCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().subtract(const Duration(days: 1));
  }

  @override
  void dispose() {
    _caloriesCtrl.dispose();
    _waterCtrl.dispose();
    _stepsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();

    // Generate last 5 days (excluding today)
    final days = List.generate(5, (i) => now.subtract(Duration(days: i + 1)));

    return Scaffold(
      appBar: AppBar(title: const Text('Log Past Day')),
      body: Consumer(
        builder: (context, ref, _) {
          // Load existing data for selected date
          _loadExistingData(ref);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Date selector chips
              Text('Select a day',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final date = days[i];
                    final isSelected = _isSameDay(date, _selectedDate);
                    final dayName = DateFormat('EEE').format(date);
                    final dayNum = date.day.toString();
                    final month = DateFormat('MMM').format(date);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                          _saved = false;
                          _clearFields();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 60,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary.withAlpha(25)
                              : cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                isSelected ? cs.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(dayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                )),
                            Text(dayNum,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? cs.primary
                                      : cs.onSurface,
                                )),
                            Text(month,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Logging for: ${DateFormat('EEEE, d MMM yyyy').format(_selectedDate)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // Fields
              _buildField(
                icon: Icons.local_fire_department,
                label: 'Calories consumed',
                hint: 'e.g. 1500',
                suffix: 'kcal',
                controller: _caloriesCtrl,
                color: cs.error,
              ),
              const SizedBox(height: 16),
              _buildField(
                icon: Icons.water_drop,
                label: 'Water intake',
                hint: 'e.g. 2500',
                suffix: 'ml',
                controller: _waterCtrl,
                color: cs.primary,
              ),
              const SizedBox(height: 16),
              _buildField(
                icon: Icons.directions_walk,
                label: 'Steps walked',
                hint: 'e.g. 8000',
                suffix: 'steps',
                controller: _stepsCtrl,
                color: cs.primary,
              ),
              const SizedBox(height: 16),
              _buildField(
                icon: Icons.monitor_weight_outlined,
                label: 'Weight (optional)',
                hint: 'e.g. 75.5',
                suffix: 'kg',
                controller: _weightCtrl,
                color: cs.tertiary,
                isDecimal: true,
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _saved ? null : () => _save(ref),
                  icon: Icon(_saved ? Icons.check : Icons.save),
                  label: Text(_saved ? 'Saved!' : 'Save'),
                ),
              ),

              if (_saved) ...[
                const SizedBox(height: 12),
                Text(
                  'Data saved for ${DateFormat('d MMM').format(_selectedDate)}',
                  style: TextStyle(color: cs.primary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildField({
    required IconData icon,
    required String label,
    required String hint,
    required String suffix,
    required TextEditingController controller,
    required Color color,
    bool isDecimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: Icon(icon, color: color),
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) {
        if (_saved) setState(() => _saved = false);
      },
    );
  }

  void _loadExistingData(WidgetRef ref) {
    final storage = ref.read(localStorageProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final existing = storage.getMetricsForDate(dateKey);

    if (existing != null &&
        _caloriesCtrl.text.isEmpty &&
        _waterCtrl.text.isEmpty &&
        _stepsCtrl.text.isEmpty) {
      if (existing.totalCalories > 0) {
        _caloriesCtrl.text = existing.totalCalories.toString();
      }
      if (existing.waterMl > 0) {
        _waterCtrl.text = existing.waterMl.toString();
      }
      if (existing.steps > 0) {
        _stepsCtrl.text = existing.steps.toString();
      }
      if (existing.weight != null) {
        _weightCtrl.text = existing.weight.toString();
      }
    }
  }

  void _clearFields() {
    _caloriesCtrl.clear();
    _waterCtrl.clear();
    _stepsCtrl.clear();
    _weightCtrl.clear();
  }

  void _save(WidgetRef ref) {
    final storage = ref.read(localStorageProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Get existing or create new
    final metrics = storage.getMetricsForDate(dateKey) ??
        DailyMetrics(dateKey: dateKey);

    final cal = int.tryParse(_caloriesCtrl.text);
    final water = int.tryParse(_waterCtrl.text);
    final steps = int.tryParse(_stepsCtrl.text);
    final weight = double.tryParse(_weightCtrl.text);

    if (cal != null) {
      metrics.totalCalories = cal;
      metrics.calorieEntries = [cal];
    }
    if (water != null) metrics.waterMl = water;
    if (steps != null) metrics.steps = steps;
    if (weight != null) metrics.weight = weight;

    storage.saveMetrics(metrics);

    // Invalidate calorie provider so weekly analytics / trend chart refresh
    ref.invalidate(calorieProvider);

    // Also save weight entry if provided
    if (weight != null) {
      final entry = WeightEntry(dateKey: dateKey, weight: weight);
      storage.saveWeight(entry);
      ref.invalidate(weightProvider);
    }

    setState(() => _saved = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Saved data for ${DateFormat('d MMM').format(_selectedDate)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
