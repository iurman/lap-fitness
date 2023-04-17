// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, deprecated_member_use, duplicate_ignore, prefer_const_constructors

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
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

  late DatabaseReference mealsReference;

  List<Map<String, dynamic>> mealJournal = [];

  late StreamSubscription<DatabaseEvent> _streamSubscription;

  @override
  void initState() {
    super.initState();

    // Get the current user ID
    final currentUserID = FirebaseAuth.instance.currentUser!.uid;

    // Update the meals reference to include the user ID
    // ignore: deprecated_member_use
    mealsReference = FirebaseDatabase.instance
        .reference()
        .child('meals')
        .child(currentUserID);

    // Listen to changes in the meals node in Firebase Realtime Database
    _streamSubscription = mealsReference.onValue.listen((event) {
      _onMealsUpdate(event.snapshot);
    });
  }

  @override
  void dispose() {
    _streamSubscription.cancel();
    super.dispose();
  }

  void _onMealsUpdate(DataSnapshot dataSnapshot) {
    final List<Map<String, dynamic>> meals = [];
    if (dataSnapshot.value != null) {
      (dataSnapshot.value as Map<dynamic, dynamic>).forEach((key, data) {
        meals.add({
          'key': key,
          'name': data['name'],
          'protein': data['protein'],
          'fat': data['fat'],
          'carbs': data['carbs'],
        });
      });
      setState(() {
        mealJournal = meals;
      });
    }
  }

  void deleteMeal(String mealKey) async {
    await mealsReference.child(mealKey).remove();
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
    final meal = {
      'name': mealName,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
    };
    await mealsReference.push().set(meal);

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
    for (var meal in mealJournal) {
      final protein = meal['protein'];
      final fat = meal['fat'];
      final carbs = meal['carbs'];

      // calculate the calories from the macronutrients using the following formula:
      // calories = 4 * protein + 9 * fat + 4 * carbs
      final calories = 4 * protein + 9 * fat + 4 * carbs;

      totalCalories += calories;
      totalProtein += protein;
      totalFat += fat;
      totalCarbs += carbs;
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
                      backgroundColor: MaterialStateProperty.all<Color>(
                        Color.fromARGB(255, 138, 104, 35),
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
                  key: Key(meal['key']),
                  onDismissed: (direction) {
                    deleteMeal(meal['key']);
                    setState(() {
                      mealJournal.removeAt(index);
                    });
                  },
                  child: Card(
                    child: ListTile(
                      title: Text(meal['name']),
                      subtitle: Text(
                        '${meal['protein']}g P | ${meal['fat']}g F | ${meal['carbs']}g C',
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          // Delete the meal from Firebase Realtime Database
                          mealsReference.child(meal['key']).remove();
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
