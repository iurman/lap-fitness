// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, prefer_const_constructors

import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/data/auth_repository.dart';
import '../data/meals_repository.dart';
import '../domain/meal.dart';

class MealTrackingPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<MealTrackingPage> createState() => _MealTrackingPageState();
}

class _MealTrackingPageState extends ConsumerState<MealTrackingPage> {
  final mealNameController = TextEditingController();
  final proteinController = TextEditingController();
  final fatController = TextEditingController();
  final carbsController = TextEditingController();

  AuthRepository get _authRepo => ref.read(authRepositoryProvider);
  MealsRepository get _mealsRepo => ref.read(mealsRepositoryProvider);
  late final String _uid;

  List<Meal> mealJournal = [];

  StreamSubscription<List<Meal>>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _uid = _authRepo.currentUid!;
    _streamSubscription = _mealsRepo.watchMeals(_uid).listen((meals) {
      if (!mounted) return;
      setState(() {
        mealJournal = meals;
      });
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  void deleteMeal(String mealKey) async {
    await _mealsRepo.deleteMeal(_uid, mealKey);
  }

  void submitMealForm() async {
    // Get the form values
    final mealName = mealNameController.text;
    final protein = double.tryParse(proteinController.text) ?? 0.0;
    final fat = double.tryParse(fatController.text) ?? 0.0;
    final carbs = double.tryParse(carbsController.text) ?? 0.0;

    // Validate the form values
    if (mealName.isEmpty || protein == 0.0 && fat == 0.0 && carbs == 0.0) {
      return;
    }

    // Add the meal to the journal
    final meal = Meal(
      key: '',
      name: mealName,
      protein: protein,
      fat: fat,
      carbs: carbs,
    );
    await _mealsRepo.addMeal(_uid, meal);

    // Clear the form values
    mealNameController.clear();
    proteinController.clear();
    fatController.clear();
    carbsController.clear();
  }

  @override
  Widget build(BuildContext context) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalFat = 0;
    double totalCarbs = 0;

    // calculate the total calories, protein, fat, and carbs for the day
    for (final meal in mealJournal) {
      totalCalories += meal.calories;
      totalProtein += meal.protein;
      totalFat += meal.fat;
      totalCarbs += meal.carbs;
    }

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
                SizedBox(height: 16.0),
                TextFormField(
                  controller: mealNameController,
                  decoration: InputDecoration(
                    labelText: 'Meal name',
                  ),
                ),
                SizedBox(height: 8.0),
                TextFormField(
                  controller: proteinController,
                  decoration: InputDecoration(
                    labelText: 'Protein (g)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 8.0),
                TextFormField(
                  controller: fatController,
                  decoration: InputDecoration(
                    labelText: 'Fat (g)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 8.0),
                TextFormField(
                  controller: carbsController,
                  decoration: InputDecoration(
                    labelText: 'Carbs (g)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16.0),
                Center(
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all<Color>(
                        AppColors.brand,
                      ),
                    ),
                    onPressed: submitMealForm,
                    child: Text('Add meal'),
                  ),
                ),
                SizedBox(height: 16.0),
                // show the total calories, protein, fat, and carbs for the day
                Center(
                  child: Text(
                    'Total Calories: ${totalCalories.toStringAsFixed(2)} cal\n'
                    'Total Protein: ${totalProtein.toStringAsFixed(2)} g\n'
                    'Total Fat: ${totalFat.toStringAsFixed(2)} g\n'
                    'Total Carbs: ${totalCarbs.toStringAsFixed(2)} g',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: mealJournal.length,
              itemBuilder: (BuildContext context, int index) {
                final meal = mealJournal[index];
                return Dismissible(
                  key: Key(meal.key),
                  onDismissed: (direction) {
                    deleteMeal(meal.key);
                    setState(() {
                      mealJournal.removeAt(index);
                    });
                  },
                  child: Card(
                    child: ListTile(
                      title: Text(meal.name),
                      subtitle: Text(
                        '${meal.protein}g P | ${meal.fat}g F | ${meal.carbs}g C',
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          deleteMeal(meal.key);
                        },
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
