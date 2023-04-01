// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MealTrackingPage extends StatefulWidget {
  @override
  _MealTrackingPageState createState() => _MealTrackingPageState();
}

class _MealTrackingPageState extends State<MealTrackingPage> {
  final mealNameController = TextEditingController();
  final mealTypeController = TextEditingController();
  final calorieCountController = TextEditingController();

  final mealsCollection = FirebaseFirestore.instance.collection('meals');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meal Tracker'),
      ),
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
                  controller: mealTypeController,
                  decoration: InputDecoration(
                    labelText: 'Meal type',
                  ),
                ),
                SizedBox(height: 8.0),
                TextFormField(
                  controller: calorieCountController,
                  decoration: InputDecoration(
                    labelText: 'Calorie count',
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
            child: StreamBuilder<QuerySnapshot>(
              stream: mealsCollection
                  .where('userId',
                      isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final meals = snapshot.data!.docs;

                if (meals.isEmpty) {
                  return Center(
                    child: Text('You have not added any meals yet'),
                  );
                }

                return ListView.builder(
                  itemCount: meals.length,
                  itemBuilder: (context, index) {
                    final meal = meals[index];
                    final name = meal['name'];
                    final type = meal['type'];
                    final calories = meal['calories'];
                    final timestamp = meal['timestamp'].toDate();

                    return ListTile(
                      title: Text(name),
                      subtitle: Text('$type - $calories calories'),
                      trailing: Text(
                        '${timestamp.month}/${timestamp.day}/${timestamp.year}',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void submitMealForm() async {
    // Get the form values
    final mealName = mealNameController.text;
    final mealType = mealTypeController.text;
    final calorieCount = int.tryParse(calorieCountController.text);

    // Validate the form values
    if (mealName.isEmpty || mealType.isEmpty || calorieCount == null) {
      return;
    }

    // Get the current user ID
    final userId = FirebaseAuth.instance.currentUser!.uid;

    // Save the meal to Firestore
    await mealsCollection.add({
      'name': mealName,
      'type': mealType,
      'calories': calorieCount,
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Clear the form values
    mealNameController.clear();
    mealTypeController.clear();
    calorieCountController.clear();
  }
}
