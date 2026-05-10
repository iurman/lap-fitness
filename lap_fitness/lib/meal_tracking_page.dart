import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'data/meal_repository.dart';

class MealTrackingPage extends StatefulWidget {
  const MealTrackingPage({super.key});

  @override
  State<MealTrackingPage> createState() => _MealTrackingPageState();
}

class _MealTrackingPageState extends State<MealTrackingPage> {
  final _mealNameController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbsController = TextEditingController();

  final MealRepository _repo = MealRepository();
  StreamSubscription<DatabaseEvent>? _sub;
  List<Map<String, dynamic>> _mealJournal = [];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    try {
      _sub = _repo.ref.onValue.listen((event) {
        _onMealsUpdate(event.snapshot);
      });
    } catch (_) {/* not signed in */}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mealNameController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  void _onMealsUpdate(DataSnapshot snapshot) {
    final meals = <Map<String, dynamic>>[];
    final value = snapshot.value;
    if (value is Map) {
      value.forEach((key, data) {
        meals.add({
          'key': key,
          'name': data['name'],
          'protein': data['protein'],
          'fat': data['fat'],
          'carbs': data['carbs'],
        });
      });
    }
    if (!mounted) return;
    setState(() => _mealJournal = meals);
  }

  Future<void> _deleteMeal(String key) => _repo.deleteMeal(key);

  Future<void> _submitMealForm() async {
    final mealName = _mealNameController.text.trim();
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final fat = double.tryParse(_fatController.text) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;

    if (mealName.isEmpty || (protein == 0.0 && fat == 0.0 && carbs == 0.0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a meal name and at least one macro value.'),
        ),
      );
      return;
    }

    await _repo.addMeal({
      'name': mealName,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
    });

    _mealNameController.clear();
    _proteinController.clear();
    _fatController.clear();
    _carbsController.clear();
  }

  Map<String, double> _totals() {
    double cal = 0, p = 0, f = 0, c = 0;
    for (final meal in _mealJournal) {
      final protein = (meal['protein'] as num?)?.toDouble() ?? 0;
      final fat = (meal['fat'] as num?)?.toDouble() ?? 0;
      final carbs = (meal['carbs'] as num?)?.toDouble() ?? 0;
      cal += 4 * protein + 9 * fat + 4 * carbs;
      p += protein;
      f += fat;
      c += carbs;
    }
    return {'calories': cal, 'protein': p, 'fat': f, 'carbs': c};
  }

  @override
  Widget build(BuildContext context) {
    final t = _totals();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add a meal',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: _mealNameController,
                    decoration: const InputDecoration(labelText: 'Meal name'),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _proteinController,
                          decoration:
                              const InputDecoration(labelText: 'Protein (g)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _fatController,
                          decoration:
                              const InputDecoration(labelText: 'Fat (g)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _carbsController,
                          decoration:
                              const InputDecoration(labelText: 'Carbs (g)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  FilledButton.icon(
                    onPressed: _submitMealForm,
                    icon: const Icon(Icons.add),
                    label: const Text('Add meal'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _TotalsCard(totals: t),
          const SizedBox(height: 8),
          if (_mealJournal.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No meals logged yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else
            ..._mealJournal.map(
              (meal) => Dismissible(
                key: Key(meal['key'] as String),
                background: _DismissBackground(),
                onDismissed: (_) => _deleteMeal(meal['key'] as String),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.brand,
                      child: Icon(Icons.restaurant_menu, color: Colors.white),
                    ),
                    title: Text('${meal['name']}'),
                    subtitle: Text(
                      '${meal['protein']}g P · ${meal['fat']}g F · ${meal['carbs']}g C',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteMeal(meal['key'] as String),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final Map<String, double> totals;
  const _TotalsCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Totals',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Metric(label: 'Calories', value: totals['calories']!),
                _Metric(
                    label: 'Protein',
                    value: totals['protein']!,
                    suffix: 'g'),
                _Metric(label: 'Fat', value: totals['fat']!, suffix: 'g'),
                _Metric(label: 'Carbs', value: totals['carbs']!, suffix: 'g'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final double value;
  final String suffix;
  const _Metric({required this.label, required this.value, this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(0)}$suffix',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.brand,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
      ],
    );
  }
}

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}
