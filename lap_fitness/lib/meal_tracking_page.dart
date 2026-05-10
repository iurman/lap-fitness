import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'data/meal_repository.dart';

class MealTrackingPage extends StatefulWidget {
  const MealTrackingPage({Key? key}) : super(key: key);

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a meal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _mealNameController,
                  decoration: const InputDecoration(labelText: 'Meal name'),
                ),
                const SizedBox(height: 8.0),
                TextFormField(
                  controller: _proteinController,
                  decoration: const InputDecoration(labelText: 'Protein (g)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8.0),
                TextFormField(
                  controller: _fatController,
                  decoration: const InputDecoration(labelText: 'Fat (g)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8.0),
                TextFormField(
                  controller: _carbsController,
                  decoration: const InputDecoration(labelText: 'Carbs (g)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16.0),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                    ),
                    onPressed: _submitMealForm,
                    child: const Text('Add meal'),
                  ),
                ),
                const SizedBox(height: 16.0),
                Center(
                  child: Text(
                    'Total Calories: ${t['calories']!.toStringAsFixed(2)} cal\n'
                    'Total Protein: ${t['protein']!.toStringAsFixed(2)} g\n'
                    'Total Fat: ${t['fat']!.toStringAsFixed(2)} g\n'
                    'Total Carbs: ${t['carbs']!.toStringAsFixed(2)} g',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _mealJournal.length,
              itemBuilder: (context, index) {
                final meal = _mealJournal[index];
                return Dismissible(
                  key: Key(meal['key'] as String),
                  onDismissed: (_) => _deleteMeal(meal['key'] as String),
                  child: Card(
                    child: ListTile(
                      title: Text('${meal['name']}'),
                      subtitle: Text(
                        '${meal['protein']}g P | ${meal['fat']}g F | ${meal['carbs']}g C',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteMeal(meal['key'] as String),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
