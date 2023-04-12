import 'package:flutter/material.dart';

class WaterTracker extends StatefulWidget {
  @override
  _WaterTrackerState createState() => _WaterTrackerState();
}

class _WaterTrackerState extends State<WaterTracker> {
  int _waterIntake = 0;

  void _incrementWaterIntake() {
    setState(() {
      _waterIntake++;
    });
  }

  void _decrementWaterIntake() {
    setState(() {
      if (_waterIntake > 0) {
        _waterIntake--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                  Image.asset(
                    'assets/images/water_bottle.png',
                    fit: BoxFit.cover,
                  ),
                  FractionallySizedBox(
                    heightFactor: _waterIntake / 10,
                    child: Container(
                      color: Colors.blue,
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
