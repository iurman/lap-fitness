// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MealTrackingPage extends StatefulWidget {
  const MealTrackingPage({Key? key}) : super(key: key);

  @override
  _MealTrackingPageState createState() => _MealTrackingPageState();
}

class _MealTrackingPageState extends State<MealTrackingPage> {
  final TextEditingController _nameController = TextEditingController();
  final List<FoodItem> _foodItems = [];

  void _addFoodItem() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController nameController = TextEditingController();
        final TextEditingController caloriesController =
            TextEditingController();
        final TextEditingController proteinController = TextEditingController();
        final TextEditingController carbsController = TextEditingController();
        final TextEditingController fatController = TextEditingController();

        return AlertDialog(
          title: Text('Add Food Item'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: caloriesController,
                  decoration: InputDecoration(labelText: 'Calories'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: proteinController,
                  decoration: InputDecoration(labelText: 'Protein (g)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: carbsController,
                  decoration: InputDecoration(labelText: 'Carbs (g)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: fatController,
                  decoration: InputDecoration(labelText: 'Fat (g)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final foodItem = FoodItem(
                  name: nameController.text,
                  calories: int.parse(caloriesController.text),
                  protein: int.parse(proteinController.text),
                  carbs: int.parse(carbsController.text),
                  fat: int.parse(fatController.text),
                );
                setState(() {
                  _foodItems.add(foodItem);
                });
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _addMeal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Meal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                ),
                SizedBox(height: 8.0),
                Text(
                  'Food Items',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 8.0),
                DataTable(
                  columns: [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Calories')),
                    DataColumn(label: Text('Protein (g)')),
                    DataColumn(label: Text('Carbs (g)')),
                    DataColumn(label: Text('Fat (g)')),
                  ],
                  rows: _foodItems.map((foodItem) {
                    return DataRow(cells: [
                      DataCell(Text(foodItem.name)),
                      DataCell(Text('${foodItem.calories}')),
                      DataCell(Text('${foodItem.protein}')),
                      DataCell(Text('${foodItem.carbs}')),
                      DataCell(Text('${foodItem.fat}')),
                    ]);
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final mealsRef = FirebaseFirestore.instance.collection('meals');
                final user = FirebaseAuth.instance.currentUser;
                final userId = user != null ? user.uid : '';
                final mealDate =
                    DateTime.now().toLocal().toIso8601String().substring(0, 10);
                final mealDoc = mealsRef.doc('$userId-$mealDate');
                await mealDoc.set({
                  'name': _nameController.text,
                  'foodItems':
                      _foodItems.map((foodItem) => foodItem.toMap()).toList(),
                });

                setState(() {
                  _nameController.clear();
                  _foodItems.clear();
                });
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mealsRef = FirebaseFirestore.instance.collection('meals');
    final user = FirebaseAuth.instance.currentUser;
    final userId = user != null ? user.uid : '';
    // rest of the build method
    final mealDate =
        DateTime.now().toLocal().toIso8601String().substring(0, 10);
    final mealDoc = mealsRef.doc('$userId-$mealDate');

    return Scaffold(
      appBar: AppBar(
        title: Text('Meal Tracking'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: mealDoc.snapshots(),
        builder:
            (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final mealData = snapshot.data!.data() as Map<String, dynamic>?;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ElevatedButton(
                  onPressed: _addFoodItem,
                  child: Text('Add Food Item'),
                ),
                SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _addMeal,
                  child: Text('Add Meal'),
                ),
                SizedBox(height: 16.0),
                if (mealData != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        mealData['name'],
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16.0),
                      DataTable(
                        columns: [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Calories')),
                          DataColumn(label: Text('Protein (g)')),
                          DataColumn(label: Text('Carbs (g)')),
                          DataColumn(label: Text('Fat (g)')),
                        ],
                        rows: (mealData['foodItems'] as List<dynamic>)
                            .map((foodItemData) =>
                                FoodItem.fromMap(foodItemData))
                            .map((foodItem) {
                          return DataRow(cells: [
                            DataCell(Text(foodItem.name)),
                            DataCell(Text('${foodItem.calories}')),
                            DataCell(Text('${foodItem.protein}')),
                            DataCell(Text('${foodItem.carbs}')),
                            DataCell(Text('${foodItem.fat}')),
                          ]);
                        }).toList(),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FoodItem {
  String name;
  int calories;
  int protein;
  int carbs;
  int fat;

  FoodItem(
      {required this.name,
      required this.calories,
      required this.protein,
      required this.carbs,
      required this.fat});

  // Convert a FoodItem object to a Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  // Create a FoodItem object from a Map
  static FoodItem fromMap(Map<String, dynamic> map) {
    return FoodItem(
      name: map['name'],
      calories: map['calories'],
      protein: map['protein'],
      carbs: map['carbs'],
      fat: map['fat'],
    );
  }
}
