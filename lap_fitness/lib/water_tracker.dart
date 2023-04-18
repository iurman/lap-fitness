// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, prefer_const_constructors, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class WaterTracker extends StatefulWidget {
  @override
  _WaterTrackerState createState() => _WaterTrackerState();
}

class _WaterTrackerState extends State<WaterTracker> {
  int _waterIntake = 0;
  late DatabaseReference
      _waterIntakeRef; // Firebase Realtime Database reference

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp(); // Initialize Firebase
    _waterIntakeRef = FirebaseDatabase.instance.reference().child(
        'waterIntake'); // Reference to the 'waterIntake' node in the database
  }

  void _incrementWaterIntake() {
    setState(() {
      _waterIntake++;
      _waterIntakeRef
          .set(_waterIntake); // Save water intake value to the database
    });
  }

  void _decrementWaterIntake() {
    setState(() {
      if (_waterIntake > 0) {
        _waterIntake--;
        _waterIntakeRef
            .set(_waterIntake); // Save water intake value to the database
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 138, 104, 35),
        title: Text('Water Intake Tracker'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 200,
              child: Stack(
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/water_bottle.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Water Intake: $_waterIntake cups',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: _decrementWaterIntake,
                  child: Icon(Icons.remove),
                ),
                SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: _incrementWaterIntake,
                  child: Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
