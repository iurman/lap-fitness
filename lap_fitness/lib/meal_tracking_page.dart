import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MealTrackingPage extends StatefulWidget {
  @override
  _MealTrackingPageState createState() => _MealTrackingPageState();
}

class _MealTrackingPageState extends State<MealTrackingPage> {
  final mealNameController = TextEditingController();
  final proteinController = TextEditingController();
  final fatController = TextEditingController();
  final carbsController = TextEditingController();

  final mealsCollection = FirebaseFirestore.instance.collection('meals');

  List<Map<String, dynamic>> mealJournal = [];

  @override
  Widget build(BuildContext context) {
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
                  style: Theme.of(context).textTheme.headline6,
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
                ElevatedButton(
                  onPressed: submitMealForm,
                  child: Text('Add meal'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: mealJournal.length,
              itemBuilder: (context, index) {
                final meal = mealJournal[index];
                final name = meal['name'];
                final protein = meal['protein'];
                final fat = meal['fat'];
                final carbs = meal['carbs'];

                return ListTile(
                  title: Text(name),
                  subtitle: Text(
                    'Protein: $protein g, Fat: $fat g, Carbs: $carbs g',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> submitMealForm() async {
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
    final meal = {
      'name': mealName,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
    };
    setState(() {
      mealJournal.add(meal);
    });

    // Clear the form values
    mealNameController.clear();
    proteinController.clear();
    fatController.clear();
    carbsController.clear();
  }
}
