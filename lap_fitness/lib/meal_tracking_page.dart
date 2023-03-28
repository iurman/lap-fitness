// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';

class MealTrackingPage extends StatelessWidget {
  const MealTrackingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meal Tracking'),
      ),
      body: Center(
        child: Text('Meal Tracking Page'),
      ),
    );
  }
}
